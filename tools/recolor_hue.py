#!/usr/bin/env python3
"""Rota el tono de una franja de color de una imagen, dejando el resto igual.

Se escribió para un caso puntual: `sofia_menu.png` salió del generador con
el overol **azul denim** mientras que en todo el resto del arte es
**verde**. Repintar a mano una prenda con pliegues y sombras es tedioso y
queda plano; en cambio, rotar el tono conserva intacto el sombreado
original (el canal V no se toca) y solo cambia el color.

Por qué HSV y no un reemplazo de color: el overol no es un color plano,
son ~9600 píxeles repartidos en un rango de tonos y brillos. Lo único
que hay que mover es el tono; el brillo es el que dibuja los pliegues.

El borde del rango se aplica con un desvanecido (`FEATHER`) para que los
píxeles de antialias entre la prenda y el fondo no queden con un halo del
color viejo.

Uso:
    python3 tools/recolor_hue.py entrada.png salida.png \
        --from-hue 206 --to-hue 118 --range 35 --sat-scale 0.745
"""

import argparse
import numpy as np
from PIL import Image


def rgb_to_hsv(arr: np.ndarray) -> np.ndarray:
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    mx = arr[..., :3].max(axis=-1)
    mn = arr[..., :3].min(axis=-1)
    diff = mx - mn
    h = np.zeros_like(mx)
    # np.where en vez de if/else: el cálculo del tono depende de cuál de
    # los tres canales es el máximo, y así se resuelve vectorizado.
    safe = np.where(diff == 0, 1, diff)
    h = np.where(mx == r, ((g - b) / safe) % 6, h)
    h = np.where(mx == g, ((b - r) / safe) + 2, h)
    h = np.where(mx == b, ((r - g) / safe) + 4, h)
    h = np.where(diff == 0, 0, h * 60.0)
    s = np.where(mx == 0, 0, diff / np.where(mx == 0, 1, mx))
    return np.stack([h, s, mx], axis=-1)


def hsv_to_rgb(hsv: np.ndarray) -> np.ndarray:
    h, s, v = hsv[..., 0] % 360.0, hsv[..., 1], hsv[..., 2]
    c = v * s
    x = c * (1 - np.abs((h / 60.0) % 2 - 1))
    m = v - c
    z = np.zeros_like(h)
    seg = (h / 60.0).astype(int) % 6
    r = np.select([seg == 0, seg == 1, seg == 2, seg == 3, seg == 4, seg == 5], [c, x, z, z, x, c])
    g = np.select([seg == 0, seg == 1, seg == 2, seg == 3, seg == 4, seg == 5], [x, c, c, x, z, z])
    b = np.select([seg == 0, seg == 1, seg == 2, seg == 3, seg == 4, seg == 5], [z, z, x, c, c, x])
    return np.stack([r + m, g + m, b + m], axis=-1)


def recolor(path_in, path_out, from_hue, to_hue, hue_range, sat_scale, min_sat, feather):
    im = Image.open(path_in).convert("RGBA")
    arr = np.asarray(im).astype(np.float32) / 255.0
    hsv = rgb_to_hsv(arr)
    h, s = hsv[..., 0], hsv[..., 1]
    alpha = arr[..., 3]

    # Distancia angular al tono de origen, respetando que 359° y 1° están
    # a 2° de distancia y no a 358°.
    dist = np.abs(((h - from_hue + 180.0) % 360.0) - 180.0)

    # Peso 1 en el centro del rango, cayendo a 0 en el borde. Sin este
    # desvanecido los píxeles de antialias del contorno se quedan con el
    # color viejo y se ve un halo.
    weight = np.clip((hue_range + feather - dist) / max(feather, 1e-6), 0.0, 1.0)
    # Un color casi gris no tiene tono confiable: rotarlo lo ensucia.
    weight *= np.clip((s - min_sat) / max(min_sat, 1e-6), 0.0, 1.0)
    weight *= (alpha > 0.02)

    shift = ((to_hue - from_hue + 180.0) % 360.0) - 180.0
    hsv[..., 0] = h + shift * weight
    hsv[..., 1] = s * (1.0 + (sat_scale - 1.0) * weight)
    # El canal V (brillo) queda intacto: es el que dibuja los pliegues.

    out = np.concatenate([hsv_to_rgb(hsv), alpha[..., None]], axis=-1)
    Image.fromarray((np.clip(out, 0, 1) * 255).round().astype(np.uint8), "RGBA").save(path_out)
    print(f"{path_in} -> {path_out}: {int((weight > 0.5).sum())} px repintados")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("input")
    p.add_argument("output")
    p.add_argument("--from-hue", type=float, required=True, help="tono a reemplazar, en grados 0-360")
    p.add_argument("--to-hue", type=float, required=True, help="tono nuevo, en grados 0-360")
    p.add_argument("--range", dest="hue_range", type=float, default=30.0, help="mitad del ancho del rango afectado")
    p.add_argument("--sat-scale", type=float, default=1.0, help="factor de saturación (1.0 = sin cambio)")
    p.add_argument("--min-sat", type=float, default=0.12, help="debajo de esta saturación no se toca (grises)")
    p.add_argument("--feather", type=float, default=12.0, help="grados de desvanecido en el borde del rango")
    a = p.parse_args()
    recolor(a.input, a.output, a.from_hue, a.to_hue, a.hue_range, a.sat_scale, a.min_sat, a.feather)


if __name__ == "__main__":
    main()
