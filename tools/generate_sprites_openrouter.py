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

## Sofía va en UNA sola generación con las seis emociones adentro: seis
## llamadas sueltas devuelven seis caras distintas. Es el mismo truco que
## mantiene idéntico al bicho entre los cuadros de caminata.
##
## Además la hoja se pide CONTRA una imagen de referencia (ver
## call_with_reference), que es lo que ata la cara a un diseño elegido y
## no a lo que el modelo improvise esa vez. Los dos mecanismos se suman:
## la referencia fija QUIÉN es, la hoja única fija que las seis celdas
## salgan del mismo dibujo.
SOFIA_DESIGN = (
    "a young woman gardener about twenty years old, heart-shaped face, fair light skin, light freckles across the nose only, large bright brown eyes, a small upturned nose, thick dark brown wavy hair tied up in a loose messy bun with a few strands loose at the temples, wearing a mustard-yellow hoodie with the sleeves pushed up and olive-green denim overalls, white and orange over-ear headphones resting around her neck"
)

## La cara elegida, guardada como imagen. El texto de arriba describe el
## diseño pero no lo fija: dos generaciones con el mismo texto dan dos
## caras parecidas, no la misma. Pasarle ESTA imagen como referencia a
## call_with_reference es lo que hace que el retrato del diálogo y la
## Sofía del menú sean la misma persona aunque salgan de llamadas
## distintas. Si algún día se cambia la cara, se cambia este archivo.
SOFIA_REFERENCE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sofia_reference.png")

SOFIA_SHEET_PROMPT = (
    "a 3x2 character expression sheet of 6 head-and-shoulders portraits in "
    "three columns and two rows, with NO grid lines, NO borders and NO frames "
    "between them, the portraits clearly separated by wide empty background. "
    "Every portrait shows the exact same character: " + SOFIA_DESIGN + ". "
    "Identical face, identical hair, identical clothes, identical camera angle "
    "and identical size in all 6 portraits, front view, chest up. "
    "Only the facial expression changes between cells. "
    "Reading order left to right, top row: neutral calm, warm happy smile, sad "
    "downcast. Bottom row: angry determined frown, worried anxious, surprised "
    "wide-eyed open mouth"
)

