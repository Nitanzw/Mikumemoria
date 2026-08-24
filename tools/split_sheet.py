#!/usr/bin/env python3
"""Parte un sprite sheet en grilla (ej. 2x2) en cuadros sueltos.

    python3 tools/split_sheet.py hormiga_obrera_walk.png --grid 2x2 --size 128x128

Genera `<nombre_sin_walk>_walk_0.png` ... `_3.png` en la misma carpeta,
que son los nombres que arma `Insect._apply_sprite_data()`.

Se corre DESPUÉS de chroma_key.py, sobre la hoja ya transparente.

Detalles que importan para que la animación no "salte":

- Se descarta un margen de cada celda (`--trim`) para tirar la línea de
  la grilla que el modelo dibuja entre cuadros.
- El recorte fino NO es a la celda entera: se busca el bounding box de
  lo que quedó opaco y se recorta a eso. Así no importa que el bicho
  esté descentrado en su celda.
- Todos los cuadros se escalan con **el mismo factor** (el que necesita
  el cuadro más grande) y se centran en un lienzo del tamaño pedido. Si
  cada cuadro se escalara por separado para llenar su lienzo, el bicho
  cambiaría de tamaño entre cuadros y la caminata latiría.
"""
from __future__ import annotations

import argparse
import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:
    sys.exit("Faltan dependencias: pip install pillow numpy")


def _alpha_bbox(img: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = np.array(img.convert("RGBA"))[..., 3]
    ys, xs = np.where(alpha > 16)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def split(path: str, cols: int, rows: int, size: tuple[int, int], trim: float, padding: float) -> list[str]:
    sheet = Image.open(path).convert("RGBA")
    W, H = sheet.size
    cw, ch = W / cols, H / rows

    crops: list[Image.Image] = []
    for r in range(rows):
        for c in range(cols):
            cell = sheet.crop((
                int((c + trim) * cw), int((r + trim) * ch),
                int((c + 1 - trim) * cw), int((r + 1 - trim) * ch),
            ))
            box = _alpha_bbox(cell)
            if box is None:
                print(f"  aviso: la celda {r},{c} quedó vacía", file=sys.stderr)
                crops.append(cell)
            else:
                crops.append(cell.crop(box))

    # Un solo factor de escala para todos, del cuadro más grande.
    target_w = size[0] * (1.0 - padding * 2)
    target_h = size[1] * (1.0 - padding * 2)
    scale = min(min(target_w / c.width, target_h / c.height) for c in crops)

    base = os.path.basename(path)
    stem = base[:-4] if base.lower().endswith(".png") else base
    if stem.endswith("_walk"):
        stem = stem[:-5]
    outdir = os.path.dirname(path) or "."

    written = []
    for i, crop in enumerate(crops):
        nw, nh = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
        resized = crop.resize((nw, nh), Image.LANCZOS)
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        canvas.paste(resized, ((size[0] - nw) // 2, (size[1] - nh) // 2), resized)
        out = os.path.join(outdir, f"{stem}_walk_{i}.png")
        canvas.save(out, "PNG")
        written.append(out)
        print(f"  {os.path.basename(out)}  ({nw}x{nh} dentro de {size[0]}x{size[1]})")
    return written


def _pair(text: str, sep: str = "x") -> tuple[int, int]:
    a, b = text.lower().split(sep)
    return int(a), int(b)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheets", nargs="+", help="sprite sheet(s) .png ya recortados")
    ap.add_argument("--grid", default="2x2", help="columnas x filas (default: 2x2)")
    ap.add_argument("--size", default="128x128", help="tamaño de cada cuadro (default: 128x128)")
    ap.add_argument("--trim", type=float, default=0.03,
                    help="fracción del borde de cada celda a descartar, tira la línea de grilla (default: 0.03)")
    ap.add_argument("--padding", type=float, default=0.04,
                    help="aire alrededor del sujeto en el lienzo final (default: 0.04)")
    args = ap.parse_args()

    cols, rows = _pair(args.grid)
    size = _pair(args.size)
    for sheet in args.sheets:
        print(os.path.basename(sheet))
        split(sheet, cols, rows, size, args.trim, args.padding)


if __name__ == "__main__":
    main()
