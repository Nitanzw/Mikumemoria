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
    from scipy import ndimage
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

BG_COLOR_TOLERANCE = 65.0  # distancia RGB al color de fondo sampleado del borde
BG_FEATHER_SIGMA = 2.0  # blur (px) del borde de la máscara, evita contorno duro

STYLE_SUFFIX = (
    ", flat cartoon vector game-icon art style, bold clean black outline, "
    "simple cel shading, vibrant saturated colors, centered single subject, "
    "no text, no watermark, no signature, high detail"
)
TRANSPARENT_BG_INSTRUCTION = (
    ", isolated on a solid flat magenta background (#FF00FF), no shadow, "
    "no gradient, no other objects, no floor"
)

CATEGORY_DEFAULTS = {
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

# El icono vive en la raiz del repo, no en assets/sprites/
ICON_ASSET = ("icon", "a bold cute app icon: a cartoon shoe squashing an angry cartoon ant, garden background, square composition, readable at small size")


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


def _build_prompt(base_prompt: str, transparent: bool) -> str:
    prompt = base_prompt + STYLE_SUFFIX
    if transparent:
        prompt += TRANSPARENT_BG_INSTRUCTION
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
    """Quita el fondo sin asumir un color fijo: samplea el color real del
    borde de la imagen y hace flood-fill (componentes conexas) desde ese
    borde, así solo se borra lo que está *conectado* a él (evita agujeros
    si el sujeto tiene, por casualidad, un tono parecido en el medio)."""
    img = img.convert("RGBA")
    arr = np.array(img).astype(np.float32)
    rgb = arr[..., :3]
    h, w = rgb.shape[:2]

    border_mask = np.zeros((h, w), dtype=bool)
    border_mask[0, :] = border_mask[-1, :] = True
    border_mask[:, 0] = border_mask[:, -1] = True
    key_color = rgb[border_mask].mean(axis=0)

    dist = np.sqrt(((rgb - key_color) ** 2).sum(axis=-1))
    bg_candidate = dist < BG_COLOR_TOLERANCE

    labeled, _ = ndimage.label(bg_candidate)
    border_labels = set(labeled[border_mask].tolist()) - {0}
    connected_bg = np.isin(labeled, list(border_labels)) if border_labels else np.zeros((h, w), dtype=bool)

    alpha = np.where(connected_bg, 0.0, 255.0)
    alpha = ndimage.gaussian_filter(alpha, sigma=BG_FEATHER_SIGMA)
    arr[..., 3] = np.minimum(arr[..., 3], alpha)

    return Image.fromarray(arr.astype(np.uint8), mode="RGBA")


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

    prompt = _build_prompt(base_prompt, defaults["transparent"])
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
    args = parser.parse_args()

    all_items = _all_items()

    if args.list:
        for name, cat, _prompt in all_items:
            print(f"{name:24s} [{cat}]")
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