CATEGORY_DEFAULTS = {
    # Pantallas de menú (tienda, habilidades, mapa). Opacas y verticales.
    "ui_background": {"dir": "ui", "size": (1080, 1920), "transparent": False, "aspect_ratio": "9:16"},
    # Piezas de interfaz recortadas (paneles, íconos).
    "ui_panel": {"dir": "ui", "size": (512, 256), "transparent": True, "aspect_ratio": "2:1"},
    "ui_icon": {"dir": "ui", "size": (128, 128), "transparent": True, "aspect_ratio": "1:1"},
    "insect": {"dir": "insects", "size": (128, 128), "transparent": True, "aspect_ratio": "1:1"},
    "weapon": {"dir": "weapons", "size": (128, 128), "transparent": True, "aspect_ratio": "1:1"},
    "character": {"dir": "character", "size": (512, 768), "transparent": True, "aspect_ratio": "9:16"},
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
    # Iconos de los objetos pasivos de la tienda (ver ItemSystem).
    "item_guantes": ("ui_icon", "a pair of sturdy brown leather gardening work gloves, thick reinforced knuckles, worn and used, stacked one over the other, game item icon, readable at small size"),
    "item_botiquin": ("ui_icon", "a small cream-colored first aid tin box with a red cross on the lid, slightly open showing bandages, homemade and worn, game item icon, readable at small size"),
    "item_delantal": ("ui_icon", "a thick padded green gardening apron with reinforced stitching and a front pocket, folded neatly, sturdy protective look, game item icon, readable at small size"),
    "item_repelente": ("ui_icon", "a homemade glass spray bottle filled with cloudy green herbal liquid, cork and hand-tied label, a few leaves at its base, game item icon, readable at small size"),
    "item_trebol": ("ui_icon", "a single bright four-leaf clover with dewdrops and a soft golden glow around it, lucky charm, game item icon, readable at small size"),
    "item_frasco": ("ui_icon", "a glass mason jar packed with gold coins, metal lid slightly open, coins spilling over the rim, warm shine, game item icon, readable at small size"),
    "item_reloj": ("ui_icon", "a small wooden-framed hourglass with golden sand falling, brass caps, game item icon, readable at small size"),
    "item_lupa": ("ui_icon", "an old brass magnifying glass with a worn wooden handle and a clear round lens, game item icon, readable at small size"),
    "item_botas": ("ui_icon", "a pair of yellow rubber gardening boots with muddy soles, standing side by side, game item icon, readable at small size"),
    "item_reloj_bolsillo": ("ui_icon", "an ornate golden pocket watch on a chain, lid open showing the clock face, faint blue glow, game item icon, readable at small size"),
    "item_campo": ("ui_icon", "a glowing translucent blue energy dome shockwave expanding outward in concentric rings, game item icon, readable at small size"),
    "item_rayo": ("ui_icon", "a dark storm cloud with a bright yellow lightning bolt striking down from it, game item icon, readable at small size"),
    # Piezas del HUD de partida. Se ensamblan en hud.tscn: la barra va
    # 9-sliceada a lo ancho, el medallón y las placas van encima.
    "hud_bar": ("ui_panel", "a long horizontal ornate game HUD bar, dark carved stone slab with a polished bronze frame and rivets, symmetrical, completely empty flat surface in the middle with no text and no icons, seen straight from the front"),
    "hud_medallion": ("ui_icon", "an ornate circular bronze medallion frame for a game timer, thick decorated rim with small rivets, hollow dark empty center, seen straight from the front, no text"),
    "hud_badge": ("ui_icon", "an ornate bronze shield-shaped badge plaque for a game HUD, decorated border, flat dark empty center, seen straight from the front, no text no emblem"),
    # Barra de vidas de la pelea de jefe, abajo de la pantalla.
    "hud_bottom_panel": ("ui_panel", "a long horizontal ornate game UI panel, dark carved wood planks with a thick bronze frame and corner brackets, symmetrical, completely empty flat surface with no text and no icons, seen straight from the front"),
    "hud_boss_icon": ("ui_icon", "a circular bronze medallion with an angry red beetle face emblem in the center, game boss health icon, seen straight from the front, no text"),
    "hud_heart_icon": ("ui_icon", "a circular bronze medallion with a bright red heart emblem in the center, game player health icon, seen straight from the front, no text"),
    # Pantalla de fin de nivel.
    "res_plaque": ("ui_panel", "a large RECTANGULAR ornate wooden panel for a game results screen, straight square edges and flat top and bottom, warm carved wood planks with a thick bronze border and decorative corner brackets with rivets, completely empty flat surface with no text and no icons, not a shield, seen straight from the front"),
    "res_banner": ("ui_panel", "a golden ornate ribbon banner with scrolled forked ends and a decorative border, empty surface with no text, game reward banner, seen straight from the front"),
    "res_row": ("ui_panel", "a horizontal dark recessed wooden slot strip with a thin bronze inner edge, empty, a row background for a game stats list, no text, seen straight from the front"),
    "icon_medal": ("ui_icon", "a golden medal on a striped ribbon, award emblem, game icon, seen straight from the front, no text"),
    "icon_coinbag": ("ui_icon", "a small brown cloth coin pouch tied with string, gold coins spilling from the top, game reward icon, seen straight from the front, no text"),
    "hud_star": ("ui_icon", "a golden five-pointed star with a small laurel wreath under it, game score emblem, seen straight from the front, no text"),
    "hud_ribbon": ("ui_panel", "a horizontal green cloth banner ribbon with bronze end caps and forked tails, empty surface with no text, game UI title banner, seen straight from the front"),
    # Marco verde con guardas de hojas para el resumen de nivel, y los
    # íconos de sus tres botones. Van aparte del res_plaque de madera:
    # el marco encuadra todo y la placa queda adentro.
    "res_frame": ("ui_panel", "a large RECTANGULAR ornate game panel frame, deep olive green painted wood with a polished gold inner edge and gold corner brackets, small carved leaf and vine ornaments along the border, the whole center completely hollow and empty, straight square edges, no text no icons, seen straight from the front"),
    "res_plate": ("ui_panel", "a small horizontal golden plaque with a decorated scrolled border and a flat empty center, a nameplate for a game score number, no text, seen straight from the front"),
    "btn_menu": ("ui_icon", "a rolled parchment scroll tied with a red ribbon, seen straight from the front, game menu button icon, readable at small size, no text"),
    "btn_shop": ("ui_icon", "a woven wicker market basket with a few vegetables and a gold coin inside, seen straight from the front, game shop button icon, readable at small size, no text"),
    "btn_next": ("ui_icon", "a bold golden double chevron arrow pointing right, thick beveled metal with a dark outline, seen straight from the front, game continue button icon, readable at small size, no text"),
    # Barra de nivel de los casilleros de la tienda. Van MUY anchas y
    # bajas: se 9-slicean a lo largo, así que sólo el centro se estira.
    "bar_track": ("ui_panel", "an extremely wide and very short empty horizontal progress bar slot for a game UI, like a thin trough, a dark recessed groove carved into stone with a thin polished bronze rim and fully rounded ends, completely dark and empty inside, ten times wider than tall, seen straight from the front, no text no icons no fill"),
    # Ojo: pedirlo como "barra" devolvía una línea hueca. Describirlo como
    # una pastilla SÓLIDA rellena de punta a punta es lo que funciona.
    "bar_fill": ("ui_panel", "a solid filled rounded-rectangle pill shape, completely filled edge to edge with bright glossy leaf-green, like a green plastic lozenge, a soft lighter glossy highlight along the upper half, fully opaque solid green with no hollow center and no outline, wide and short proportions, seen straight from the front, no text no icons"),
    "bar_fill_gold": ("ui_panel", "an extremely wide and very short horizontal progress bar fill for a game UI, like a thin bright bar, solid glossy warm polished gold with a lighter glossy highlight stripe along the top and fully rounded ends, fully opaque with no transparency, ten times wider than tall, seen straight from the front, no text no icons no container"),
    "item_lanzallamas": ("ui_icon", "a homemade metal flamethrower nozzle shooting a burst of orange flame to the side, rustic and improvised, game item icon, readable at small size"),
}

