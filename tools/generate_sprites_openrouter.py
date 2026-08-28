#!/usr/bin/env python3
"""Genera los sprites del juego con OpenRouter (https://openrouter.ai).

Requiere la variable de entorno OPENROUTER_API_KEY (https://openrouter.ai/keys)
y las librerías Pillow + numpy + scipy (no vienen en la librería estándar):

    pip install pillow numpy scipy
    export OPENROUTER_API_KEY="tu_clave"

Uso:
    python3 tools/generate_sprites_openrouter.py --list
    python3 tools/generate_sprites_openrouter.py --asset hormiga_obrera
    python3 tools/generate_sprites_openrouter.py --category insect
    python3 tools/generate_sprites_openrouter.py --all --skip-existing

Modelo por defecto: google/gemini-3.1-flash-lite-image ("Nano Banana 2
Lite"), la variante económica de la gama "flash" de Gemini para imagen
(precio por token de salida bastante menor que la variante "flash" sin
-lite, misma familia/calidad visual). Se puede cambiar con --model —
por ejemplo black-forest-labs/flux.2-klein-4b sale aún más barato
(cobra por megapíxel, y estos sprites son chicos).

Cómo se generan los sprites con transparencia (insectos, armas, personaje):
    1. Se le pide al modelo el sujeto "aislado sobre fondo magenta plano
       (#FF00FF)" en vez de pedirle transparencia nativa (no todos los
       modelos la soportan bien vía API) — pero en la práctica el modelo
       no siempre respeta el magenta exacto, así que el post-proceso NO
       asume ese color fijo.
    2. Post-proceso local con Pillow/numpy/scipy: se samplea el color
       real del borde de la imagen (sea cual sea) y se hace flood-fill
       (componentes conexas) desde los bordes para volver transparente
       solo el fondo *conectado al borde* — así no se generan agujeros
       si el sujeto tiene por casualidad un color parecido en el medio.
       El borde de la máscara se difumina un poco para evitar contornos
       duros tipo "recorte con tijera".
    3. Se reencuadra al tamaño exacto que ya esperan las escenas .tscn.

Los fondos de capítulo y el ícono no llevan este paso (son opacos).
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import os
import sys
import urllib.error
import urllib.request

try:
    import numpy as np
    from PIL import Image

    # El recorte de croma bueno vive en chroma_key.py: samplea el color
    # con la mediana de un anillo metido hacia adentro, limpia las manchas
    # de fondo atrapadas dentro del sujeto y corrige el halo verde. Acá
    # había una copia más floja que se comía solo el fondo pegado al borde.
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from chroma_key import key_out, _border_color
except ImportError:
    sys.exit("Faltan dependencias: pip install pillow numpy scipy")

API_BASE = "https://openrouter.ai/api/v1"
IMAGES_ENDPOINT = f"{API_BASE}/images"

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(REPO_ROOT, "assets", "sprites")

DEFAULT_MODEL = "google/gemini-3.1-flash-lite-image"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


# Margen que se descarta a cada lado de un corte, como fracción del lado
# de la hoja: tira la línea divisoria y su antialiasing.
GRID_LINE_PAD = 0.02
# Misma tolerancia que usa chroma_key para decidir qué es fondo.
CHROMA_TOLERANCE = 100.0

STYLE_SUFFIX = (
    ", flat cartoon vector game-icon art style, bold clean black outline, "
    "simple cel shading, vibrant saturated colors, centered single subject, "
    "no text, no watermark, no signature, high detail"
)
TRANSPARENT_BG_INSTRUCTION = (
    ", isolated on a solid flat magenta background (#FF00FF), no shadow, "
    "no gradient, no other objects, no floor"
)
## Estilo del arte ACTUAL del juego (el que se generó con Nano Banana a
## partir de ARTE_PEDIDO.md). STYLE_SUFFIX de arriba es el estilo viejo,
## plano; se conserva solo para no romper los prompts originales.
POLISHED_STYLE = (
    ", polished mobile game art, soft cel shading with rim light, subtle "
    "gradients, painterly texture, rich saturated palette, clean readable "
    "composition, no text, no watermark, no signature, no logo, high detail"
)

GREEN_SCREEN_BG_INSTRUCTION = (
    ", isolated on a solid flat chroma-key green background (#00FF00), no "
    "shadow, no gradient, no other objects, no floor"
)

CATEGORY_DEFAULTS = {
    # Pantallas de menú (tienda, habilidades, mapa). Opacas y verticales.
    "ui_background": {"dir": "ui", "size": (1080, 1920), "transparent": False, "aspect_ratio": "9:16"},
    # Piezas de interfaz recortadas (paneles, íconos).
    "ui_panel": {"dir": "ui", "size": (512, 256), "transparent": True, "aspect_ratio": "2:1"},
    "ui_icon": {"dir": "ui", "size": (128, 128), "transparent": True, "aspect_ratio": "1:1"},
    "insect": {"dir": "insects", "size": (128, 128), "transparent": True, "aspect_ratio": "1:1"},
    "weapon": {"dir": "weapons", "size": (128, 128), "transparent": True, "aspect_ratio": "1:1"},
    "character": {"dir": "character", "size": (200, 320), "transparent": True, "aspect_ratio": "9:16"},
    "background": {"dir": "backgrounds", "size": (540, 960), "transparent": False, "aspect_ratio": "9:16"},
    "icon": {"dir": "", "size": (256, 256), "transparent": False, "aspect_ratio": "1:1"},
}

# nombre -> (categoria, prompt)  -- el nombre de archivo final es "<nombre>.png"
ASSETS: dict[str, tuple[str, str]] = {
    # --- Insectos comunes (Insect.INSECT_DATA en insect.gd) ---
    "hormiga_obrera": ("insect", "a cute cartoon worker ant character for a garden-defense video game, brown color, big round eyes, three-quarter view"),
    "cucaracha_electrica": ("insect", "a cute cartoon cockroach crackling with yellow electric energy, comic video game enemy"),
    "escarabajo_blindado": ("insect", "a cute cartoon armored beetle with a thick metallic blue-gray shell, tank-like, video game enemy"),
    "mosca_pesada": ("insect", "a cute cartoon heavy chubby fly, dark gray, round body, video game enemy"),
    "grillo_saltarin": ("insect", "a cute cartoon jumping cricket, green, mid-leap pose, video game enemy"),
    # --- Silueta del incognito (mystery_bug.gd) ---
    "mystery_bug_silueta": ("insect", "a mysterious dark purple insect silhouette shape with a glowing white question mark on it, spooky but cute, video game enemy"),
    # --- Insectos incognito revelados (MysteryBug.MYSTERY_DATABASE) ---
    "hormiga_ladrona": ("insect", "a cute cartoon ant wearing a bandit mask, holding a tiny sparkling diamond, golden color, video game enemy"),
    "abejorro_pinata": ("insect", "a cute cartoon bumblebee shaped like a colorful paper pinata, orange and black stripes with paper fringe, video game enemy"),
    "mantis_cronometro": ("insect", "a cute cartoon praying mantis with a stopwatch clock embedded in its chest, teal color, video game enemy"),
    "escarabajo_radiactivo": ("insect", "a cute cartoon beetle glowing toxic green with radioactive symbol markings, video game enemy"),
    "lombriz_gigante": ("insect", "a cute cartoon giant earthworm, pink, segmented body, video game enemy"),
    "mutante_volador": ("insect", "a cute cartoon mutant flying insect with purple wings and extra eyes, video game enemy"),
    "centella_blindada": ("insect", "a cute cartoon insect wrapped in blue electric armor plating, sparking with energy, video game enemy"),
    "rayo_insecto": ("insect", "a cute cartoon insect made of bright yellow lightning bolts, glowing, video game enemy"),
    "coraza_antigua": ("insect", "a cute cartoon insect wearing a weathered ancient bronze beetle-shell armor, video game enemy"),
    "reina_primordial": ("insect", "a majestic cute cartoon insect queen, large, purple and gold royal colors, crown-like antennae, video game boss enemy"),

    # --- Armas (WeaponSystem.WEAPONS en weapon_system.gd) ---
    "zapato_viejo": ("weapon", "an old worn brown leather shoe, comic video game weapon icon, three-quarter view"),
    "chancla_goma": ("weapon", "a blue rubber flip-flop sandal, comic video game weapon icon, top view"),
    "matamoscas_metalico": ("weapon", "a metallic fly swatter with a wire mesh head, comic video game weapon icon"),
    "sarten_hierro": ("weapon", "a black cast iron frying pan, comic video game weapon icon, top view"),
    "pala_electrificada": ("weapon", "a metal garden shovel crackling with yellow electricity, comic video game weapon icon"),

    # --- Personaje (Player/DonBetoSprite en main_game.tscn) ---
    "don_beto": ("character", "a cheerful cartoon farmer character named Don Beto, older man with a mustache, straw hat, green overalls, holding a shoe raised up, full body, front view, video game character"),

    # --- Retrato de Don Beto por emoción (don_beto_portrait.gd, dialogue_box) ---
    "don_beto_neutral": ("character", "portrait of a cartoon farmer character named Don Beto, older man with a mustache, straw hat, green overalls, calm neutral friendly expression, waist-up, front view, video game character portrait"),
    "don_beto_happy": ("character", "portrait of a cheerful cartoon farmer character named Don Beto, older man with a mustache, straw hat, green overalls, big warm smile, eyes crinkled with joy, waist-up, front view, video game character portrait"),
    "don_beto_sad": ("character", "portrait of a cartoon farmer character named Don Beto, older man with a mustache, straw hat, green overalls, downturned mouth, droopy sad eyes, slumped shoulders, waist-up, front view, video game character portrait"),
    "don_beto_angry": ("character", "portrait of a cartoon farmer character named Don Beto, older man with a mustache, straw hat, green overalls, furrowed angry eyebrows, gritted teeth, red flushed cheeks, waist-up, front view, video game character portrait"),
    "don_beto_worried": ("character", "portrait of a cartoon farmer character named Don Beto, older man with a mustache, straw hat, green overalls, wide anguished eyes, sweat drop, biting lip, nervous expression, waist-up, front view, video game character portrait"),

    # --- Pantallas de menú ---
    "shop_background": ("ui_background", "the cozy interior of a garden potting shed seen from the front, wooden shelves lined with terracotta pots, coiled hose, hanging hand tools, seed packets and twine, warm afternoon light through a dusty window, inviting and tidy, vertical mobile game shop background, large uncluttered area in the middle for a list of items"),
    "skills_background": ("ui_background", "an open gardening journal lying on a wooden table seen from directly above, both pages COMPLETELY BLANK aged cream paper with no writing whatsoever, no letters, no words, no handwriting, no printed title, only pressed leaves and small botanical sketches in the outer margins, a pencil and a few seeds resting on the table beside it, warm soft light, vertical mobile game background"),
    "map_background": ("ui_background", "a hand-drawn treasure-map style illustration of a countryside on aged parchment, a winding dirt path going from the bottom to the top past a vegetable garden, a greenhouse, a cave mouth, a swamp and distant mountains, compass rose in a corner, soft sepia and green tones, no text and no labels, vertical mobile game world map background"),

    # --- Fondos de capitulo (LevelManager.chapter_configs) ---
    "chapter_1_huerto": ("background", "a sunny cheerful vegetable garden with tomato plants, wooden fences and blue sky, mobile game background, portrait orientation, no characters"),
    "chapter_2_invernadero": ("background", "the warm humid interior of a glass greenhouse full of tropical plants, soft light rays, mobile game background, portrait orientation, no characters"),
    "chapter_3_cueva": ("background", "a mysterious dark underground cave with glowing crystals and stalactites, mobile game background, portrait orientation, no characters"),
    "chapter_4_radiactivo": ("background", "a glowing toxic radioactive crop field with green mutated plants and warning signs, mobile game background, portrait orientation, no characters"),
    "chapter_5_pantano": ("background", "a misty swamp with murky water, twisted trees and lily pads, mobile game background, portrait orientation, no characters"),
    "chapter_6_lab": ("background", "a sci-fi secret laboratory with glowing tubes, computer screens and metal tables, mobile game background, portrait orientation, no characters"),
    "chapter_7_fabrica": ("background", "an industrial factory interior with conveyor belts, pipes and metal gears, mobile game background, portrait orientation, no characters"),
    "chapter_8_tuneles": ("background", "a fast underground tunnel network with speed motion lines and warning stripes, mobile game background, portrait orientation, no characters"),
    "chapter_9_bunker": ("background", "a tense military bunker interior with metal walls, red alert lights and crates, mobile game background, portrait orientation, no characters"),
    "chapter_10_nucleo": ("background", "an epic glowing alien queen's core chamber, purple and gold energy, dramatic final-boss atmosphere, mobile game background, portrait orientation, no characters"),
}

# Piezas sueltas de interfaz
UI_PIECES = {
    "panel_card": ("ui_panel", "a horizontal wooden signboard panel for a game list row, warm sanded wood planks with visible grain, rounded corners, a thin darker carved border and small iron nails in the four corners, completely empty surface with no text and no carving, even flat lighting, front view"),
    "coin": ("ui_icon", "a single shiny gold coin seen at a slight three-quarter angle, thick rim with a small embossed leaf on its face, warm metallic highlights, game currency icon, readable at small size"),
}

# El icono vive en la raiz del repo, no en assets/sprites/
ICON_ASSET = ("icon", "a bold cute app icon: a cartoon shoe squashing an angry cartoon ant, garden background, square composition, readable at small size")

# --- Sprite sheets de walk-cycle (grid NxM en una sola imagen, se generan
# en una sola llamada para que los frames sean consistentes entre sí -
# pedirle al modelo N imagenes separadas da resultados demasiado
# distintos frame a frame). Se parte en celdas en post-proceso local. ---
WALK_SHEETS: dict[str, dict] = {
        "hormiga_obrera_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon "
            "worker ant character (solid brown color all over, including legs "
            "and joints, big round eyes, three-quarter view) in a different leg "
            "position of a walking cycle, identical character design, size, "
            "color and camera angle in all 4 poses, only the legs move between "
            "cells, no pink or magenta color anywhere on the ant's body or legs"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "hormiga_obrera_walk",
    },

    "hormiga_ladrona_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon golden ant wearing a black bandit eye mask, clutching a tiny sparkling blue diamond in its front legs, sly grin, small loot sack on its back, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the legs move between poses, in a different position of a walking cycle"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "hormiga_ladrona_walk",
    },
    "abejorro_pinata_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon bumblebee whose body is made of a colorful layered paper pinata, orange and black crepe-paper fringe, tiny paper wings, festive party look, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the wings and the paper fringe move between poses"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "abejorro_pinata_walk",
    },
    "mantis_cronometro_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon praying mantis, teal-green body, with a real analog stopwatch embedded in its chest showing visible clock hands, raised scythe arms, focused stare, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the legs move between poses, in a different position of a walking cycle"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "mantis_cronometro_walk",
    },
    "escarabajo_radiactivo_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon beetle glowing toxic neon green, radioactive trefoil symbol markings on its shell, dripping glowing green ooze, faint green light from the seams, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the legs move between poses, in a different position of a walking cycle"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "escarabajo_radiactivo_walk",
    },
    "lombriz_gigante_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon giant earthworm, thick pink segmented glossy body, small simple friendly face at one end, damp soil crumbs stuck to its skin, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the body coils and stretches between poses, like an earthworm crawling forward, the head stays the same"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "lombriz_gigante_walk",
    },
    "mutante_volador_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon mutant flying insect with a reddish-brown body, four purple wings, an extra pair of asymmetric eyes on its forehead, slightly lumpy mutated body, brown and purple color scheme, no green body, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the four wings change position between poses"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "mutante_volador_walk",
    },
    "centella_blindada_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon insect encased in riveted blue electric armor plating, arcs of white-blue energy sparking between the plates, glowing seams, heavy stance, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the legs and the energy arcs move between poses"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "centella_blindada_walk",
    },
    "rayo_insecto_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon insect with a SOLID OPAQUE bright yellow and white body shaped from lightning bolts, sharp zigzag edges, crackling electric arcs around it, fully opaque with a clear dark outline, no transparency anywhere, no green tones, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the lightning arcs and the energy streaks change shape between poses, the silhouette stays the same"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "rayo_insecto_walk",
    },
    "coraza_antigua_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon insect wearing weathered ancient bronze beetle-shell armor, the metal heavily oxidized to a blue-green verdigris patina over dark bronze, engraved tribal glyphs on the plates, chipped edges, teal-and-bronze color scheme, not brown, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the legs move between poses, in a different position of a walking cycle"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "coraza_antigua_walk",
    },
    "reina_primordial_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same majestic cartoon insect queen, large regal body in deep purple and gold, ornate crown-like antennae, layered iridescent wings, glowing amber eyes, commanding pose, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the wings and the legs move between poses"
        ),
        "grid": (2, 2),
        "frame_size": (128, 128),
        "dest_dir": "insects",
        "dest_prefix": "reina_primordial_walk",
    },
}


def _find_dividers(rgb: "np.ndarray", key: "np.ndarray", count: int, axis: int) -> list[int]:
    """Posiciones donde cortar la hoja: el centro del hueco de fondo que
    separa una fila/columna de poses de la siguiente.

    Antes se pedía una línea de grilla dibujada y se cortaba sobre ella.
    Mal negocio: el modelo dibuja la grilla donde quiere y de más — en la
    hoja de hormiga_obrera puso líneas cada 1/4 de ancho pero cada bicho
    ocupaba 2 columnas, así que aun cortando bien quedaba una línea
    cruzando el medio de cada cuadro. Ahora se pide fondo vacío entre las
    poses y se corta en el medio de ese vacío, que no deja nada que borrar.
    """
    length = rgb.shape[axis]
    dist = np.sqrt(((rgb - key) ** 2).sum(axis=-1))
    # Fracción de fondo por fila (axis=0) o por columna (axis=1).
    empty = (dist < CHROMA_TOLERANCE).mean(axis=1 - axis) > 0.985

    positions = []
    for i in range(1, count + 1):
        center = int(length * i / (count + 1))
        window = max(int(length * 0.18), 4)
        lo, hi = max(center - window, 1), min(center + window, length - 1)

        # Corrida más larga de fondo dentro de la ventana; se corta al medio.
        best_len = best_mid = 0
        run_start = None
        for pos in range(lo, hi):
            if empty[pos]:
                if run_start is None:
                    run_start = pos
            elif run_start is not None:
                if pos - run_start > best_len:
                    best_len, best_mid = pos - run_start, (run_start + pos) // 2
                run_start = None
        if run_start is not None and hi - run_start > best_len:
            best_len, best_mid = hi - run_start, (run_start + hi) // 2

        # Sin hueco claro se cae al centro teórico, que es mejor que nada.
        positions.append(best_mid if best_len >= 2 else center)
    return positions


def split_walk_sheet(img: "Image.Image", cols: int, rows: int, frame_size: tuple[int, int]) -> list["Image.Image"]:
    """Parte una hoja en una grilla cols x rows y devuelve los cuadros ya
    recortados de fondo y escalados a frame_size.

    Dos cosas que no son obvias:

    1. Los cortes se hacen en las divisorias **detectadas**, no al 50%
       teórico (ver _find_dividers). Además se descarta un margen a cada
       lado del corte para tirar la línea misma.

    2. El croma se saca **por celda ya recortada**, no sobre la hoja
       entera: las líneas de la grilla parten el fondo en regiones que no
       tocan el borde de la hoja, así que un flood-fill desde ese borde no
       las alcanza y quedaban bloques de verde vivos dentro del cuadro
       (le pasó a mantis_cronometro). Recortando primero, el fondo de cada
       celda toca su propio borde y sale entero.
    """
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    key = _border_color(rgb)
    x_cuts = [0] + _find_dividers(rgb, key, cols - 1, 1) + [img.width]
    y_cuts = [0] + _find_dividers(rgb, key, rows - 1, 0) + [img.height]

    pad = max(int(min(img.size) * GRID_LINE_PAD), 2)
    frames = []
    for row in range(rows):
        for col in range(cols):
            left = x_cuts[col] + (pad if col > 0 else pad)
            right = x_cuts[col + 1] - pad
            top = y_cuts[row] + (pad if row > 0 else pad)
            bottom = y_cuts[row + 1] - pad
            cell = img.crop((left, top, right, bottom))
            frames.append(fit_transparent(key_out(cell), frame_size))
    return frames


def generate_walk_sheet(name: str, api_key: str, model: str, skip_existing: bool) -> float:
    spec = WALK_SHEETS[name]
    cols, rows = spec["grid"]
    dest_dir = os.path.join(SPRITES_DIR, spec["dest_dir"])
    first_frame_path = os.path.join(dest_dir, f"{spec['dest_prefix']}_0.png")

    if skip_existing and os.path.exists(first_frame_path):
        print(f"[{name}] ya existe, se salta (--skip-existing)")
        return 0.0

    prompt = spec["prompt"] + STYLE_SUFFIX + GREEN_SCREEN_BG_INSTRUCTION
    print(f"[{name}] generando grid {cols}x{rows} con {model}...")

    result = _call_images_api(api_key, model, prompt, "1:1")
    if "error" in result:
        raise RuntimeError(f"[{name}] OpenRouter respondió error: {result['error']}")

    items = result.get("data", [])
    if not items:
        raise RuntimeError(f"[{name}] respuesta sin imágenes: {result}")

    b64 = items[0].get("b64_json")
    if not b64:
        raise RuntimeError(f"[{name}] la respuesta no trae b64_json: {items[0]}")

    img = Image.open(io.BytesIO(base64.b64decode(b64)))

    # La hoja cruda se guarda: partirla y recortarla es post-proceso local,
    # y si hay que ajustar el corte no hace falta volver a pagar la
    # generación. .gitignore la deja afuera del repo.
    raw_dir = os.path.join(REPO_ROOT, "assets", "sprites", "_sheets_raw")
    os.makedirs(raw_dir, exist_ok=True)
    img.save(os.path.join(raw_dir, f"{name}.png"), "PNG")

    # Ojo: acá NO se saca el croma. split_walk_sheet lo hace por celda.
    frames = split_walk_sheet(img, cols, rows, spec["frame_size"])

    os.makedirs(dest_dir, exist_ok=True)
    for i, frame in enumerate(frames):
        path = os.path.join(dest_dir, f"{spec['dest_prefix']}_{i}.png")
        frame.save(path, "PNG")
        print(f"[{name}] frame {i} -> {path}")

    cost = float(result.get("usage", {}).get("cost", 0.0) or 0.0)
    print(f"[{name}] listo ({len(frames)} frames)" + (f" (${cost:.4f})" if cost else ""))
    return cost


def _api_key() -> str:
    key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if not key:
        sys.exit(
            "Falta OPENROUTER_API_KEY. Exportala antes de correr el script:\n"
            '  export OPENROUTER_API_KEY="tu_clave"\n'
            "(obtenela en https://openrouter.ai/keys)"
        )
    return key


def _dest_path(name: str, category: str) -> str:
    if category == "icon":
        return os.path.join(REPO_ROOT, "icon.png")
    subdir = CATEGORY_DEFAULTS[category]["dir"]
    return os.path.join(SPRITES_DIR, subdir, f"{name}.png")


def _build_prompt(base_prompt: str, transparent: bool, category: str = "") -> str:
    # Las piezas de menú son nuevas y usan el estilo actual del juego; el
    # resto conserva el estilo plano original para no cambiarles la pinta
    # a los assets ya generados si alguien los regenera.
    prompt = base_prompt + (POLISHED_STYLE if category.startswith("ui_") else STYLE_SUFFIX)
    if transparent:
        # Verde y no magenta: con magenta el modelo tiñe de rosa las
        # partes cálidas del sujeto y el recorte se las come.
        prompt += GREEN_SCREEN_BG_INSTRUCTION
    return prompt


def _call_images_api(api_key: str, model: str, prompt: str, aspect_ratio: str | None) -> dict:
    payload = {"model": model, "prompt": prompt, "n": 1, "output_format": "png"}
    if aspect_ratio:
        payload["aspect_ratio"] = aspect_ratio

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "User-Agent": USER_AGENT,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(IMAGES_ENDPOINT, data=data, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        if aspect_ratio and exc.code == 400:
            print(f"    aspect_ratio rechazado ({body[:200]}), reintentando sin él...")
            return _call_images_api(api_key, model, prompt, aspect_ratio=None)
        raise RuntimeError(f"HTTP {exc.code} llamando a {IMAGES_ENDPOINT}: {body}") from exc


def remove_chroma_key(img: "Image.Image") -> "Image.Image":
    """Saca el fondo croma. Delega en chroma_key.key_out para que los
    sprites sueltos y los sprite sheets se recorten con el mismo criterio."""
    return key_out(img)


def fit_transparent(img: "Image.Image", size: tuple[int, int]) -> "Image.Image":
    """Escala manteniendo proporción y centra sobre un lienzo transparente."""
    target_w, target_h = size
    img = img.convert("RGBA")
    scale = min(target_w / img.width, target_h / img.height)
    new_size = (max(int(img.width * scale), 1), max(int(img.height * scale), 1))
    resized = img.resize(new_size, Image.LANCZOS)

    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    offset = ((target_w - new_size[0]) // 2, (target_h - new_size[1]) // 2)
    canvas.paste(resized, offset, resized)
    return canvas


def cover_opaque(img: "Image.Image", size: tuple[int, int]) -> "Image.Image":
    """Escala cubriendo todo el lienzo y recorta el excedente (sin bandas vacías)."""
    target_w, target_h = size
    img = img.convert("RGB")
    scale = max(target_w / img.width, target_h / img.height)
    new_size = (max(int(img.width * scale), 1), max(int(img.height * scale), 1))
    resized = img.resize(new_size, Image.LANCZOS)

    left = (new_size[0] - target_w) // 2
    top = (new_size[1] - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def generate_asset(name: str, category: str, base_prompt: str, api_key: str, model: str, skip_existing: bool) -> float:
    defaults = CATEGORY_DEFAULTS[category]
    dest_path = _dest_path(name, category)

    if skip_existing and os.path.exists(dest_path):
        print(f"[{name}] ya existe, se salta (--skip-existing)")
        return 0.0

    prompt = _build_prompt(base_prompt, defaults["transparent"], category)
    print(f"[{name}] generando con {model}...")

    result = _call_images_api(api_key, model, prompt, defaults.get("aspect_ratio"))

    if "error" in result:
        raise RuntimeError(f"[{name}] OpenRouter respondió error: {result['error']}")

    items = result.get("data", [])
    if not items:
        raise RuntimeError(f"[{name}] respuesta sin imágenes: {result}")

    b64 = items[0].get("b64_json")
    if not b64:
        raise RuntimeError(f"[{name}] la respuesta no trae b64_json: {items[0]}")

    img = Image.open(io.BytesIO(base64.b64decode(b64)))

    if defaults["transparent"]:
        img = remove_chroma_key(img)
        img = fit_transparent(img, defaults["size"])
    else:
        img = cover_opaque(img, defaults["size"])

    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    img.save(dest_path, "PNG")

    cost = float(result.get("usage", {}).get("cost", 0.0) or 0.0)
    print(f"[{name}] listo -> {dest_path}" + (f" (${cost:.4f})" if cost else ""))
    return cost


def _all_items() -> list[tuple[str, str, str]]:
    items = [(name, cat, prompt) for name, (cat, prompt) in ASSETS.items()]
    items.append(("icon", ICON_ASSET[0], ICON_ASSET[1]))
    for name, (cat, prompt) in UI_PIECES.items():
        items.append((name, cat, prompt))
    return items


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--asset", action="append", dest="assets", metavar="NOMBRE",
                         help="nombre de asset a generar (repetible). Ver --list.")
    parser.add_argument("--category", choices=sorted(CATEGORY_DEFAULTS.keys()),
                         help="generar todos los assets de una categoría")
    parser.add_argument("--all", action="store_true", help="generar todos los assets definidos")
    parser.add_argument("--list", action="store_true", help="listar los assets disponibles y salir")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"modelo de OpenRouter (default: {DEFAULT_MODEL})")
    parser.add_argument("--skip-existing", action="store_true",
                         help="no regenerar assets cuyo .png ya existe")
    parser.add_argument("--walk-sheet", action="append", dest="walk_sheets", metavar="NOMBRE",
                         help=f"generar un sprite-sheet de walk-cycle (repetible). Disponibles: {sorted(WALK_SHEETS)}")
    args = parser.parse_args()

    all_items = _all_items()

    if args.list:
        for name, cat, _prompt in all_items:
            print(f"{name:24s} [{cat}]")
        for name in WALK_SHEETS:
            print(f"{name:24s} [walk-sheet]")
        return

    if args.walk_sheets:
        api_key = _api_key()
        total_cost = 0.0
        failures = []
        unknown = set(args.walk_sheets) - set(WALK_SHEETS)
        if unknown:
            parser.error(f"walk-sheets desconocidos: {sorted(unknown)}")
        for name in args.walk_sheets:
            try:
                total_cost += generate_walk_sheet(name, api_key, args.model, args.skip_existing)
            except Exception as exc:  # noqa: BLE001
                print(f"[{name}] ERROR: {exc}")
                failures.append(name)
        if total_cost:
            print(f"\nCosto total reportado por OpenRouter: ${total_cost:.4f}")
        if failures:
            sys.exit(f"Fallaron {len(failures)} walk-sheet(s): {failures}")
        return

    if args.all:
        selected = all_items
    elif args.category:
        selected = [(n, c, p) for n, c, p in all_items if c == args.category]
    else:
        wanted = set(args.assets or [])
        if not wanted:
            parser.error("indicá --asset NOMBRE (una o más veces), --category, --all, o --list")
        unknown = wanted - {n for n, _c, _p in all_items}
        if unknown:
            parser.error(f"assets desconocidos: {sorted(unknown)}. Usá --list para ver los válidos.")
        selected = [(n, c, p) for n, c, p in all_items if n in wanted]

    api_key = _api_key()

    total_cost = 0.0
    failures = []
    for name, category, prompt in selected:
        try:
            total_cost += generate_asset(name, category, prompt, api_key, args.model, args.skip_existing)
        except Exception as exc:  # noqa: BLE001 - seguir con los demás assets
            print(f"[{name}] ERROR: {exc}")
            failures.append(name)

    if total_cost:
        print(f"\nCosto total reportado por OpenRouter: ${total_cost:.4f}")

    if failures:
        sys.exit(f"Fallaron {len(failures)} asset(s): {failures}")


if __name__ == "__main__":
    main()
