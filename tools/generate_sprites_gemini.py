#!/usr/bin/env python3
"""Genera los sprites del juego llamando directo a la API de Gemini
(Google AI, https://ai.google.dev) en vez de pasar por OpenRouter —
para cuando ya tenés una cuenta de Google AI paga y no querés pagar el
margen de un intermediario.

Requiere la variable de entorno GEMINI_API_KEY (https://aistudio.google.com/apikey)
y las librerías Pillow + numpy:

    pip install pillow numpy
    export GEMINI_API_KEY="tu_clave"

Uso: igual que generate_sprites_openrouter.py
    python3 tools/generate_sprites_gemini.py --list
    python3 tools/generate_sprites_gemini.py --asset hormiga_obrera
    python3 tools/generate_sprites_gemini.py --category insect
    python3 tools/generate_sprites_gemini.py --all --skip-existing

IMPORTANTE - incertidumbre de API: la doc pública de generación de
imágenes (ai.google.dev/gemini-api/docs/image-generation) describe un
endpoint nuevo `/v1beta/interactions` con forma de request/response que
no pude verificar contra una llamada real antes de escribir esto. Este
script:
  1. Prueba primero `/v1beta/interactions`.
  2. Si devuelve 404 (no existe todavía en tu proyecto/región), cae
     automáticamente al endpoint clásico y estable `generateContent`
     con `responseModalities: ["IMAGE"]`, que es la forma en que
     Gemini viene generando imágenes desde el lanzamiento de
     Gemini 2.5 Flash Image ("Nano Banana").
  3. En el primer asset que genere en cada corrida, imprime las claves
     de nivel superior de la respuesta cruda — así, si el formato real
     no coincide con lo documentado, se ve enseguida en vez de fallar
     en silencio o interpretar mal el JSON.

Corré primero con --asset para UN solo sprite y revisá que el .png haya
salido bien antes de tirar --all (que gasta créditos en las 33).
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
except ImportError:
    sys.exit("Faltan dependencias: pip install pillow numpy")

API_BASE = "https://generativelanguage.googleapis.com/v1beta"
INTERACTIONS_ENDPOINT = f"{API_BASE}/interactions"

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES_DIR = os.path.join(REPO_ROOT, "assets", "sprites")

DEFAULT_MODEL = "gemini-3.1-flash-image"

CHROMA_KEY = (255, 0, 255)
CHROMA_THRESHOLD = 55
CHROMA_FEATHER = 45

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

# Mismo diccionario que generate_sprites_openrouter.py (a propósito
# duplicado: son scripts standalone independientes, no una librería
# compartida). Si cambiás un prompt, replicalo en el otro si usás ambos.
ASSETS: dict[str, tuple[str, str]] = {
    "hormiga_obrera": ("insect", "a cute cartoon worker ant character for a garden-defense video game, brown color, big round eyes, three-quarter view"),
    "cucaracha_electrica": ("insect", "a cute cartoon cockroach crackling with yellow electric energy, comic video game enemy"),
    "escarabajo_blindado": ("insect", "a cute cartoon armored beetle with a thick metallic blue-gray shell, tank-like, video game enemy"),
    "mosca_pesada": ("insect", "a cute cartoon heavy chubby fly, dark gray, round body, video game enemy"),
    "grillo_saltarin": ("insect", "a cute cartoon jumping cricket, green, mid-leap pose, video game enemy"),
    "mystery_bug_silueta": ("insect", "a mysterious dark purple insect silhouette shape with a glowing white question mark on it, spooky but cute, video game enemy"),
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
    "zapato_viejo": ("weapon", "an old worn brown leather shoe, comic video game weapon icon, three-quarter view"),
    "chancla_goma": ("weapon", "a blue rubber flip-flop sandal, comic video game weapon icon, top view"),
    "matamoscas_metalico": ("weapon", "a metallic fly swatter with a wire mesh head, comic video game weapon icon"),
    "sarten_hierro": ("weapon", "a black cast iron frying pan, comic video game weapon icon, top view"),
    "pala_electrificada": ("weapon", "a metal garden shovel crackling with yellow electricity, comic video game weapon icon"),
    "don_beto": ("character", "a cheerful cartoon farmer character named Don Beto, older man with a mustache, straw hat, green overalls, holding a shoe raised up, full body, front view, video game character"),
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

ICON_ASSET = ("icon", "a bold cute app icon: a cartoon shoe squashing an angry cartoon ant, garden background, square composition, readable at small size")

_printed_debug_shape = False


def _api_key() -> str:
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        sys.exit(
            "Falta GEMINI_API_KEY. Exportala antes de correr el script:\n"
            '  export GEMINI_API_KEY="tu_clave"\n'
            "(obtenela en https://aistudio.google.com/apikey)"
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


def _post(url: str, api_key: str, payload: dict) -> tuple[int, dict]:
    headers = {"x-goog-api-key": api_key, "Content-Type": "application/json"}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            return exc.code, json.loads(body)
        except json.JSONDecodeError:
            raise RuntimeError(f"HTTP {exc.code} llamando a {url}: {body}") from exc


def _extract_image_b64_interactions(response: dict) -> str | None:
    # Caminos plausibles según la doc pública; se prueban todos porque
    # no está confirmado contra una llamada real.
    output_image = response.get("output_image") or response.get("interaction", {}).get("output_image")
    if output_image and output_image.get("data"):
        return output_image["data"]

    for step in response.get("steps", []):
        for block in step.get("content", []) if isinstance(step, dict) else []:
            if isinstance(block, dict) and block.get("type") == "image" and block.get("data"):
                return block["data"]
    return None


def _extract_image_b64_generate_content(response: dict) -> str | None:
    for candidate in response.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return inline["data"]
    return None


def _call_interactions(api_key: str, model: str, prompt: str, aspect_ratio: str | None) -> str:
    payload = {
        "model": model,
        "input": [{"type": "text", "text": prompt}],
        "response_format": {"type": "image", "mime_type": "image/png"},
    }
    if aspect_ratio:
        payload["response_format"]["aspect_ratio"] = aspect_ratio

    status, response = _post(INTERACTIONS_ENDPOINT, api_key, payload)

    global _printed_debug_shape
    if not _printed_debug_shape:
        print(f"    [debug] /interactions status={status} claves de nivel superior: {list(response.keys())}")
        _printed_debug_shape = True

    if status == 404:
        raise _EndpointNotFound()
    if status >= 400:
        raise RuntimeError(f"Gemini /interactions respondió {status}: {response}")

    b64 = _extract_image_b64_interactions(response)
    if not b64:
        raise RuntimeError(f"No se encontró imagen en la respuesta de /interactions: {json.dumps(response)[:800]}")
    return b64


def _call_generate_content(api_key: str, model: str, prompt: str) -> str:
    url = f"{API_BASE}/models/{model}:generateContent"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }
    status, response = _post(url, api_key, payload)
    if status >= 400:
        raise RuntimeError(f"Gemini generateContent respondió {status}: {response}")

    b64 = _extract_image_b64_generate_content(response)
    if not b64:
        raise RuntimeError(f"No se encontró imagen en la respuesta de generateContent: {json.dumps(response)[:800]}")
    return b64


class _EndpointNotFound(Exception):
    pass


def fetch_image_b64(api_key: str, model: str, prompt: str, aspect_ratio: str | None) -> str:
    try:
        return _call_interactions(api_key, model, prompt, aspect_ratio)
    except _EndpointNotFound:
        print("    /interactions no existe (404), usando generateContent clásico...")
        # generateContent no tiene modelos "-lite-image" separados en todos los
        # tiers; si el modelo pedido no aplica, se prueba tal cual igual.
        return _call_generate_content(api_key, model, prompt)


def remove_chroma_key(img: "Image.Image") -> "Image.Image":
    img = img.convert("RGBA")
    arr = np.array(img).astype(np.float32)
    key = np.array(CHROMA_KEY, dtype=np.float32)
    diff = np.sqrt(((arr[..., :3] - key) ** 2).sum(axis=-1))
    alpha_from_key = np.clip((diff - CHROMA_THRESHOLD) / CHROMA_FEATHER, 0.0, 1.0) * 255.0
    arr[..., 3] = np.minimum(arr[..., 3], alpha_from_key)
    return Image.fromarray(arr.astype(np.uint8), mode="RGBA")


def fit_transparent(img: "Image.Image", size: tuple[int, int]) -> "Image.Image":
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
    target_w, target_h = size
    img = img.convert("RGB")
    scale = max(target_w / img.width, target_h / img.height)
    new_size = (max(int(img.width * scale), 1), max(int(img.height * scale), 1))
    resized = img.resize(new_size, Image.LANCZOS)
    left = (new_size[0] - target_w) // 2
    top = (new_size[1] - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def generate_asset(name: str, category: str, base_prompt: str, api_key: str, model: str, skip_existing: bool) -> None:
    defaults = CATEGORY_DEFAULTS[category]
    dest_path = _dest_path(name, category)

    if skip_existing and os.path.exists(dest_path):
        print(f"[{name}] ya existe, se salta (--skip-existing)")
        return

    prompt = _build_prompt(base_prompt, defaults["transparent"])
    print(f"[{name}] generando con {model}...")

    b64 = fetch_image_b64(api_key, model, prompt, defaults.get("aspect_ratio"))
    img = Image.open(io.BytesIO(base64.b64decode(b64)))

    if defaults["transparent"]:
        img = remove_chroma_key(img)
        img = fit_transparent(img, defaults["size"])
    else:
        img = cover_opaque(img, defaults["size"])

    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    img.save(dest_path, "PNG")
    print(f"[{name}] listo -> {dest_path}")


def _all_items() -> list[tuple[str, str, str]]:
    items = [(name, cat, prompt) for name, (cat, prompt) in ASSETS.items()]
    items.append(("icon", ICON_ASSET[0], ICON_ASSET[1]))
    return items


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--asset", action="append", dest="assets", metavar="NOMBRE")
    parser.add_argument("--category", choices=sorted(CATEGORY_DEFAULTS.keys()))
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"default: {DEFAULT_MODEL}")
    parser.add_argument("--skip-existing", action="store_true")
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

    failures = []
    for name, category, prompt in selected:
        try:
            generate_asset(name, category, prompt, api_key, args.model, args.skip_existing)
        except Exception as exc:  # noqa: BLE001
            print(f"[{name}] ERROR: {exc}")
            failures.append(name)

    if failures:
        sys.exit(f"Fallaron {len(failures)} asset(s): {failures}")


if __name__ == "__main__":
    main()