# El icono vive en la raiz del repo, no en assets/sprites/
ICON_ASSET = ("icon", "a bold cute app icon: a cartoon shoe squashing an angry cartoon ant, garden background, square composition, readable at small size")

# --- Sprite sheets de walk-cycle (grid NxM en una sola imagen, se generan
# en una sola llamada para que los frames sean consistentes entre sí -
# pedirle al modelo N imagenes separadas da resultados demasiado
# distintos frame a frame). Se parte en celdas en post-proceso local. ---
# 256 y no 128: los jefes se dibujan a escala 1.7 sobre un lienzo de 540
# que en un celular de 1440 se escala otras 2.67 veces. Un cuadro de 128px
# terminaba estirado casi 4,5 veces y se veía pixelado. La hoja cruda es de
# 1024x1024, así que 256 por cuadro sale del mismo dibujo, sin regenerar.
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
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "hormiga_obrera_walk",
    },

    "cucaracha_electrica_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon cockroach crackling with yellow electric energy, dark reddish-brown shell with glowing yellow lightning arcs around its body, small sparks, speedy alert posture, big round eyes, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the legs and the electric arcs change between poses"
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "cucaracha_electrica_walk",
    },
    "escarabajo_blindado_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute but tough cartoon beetle with a thick metallic blue-grey armored shell with riveted plates, short stubby legs, heavy solid stance, small determined eyes, scratches on the armor, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the legs move between poses, in a different position of a walking cycle"
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "escarabajo_blindado_walk",
    },
    "mosca_pesada_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute chubby cartoon housefly, round heavy dark grey body, translucent iridescent wings, big compound red eyes, tiny legs tucked in, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "only the wings change position between poses"
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "mosca_pesada_walk",
    },
    "grillo_saltarin_walk": {
        "prompt": (
            "a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid "
            "lines, NO borders and NO frames between them, the poses clearly "
            "separated by wide empty background, each pose shows the exact same cute cartoon green cricket, powerful folded hind legs, long antennae, bright leaf-green body with lighter belly, cheerful energetic expression, "
            "identical character design, IDENTICAL SIZE and camera angle in all 4 poses, "
            "the character fills each pose the same amount, same color, "
            "the hind legs go through a leap: crouched, pushing off, extended in the air, landing"
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "grillo_saltarin_walk",
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
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "hormiga_ladrona_walk",
    },
    "abejorro_pinata_walk": {
        "prompt": (
            'a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid lines, NO borders and NO frames between them, the poses clearly separated by wide empty background, each pose shows the exact same cute cartoon bumblebee whose body is made of a colorful layered paper pinata, orange and black crepe-paper fringe, paper wings, festive party look, identical character design, identical colors and identical camera angle in all 4 poses. CRITICAL: the creature is drawn at exactly the same SIZE in all 4 cells and fills the same amount of its cell in every pose, never closer and never further away. Its two wings are fully spread and clearly visible in ALL four poses, never folded away and never missing. Only the legs and the wing angle change.'
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
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
        "frame_size": (256, 256),
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
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "escarabajo_radiactivo_walk",
    },
    "lombriz_gigante_walk": {
        "prompt": (
            'a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid lines, NO borders and NO frames between them, the poses clearly separated by wide empty background, each pose shows the exact same cute cartoon giant earthworm, thick pink segmented glossy body, small simple friendly face at one end, damp soil crumbs stuck to its skin, identical character design, identical colors and identical camera angle in all 4 poses. CRITICAL: the creature is drawn at exactly the same SIZE in all 4 cells and fills the same amount of its cell in every pose, never closer and never further away. The worm has exactly the same LENGTH and the same thickness in all four poses: only the curve of its body changes, it never stretches longer nor shrinks shorter between cells.'
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "lombriz_gigante_walk",
    },
    "mutante_volador_walk": {
        "prompt": (
            'a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid lines, NO borders and NO frames between them, the poses clearly separated by wide empty background, each pose shows the exact same cute cartoon mutant flying insect with a reddish-brown body, four purple wings, an extra pair of asymmetric eyes on its forehead, slightly lumpy mutated body, identical character design, identical colors and identical camera angle in all 4 poses. CRITICAL: the creature is drawn at exactly the same SIZE in all 4 cells and fills the same amount of its cell in every pose, never closer and never further away. All four wings are fully spread in ALL four poses. Only the legs and the wing angle change between cells.'
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
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
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "centella_blindada_walk",
    },
    "rayo_insecto_walk": {
        "prompt": (
            'a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid lines, NO borders and NO frames between them, the poses clearly separated by wide empty background, each pose shows the exact same cute cartoon insect with a SOLID OPAQUE bright yellow body, a clear head with two antennae, six legs and a segmented abdomen, shaped with sharp zigzag lightning edges, small electric sparks around it as an accent, identical character design, identical colors and identical camera angle in all 4 poses. CRITICAL: the creature is drawn at exactly the same SIZE in all 4 cells and fills the same amount of its cell in every pose, never closer and never further away. The insect body must be clearly recognizable as a creature with head, legs and antennae in ALL four poses: it is an insect made of lightning, NOT a cloud of lightning bolts. No transparency, no green tones. Only the legs move between cells.'
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
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
        "frame_size": (256, 256),
        "dest_dir": "insects",
        "dest_prefix": "coraza_antigua_walk",
    },
    "reina_primordial_walk": {
        "prompt": (
            'a 2x2 sprite sheet of 4 poses in two rows and two columns, with NO grid lines, NO borders and NO frames between them, the poses clearly separated by wide empty background, each pose shows the exact same majestic cartoon insect queen, large regal body in deep purple and gold, ornate crown-like antennae, layered iridescent wings, glowing amber eyes, identical character design, identical colors and identical camera angle in all 4 poses. CRITICAL: the creature is drawn at exactly the same SIZE in all 4 cells and fills the same amount of its cell in every pose, never closer and never further away. Her wings are fully spread and identical in ALL four poses, never folded and never smaller in one cell. Only the legs and the wing angle change.'
        ),
        "grid": (2, 2),
        "frame_size": (256, 256),
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
    cells = []
    for row in range(rows):
        for col in range(cols):
            left = x_cuts[col] + pad
            right = x_cuts[col + 1] - pad
            top = y_cuts[row] + pad
            bottom = y_cuts[row + 1] - pad
            cells.append(key_out(img.crop((left, top, right, bottom))))
    return _normalize_scale(cells, frame_size)


def _normalize_scale(cells: list["Image.Image"], frame_size: tuple[int, int]) -> list["Image.Image"]:
    """Escala los cuadros para que el bicho mida lo mismo en todos.

    El modelo dibuja cada pose del tamaño que se le ocurre — a la
    mosca_pesada le salían cuadros con 32% de diferencia de alto, y al
    reproducirlos el bicho late de tamaño mientras camina. Repetir la
    generación no lo arregla: probado, vuelve a salir descentrado.

    Se mide el alto del sujeto (su caja opaca) en cada cuadro y se lleva
    a la mediana. El alto y no el ancho: lo que cambia legítimamente
    entre poses es a lo ancho (alas que se abren, lombriz que se estira),
    mientras que el alto de un bicho caminando es estable.
    """
    boxes = [c.getbbox() for c in cells]
    heights = [(b[3] - b[1]) if b else 0 for b in boxes]
    usable = sorted(h for h in heights if h > 0)
    if not usable:
        return [fit_transparent(c, frame_size) for c in cells]
    target = usable[len(usable) // 2]

    scaled = []
    for cell, box, height in zip(cells, boxes, heights):
        if box is None or height <= 0:
            scaled.append(None)
            continue
        subject = cell.crop(box)
        scale = target / height
        scaled.append(subject.resize(
            (max(int(subject.width * scale), 1), max(int(subject.height * scale), 1)),
            Image.LANCZOS))

    # El lienzo tiene que entrar al cuadro MÁS ANCHO de la serie, si no un
    # sujeto más ancho que alto se recorta: le pasó a la lombriz estirada,
    # que salía cortada en los 4 cuadros. Y tiene que ser el mismo lienzo
    # para todos, porque es lo que mantiene la escala pareja.
    widest = max((im.width for im in scaled if im), default=target)
    # El margen va proporcional, no en píxeles fijos: el lienzo después se
    # escala a frame_size, y 4px sobre un lienzo grande se vuelven menos de
    # uno al reducir, con lo que el sujeto igual toca el borde.
    side = max(int(target * 1.35), int(widest * 1.08) + 4)

    out = []
    for cell, subject in zip(cells, scaled):
        if subject is None:
            out.append(fit_transparent(cell, frame_size))
            continue
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(subject, ((side - subject.width) // 2, (side - subject.height) // 2), subject)
        out.append(fit_transparent(canvas, frame_size))
    return out


def generate_walk_sheet(name: str, api_key: str, model: str, skip_existing: bool) -> float:
    spec = WALK_SHEETS[name]
    cols, rows = spec["grid"]
    dest_dir = os.path.join(SPRITES_DIR, spec["dest_dir"])
    first_frame_path = os.path.join(dest_dir, f"{spec['dest_prefix']}_0.png")

    if skip_existing and os.path.exists(first_frame_path):
        print(f"[{name}] ya existe, se salta (--skip-existing)")
        return 0.0

    # POLISHED_STYLE y no STYLE_SUFFIX: el arte fijo del juego está en el
    # estilo pulido (mismo que Sofía, los fondos y la UI), así que un ciclo
    # en el estilo plano viejo hace que el bicho cambie de dibujo entre
    # estar quieto y caminar.
    prompt = spec["prompt"] + POLISHED_STYLE + GREEN_SCREEN_BG_INSTRUCTION
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


## El endpoint de imágenes es solo texto. El de chat, en cambio, acepta
## imágenes de entrada, y el mismo modelo redibuja a partir de una. Eso es
## lo que permite fijar la cara de un personaje UNA vez y pedir después
## todas las poses contra esa cara, en vez de depender de que todo salga
## de una única generación (que funciona, pero obliga a que todo comparta
## encuadre: no se puede meter un plano entero y un primer plano juntos).
CHAT_ENDPOINT = f"{API_BASE}/chat/completions"


def call_with_reference(api_key: str, model: str, prompt: str,
                        reference_png: bytes, timeout: int = 240) -> tuple["Image.Image", float]:
    """Genera una imagen usando otra como referencia visual.

    Devuelve (imagen, costo). El modelo copia cara, ropa y estilo de la
    referencia y aplica lo que pida el prompt; conviene que el prompt diga
    explícitamente qué se mantiene igual, porque si solo se pide la pose
    nueva a veces se toma licencias con la cara.
    """
    ref_b64 = base64.b64encode(reference_png).decode("ascii")
    payload = {
        "model": model,
        "modalities": ["image", "text"],
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": prompt},
            {"type": "image_url", "image_url": {"url": "data:image/png;base64," + ref_b64}},
        ]}],
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "User-Agent": USER_AGENT,
    }
    req = urllib.request.Request(
        CHAT_ENDPOINT, data=json.dumps(payload).encode("utf-8"),
        headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} llamando a {CHAT_ENDPOINT}: {detail}") from exc

    message = body["choices"][0]["message"]
    images = message.get("images") or []
    if not images:
        raise RuntimeError(f"la respuesta no trae imagen: {str(message.get('content'))[:300]}")
    data_url = images[0]["image_url"]["url"]
    img = Image.open(io.BytesIO(base64.b64decode(data_url.split(",", 1)[1])))
    return img, float(body.get("usage", {}).get("cost", 0.0) or 0.0)


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
