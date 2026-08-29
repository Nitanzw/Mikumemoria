#!/usr/bin/env python3
"""Genera la música del juego usando la API de Suno (https://sunoapi.org).

Requiere la variable de entorno SUNO_API_KEY con una clave válida obtenida
en https://sunoapi.org/api-key. No pases la clave por línea de comandos:
queda guardada en el historial de la shell.

Uso:
    export SUNO_API_KEY="tu_clave"
    python3 tools/generate_music_suno.py --list
    python3 tools/generate_music_suno.py --track menu_theme
    python3 tools/generate_music_suno.py --track level_theme_1 --track level_theme_2
    python3 tools/generate_music_suno.py --all
    python3 tools/generate_music_suno.py --all --skip-existing

Qué hace, por cada pista pedida:
    1. POST /api/v1/generate  -> arranca la generación, devuelve un taskId
    2. GET  /api/v1/generate/record-info  (con polling) -> espera SUCCESS
    3. Descarga el mp3 resultante a assets/sounds/music/<nombre>.mp3

Suno solo guarda los archivos generados 15 días: hay que correr este
script y commitear el resultado, no depender de las URLs que devuelve.

AudioManager (scripts/autoload/audio_manager.gd) ya busca cada pista
probando primero .ogg, después .mp3 y por último el placeholder .wav
sintetizado, así que no hace falta tocar GDScript para que el juego
empiece a usar lo que genere este script.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

API_BASE = "https://api.sunoapi.org"
GENERATE_ENDPOINT = f"{API_BASE}/api/v1/generate"
STATUS_ENDPOINT = f"{API_BASE}/api/v1/generate/record-info"

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(REPO_ROOT, "assets", "sounds", "music")

DEFAULT_MODEL = "V4_5"
POLL_INTERVAL_SECONDS = 8
POLL_TIMEOUT_SECONDS = 8 * 60

# La API exige callBackUrl aunque la doc lo marca opcional. Este script
# no depende del webhook (hace polling con record-info), así que basta
# con una URL sintácticamente válida; example.com es el dominio reservado
# de IANA para esto y no necesita servidor propio.
DEFAULT_CALLBACK_URL = "https://example.com/suno-callback-unused"

# nombre -> (título, estilo, prompt)
#
# Ojo con el estilo: la primera tanda pedía literalmente "8-bit/chiptune"
# y "tempo rapido", y el resultado sonaba a arcade y cansaba en pocos
# niveles. Ahora todo el set es ACÚSTICO y de dinámica pareja, que es lo
# que pega con el arte pintado del juego y se banca escucharlo seguido.
# Los nombres son justo los que ya usa/usará el código GDScript
# (AudioManager.play_music("menu_theme"), "level_theme_<capítulo>", etc).
TRACKS: dict[str, tuple[str, str, str]] = {
    "menu_theme": (
        "El Huerto de Sofia - Menu",
        "folk acustico calido, guitarra, ukelele, marimba suave, tempo tranquilo",
        "Tema de menu de un juego de huerta. Guitarra acustica y ukelele, marimba de fondo, sensacion de tarde de sol en el jardin, relajado y acogedor. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_1": (
        "El Huerto de Tomates",
        "folk acustico alegre, guitarra ritmica, palmas suaves, tempo medio",
        "Nivel en una huerta de tomates. Guitarra acustica ritmica, palmas suaves y flauta, alegre y liviano, nada frenetico. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_2": (
        "El Invernadero",
        "acustico calido, vibrafono, cuerdas suaves, tempo medio lento",
        "Nivel dentro de un invernadero humedo. Vibrafono y cuerdas suaves, aire tibio y verde, tranquilo. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_3": (
        "La Cueva Subterranea",
        "ambiente acustico con eco, contrabajo pizzicato, percusion tenue",
        "Nivel en una cueva bajo tierra. Contrabajo en pizzicato con eco y percusion tenue, curioso y misterioso, no de miedo. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_4": (
        "El Cultivo Radiactivo",
        "folk con synth analogico suave, tempo medio, texturas calidas",
        "Nivel en un cultivo raro y brillante. Guitarra con un synth analogico suave por encima, curioso y un poco extraño, sin estridencias. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_5": (
        "El Pantano",
        "groove acustico lento, percusion de madera, bajo redondo",
        "Nivel en un pantano. Groove lento con percusion de madera y bajo redondo, humedo y perezoso. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_6": (
        "Laboratorio Mutante",
        "acustico con cuerdas curiosas, pizzicato juguetón, tempo medio",
        "Nivel en un laboratorio abandonado. Cuerdas en pizzicato juguetonas, curioso y travieso, nada tenso. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_7": (
        "Fabrica de Cascos",
        "percusion de madera y metal suave, groove medio, acustico",
        "Nivel en una fabrica vieja. Percusion de madera y metal suave marcando un groove medio, ritmico pero calmo. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_8": (
        "Red de Tuneles Express",
        "acustico ritmico, guitarra staccato, bongos, tempo medio alto",
        "Nivel de tuneles. Guitarra staccato y bongos, con movimiento y ganas, sin llegar a ser frenetico. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_9": (
        "El Bunker Enemigo",
        "cuerdas graves suaves, percusion contenida, tempo medio",
        "Nivel de infiltracion. Cuerdas graves suaves y percusion contenida, expectante y sigiloso. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_10": (
        "El Nucleo Reina",
        "orquesta acustica calida, cuerdas y maderas, epico contenido",
        "Nivel final. Orquesta acustica calida con cuerdas y maderas, sensacion de cierre importante, epico pero sin estridencia. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "boss_theme": (
        "Pelea de Jefe",
        "percusion tribal, cuerdas tensas, tempo medio alto, acustico",
        "Musica de pelea contra un insecto jefe. Percusion tribal y cuerdas tensas, urgente y con pulso, se nota que es una pelea pero sigue siendo acustica y agradable. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_11": (
        "Tarde de Riego",
        "acustico suave, guitarra con arpegios, flauta, tempo lento",
        "Nivel tranquilo de huerta al atardecer. Arpegios de guitarra y flauta, sereno. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_12": (
        "Entre los Girasoles",
        "folk luminoso, mandolina, acordeon suave, tempo medio",
        "Nivel entre girasoles altos. Mandolina y acordeon suave, luminoso y campestre. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_13": (
        "Despues de la Lluvia",
        "acustico fresco, piano suave, cuerdas livianas, tempo medio lento",
        "Nivel despues de la lluvia. Piano suave y cuerdas livianas, fresco y limpio. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
    "level_theme_14": (
        "El Galpon de Herramientas",
        "acustico juguetón, banjo, percusion de cajon, tempo medio",
        "Nivel en el galpon. Banjo y cajon peruano, juguetón y con swing. instrumental, sin voces, sin letra, loop limpio, mezcla suave sin picos, dinamica pareja para escuchar largo rato sin cansar.",
    ),
}

def _api_key() -> str:
    key = os.environ.get("SUNO_API_KEY", "").strip()
    if not key:
        sys.exit(
            "Falta SUNO_API_KEY. Exportala antes de correr el script:\n"
            '  export SUNO_API_KEY="tu_clave"\n'
            "(obtenela en https://sunoapi.org/api-key)"
        )
    return key


USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


def _request(url: str, api_key: str, method: str = "GET", payload: dict | None = None) -> dict:
    # Cloudflare (delante de api.sunoapi.org) devuelve 403 "error code:
    # 1010" al User-Agent por defecto de urllib; con uno de navegador pasa.
    headers = {"Authorization": f"Bearer {api_key}", "User-Agent": USER_AGENT, "Accept": "application/json"}
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} llamando a {url}: {body}") from exc

    parsed = json.loads(body)
    if parsed.get("code") != 200:
        raise RuntimeError(f"Suno respondió error: {parsed}")
    return parsed["data"]


def start_generation(name: str, api_key: str, model: str) -> str:
    title, style, prompt = TRACKS[name]
    payload = {
        "prompt": prompt,
        "model": model,
        "customMode": True,
        "style": style,
        "title": title,
        "instrumental": True,
        "callBackUrl": DEFAULT_CALLBACK_URL,
    }
    data = _request(GENERATE_ENDPOINT, api_key, method="POST", payload=payload)
    task_id = data["taskId"]
    print(f"  [{name}] tarea creada: {task_id}")
    return task_id


def wait_for_result(task_id: str, api_key: str) -> dict:
    url = f"{STATUS_ENDPOINT}?taskId={task_id}"
    deadline = time.monotonic() + POLL_TIMEOUT_SECONDS

    while time.monotonic() < deadline:
        data = _request(url, api_key)
        status = data.get("status")

        if status == "SUCCESS":
            # La doc dice response.data con audio_url; en la práctica la API
            # devuelve response.sunoData con audioUrl (y 2 variaciones por
            # tarea). Se prueban ambas formas por las dudas.
            response = data.get("response", {})
            items = response.get("sunoData") or response.get("data") or []
            if not items:
                raise RuntimeError(f"Tarea {task_id} exitosa pero sin audio en la respuesta: {data}")
            chosen = items[0]
            return {
                "audio_url": chosen.get("audioUrl") or chosen.get("audio_url"),
                "duration": chosen.get("duration"),
            }

        if status == "FAILED":
            raise RuntimeError(f"Tarea {task_id} falló: {data}")

        print(f"    ...estado: {status}, esperando {POLL_INTERVAL_SECONDS}s")
        time.sleep(POLL_INTERVAL_SECONDS)

    raise TimeoutError(f"Tarea {task_id} no terminó en {POLL_TIMEOUT_SECONDS}s")


def download(url: str, dest_path: str) -> None:
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp, open(dest_path, "wb") as f:
        f.write(resp.read())


def generate_track(name: str, api_key: str, model: str, skip_existing: bool) -> None:
    dest_path = os.path.join(OUTPUT_DIR, f"{name}.mp3")
    if skip_existing and os.path.exists(dest_path):
        print(f"[{name}] ya existe, se salta (--skip-existing)")
        return

    print(f"[{name}] generando con Suno ({model})...")
    task_id = start_generation(name, api_key, model)
    result = wait_for_result(task_id, api_key)

    audio_url = result.get("audio_url")
    if not audio_url:
        raise RuntimeError(f"[{name}] la respuesta no trae audio_url: {result}")

    download(audio_url, dest_path)
    duration = result.get("duration")
    print(f"[{name}] listo -> {dest_path} ({duration}s)" if duration else f"[{name}] listo -> {dest_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--track", action="append", dest="tracks", metavar="NOMBRE",
                         help="nombre de pista a generar (repetible). Ver --list.")
    parser.add_argument("--all", action="store_true", help="generar todas las pistas definidas en TRACKS")
    parser.add_argument("--list", action="store_true", help="listar las pistas disponibles y salir")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"modelo de Suno (default: {DEFAULT_MODEL})")
    parser.add_argument("--skip-existing", action="store_true",
                         help="no regenerar pistas cuyo .mp3 ya existe en assets/sounds/music/")
    args = parser.parse_args()

    if args.list:
        for name, (title, style, _prompt) in TRACKS.items():
            print(f"{name:16s} {title!r:30s} [{style}]")
        return

    if args.all:
        names = list(TRACKS.keys())
    else:
        names = args.tracks or []

    if not names:
        parser.error("indicá --track NOMBRE (una o más veces), --all, o --list")

    unknown = [n for n in names if n not in TRACKS]
    if unknown:
        parser.error(f"pistas desconocidas: {unknown}. Usá --list para ver las válidas.")

    api_key = _api_key()

    failures = []
    for name in names:
        try:
            generate_track(name, api_key, args.model, args.skip_existing)
        except Exception as exc:  # noqa: BLE001 - queremos seguir con las demás pistas
            print(f"[{name}] ERROR: {exc}")
            failures.append(name)

    if failures:
        sys.exit(f"Fallaron {len(failures)} pista(s): {failures}")


if __name__ == "__main__":
    main()
