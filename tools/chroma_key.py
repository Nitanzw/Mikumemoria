#!/usr/bin/env python3
"""Quita el fondo croma (verde) de los sprites generados por IA.

    pip install pillow numpy scipy
    python3 tools/chroma_key.py entrada.png -o salida.png
    python3 tools/chroma_key.py carpeta/ --in-place

Por qué no alcanza con "borrar todo lo que se parezca al verde":

1. **El modelo no devuelve un verde exacto.** Pide #00FF00 y entrega
   (6, 240, 4), (10, 229, 7), etc. Por eso el color de fondo se
   *samplea* del borde de cada imagen en vez de asumirlo.

2. **Hay sujetos verdes.** El grillo y el matamoscas son verdes sobre
   fondo verde. Si se borrara por color, se les harían agujeros. Por eso
   se hace flood-fill (componentes conexas) desde el borde: solo se
   borra el fondo *conectado al borde*, así el verde del sujeto
   sobrevive aunque se parezca.

3. **Queda un halo verde en los bordes** (spill), por el antialiasing
   entre sujeto y fondo. Se corrige bajando el canal verde de los
   píxeles donde G domina sobre R y B, solo cerca del recorte.
"""
from __future__ import annotations

import argparse
import os
import sys

try:
    import numpy as np
    from PIL import Image
    from scipy import ndimage
except ImportError:
    sys.exit("Faltan dependencias: pip install pillow numpy scipy")

# Distancia RGB máxima al color de fondo sampleado para considerar un
# píxel "candidato a fondo". Los verdes del grillo quedan a ~150 de
# distancia del verde croma, así que 100 los deja afuera con margen.
DEFAULT_TOLERANCE = 100.0
# Tolerancia (mucho más estricta) para las manchas de fondo que quedan
# ATRAPADAS dentro del sujeto, sin tocar el borde: entre la malla y el
# mango del matamoscas, entre las patas del grillo. Como el fondo croma
# real está a distancia ~0-30 del color sampleado y los verdes propios
# del sujeto a ~150, con 45 se limpian las manchas sin comerse al bicho.
ENCLOSED_TOLERANCE = 45.0
FEATHER_SIGMA = 0.8  # suaviza el filo del recorte, evita el borde dentado
DESPILL_WIDTH = 3  # px alrededor del recorte donde se corrige el halo verde


def _border_color(rgb: np.ndarray) -> np.ndarray:
    """Color del fondo, tomado como la mediana de un anillo de 1px
    *metido hacia adentro* un 2% del lado.

    No se usa el borde exacto a propósito: varias imágenes generadas
    vienen con un marco oscuro de 1 o 2 píxeles (la línea de la grilla
    en los sprite sheets, o un artefacto de compresión). Sampleando ahí
    se toma negro como color de fondo y el recorte no borra nada — pasó
    con grillo_saltarin_walk.png, que salía 3% transparente en vez de 60%.

    Mediana y no promedio: si el sujeto toca un borde, el promedio se
    contamina con su color y la mediana no.
    """
    h, w = rgb.shape[:2]
    inset = max(1, int(min(h, w) * 0.02))
    ring = np.concatenate([
        rgb[inset, inset:-inset],
        rgb[-inset - 1, inset:-inset],
        rgb[inset:-inset, inset],
        rgb[inset:-inset, -inset - 1],
    ])
    return np.median(ring, axis=0)


def key_out(img: Image.Image, tolerance: float = DEFAULT_TOLERANCE) -> Image.Image:
    img = img.convert("RGBA")
    arr = np.array(img).astype(np.float32)
    rgb = arr[..., :3]
    h, w = rgb.shape[:2]

    key = _border_color(rgb)
    dist = np.sqrt(((rgb - key) ** 2).sum(axis=-1))
    candidate = dist < tolerance

    # Solo el fondo pegado al borde: evita agujerear un sujeto que tenga
    # el mismo color en el medio.
    labeled, _ = ndimage.label(candidate)
    edge_labels = set(labeled[0, :]) | set(labeled[-1, :]) | set(labeled[:, 0]) | set(labeled[:, -1])
    edge_labels.discard(0)
    background = np.isin(labeled, list(edge_labels)) if edge_labels else np.zeros((h, w), bool)

    # Manchas de fondo atrapadas dentro del sujeto (no tocan el borde):
    # se borran solo si son croma casi puro, así no se toca el verde
    # propio de un grillo o de una malla.
    background |= (dist < ENCLOSED_TOLERANCE) & ~background

    alpha = np.where(background, 0.0, 255.0)
    alpha = ndimage.gaussian_filter(alpha, sigma=FEATHER_SIGMA)

    # Despill: cerca del recorte, el antialiasing dejó píxeles teñidos de
    # verde. Donde el verde domina, se lo baja al promedio de R y B.
    near_edge = ndimage.binary_dilation(background, iterations=DESPILL_WIDTH) & ~background
    g = rgb[..., 1]
    rb_mean = (rgb[..., 0] + rgb[..., 2]) / 2.0
    spill = near_edge & (g > rb_mean + 12.0)
    rgb[..., 1] = np.where(spill, rb_mean + 12.0, g)

    arr[..., :3] = rgb
    arr[..., 3] = np.minimum(arr[..., 3], alpha)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def _process(path: str, out: str, tolerance: float) -> None:
    img = Image.open(path)
    before = np.array(img.convert("RGBA"))[..., 3]
    result = key_out(img, tolerance)
    after = np.array(result)[..., 3]
    removed = float((after < 128).mean() - (before < 128).mean()) * 100.0
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    result.save(out, "PNG")
    print(f"{os.path.basename(path):38} -> transparente el {removed:5.1f}% de la imagen")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path", help="archivo .png o carpeta")
    ap.add_argument("-o", "--output", help="archivo de salida (solo para un archivo)")
    ap.add_argument("--in-place", action="store_true", help="sobrescribir los originales")
    ap.add_argument("--tolerance", type=float, default=DEFAULT_TOLERANCE,
                    help=f"distancia RGB al color de fondo (default: {DEFAULT_TOLERANCE})")
    args = ap.parse_args()

    if os.path.isdir(args.path):
        files = sorted(f for f in os.listdir(args.path) if f.lower().endswith(".png"))
        if not files:
            sys.exit(f"No hay .png en {args.path}")
        for f in files:
            src = os.path.join(args.path, f)
            dst = src if args.in_place else os.path.join(args.path, "keyed", f)
            _process(src, dst, args.tolerance)
    else:
        dst = args.output or (args.path if args.in_place else args.path.replace(".png", "_keyed.png"))
        _process(args.path, dst, args.tolerance)


if __name__ == "__main__":
    main()
