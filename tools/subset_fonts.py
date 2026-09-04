"""Baja las Noto que hacen falta y las recorta a los glifos usados.

Correr despues de tocar assets/i18n/ui.csv:

    pip install fonttools
    python3 tools/subset_fonts.py


Sin recortar, la Noto de chino sola pesa ~16MB. Recortada a los caracteres
que aparecen de verdad en el CSV son unos pocos cientos, así que baja a
cientos de KB. El precio es que si mañana se agrega una cadena nueva en
uno de esos idiomas, sus glifos no van a estar: por eso esto vive en
tools/ y se vuelve a correr cuando cambian las traducciones.
"""
import csv, os, re, subprocess, sys, tempfile, urllib.request

CSS = "https://fonts.googleapis.com/css2?family=%s:wght@600&display=swap"
UA = {"User-Agent": "Mozilla/5.0"}
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(RAIZ, "assets", "fonts")
CSV = os.path.join(RAIZ, "assets", "i18n", "ui.csv")

# Una fuente por sistema de escritura, y qué columnas del CSV la usan.
FUENTES = {
    "NotoSansSC":         ("Noto+Sans+SC",         ["zh_CN"]),
    "NotoSansJP":         ("Noto+Sans+JP",         ["ja"]),
    "NotoSansKR":         ("Noto+Sans+KR",         ["ko"]),
    "NotoSansArabic":     ("Noto+Sans+Arabic",     ["ar", "ur"]),
    "NotoSansDevanagari": ("Noto+Sans+Devanagari", ["hi"]),
    "NotoSansBengali":    ("Noto+Sans+Bengali",    ["bn"]),
}

filas = list(csv.reader(open(CSV, encoding="utf-8")))
cab = filas[0]

os.makedirs(DEST, exist_ok=True)
total = 0
for nombre, (familia, columnas) in FUENTES.items():
    idx = [cab.index(c) for c in columnas]
    usados = set()
    for fila in filas[1:]:
        for i in idx:
            usados.update(fila[i])
    # Dígitos y puntuación básica por las dudas: los números del HUD se
    # dibujan con la fuente base, pero un idioma puede mezclarlos.
    usados.update("0123456789 .,:;!?%()-/…")

    css = urllib.request.urlopen(
        urllib.request.Request(CSS % familia, headers=UA), timeout=60).read().decode()
    url = re.search(r"src: url\((https://[^)]+\.(?:ttf|otf|woff2))\)", css)
    if not url:
        print("  %-20s NO se encontró la URL" % nombre); continue
    crudo = os.path.join(tempfile.gettempdir(), nombre + "_full.ttf")
    if not os.path.exists(crudo):
        with open(crudo, "wb") as f:
            f.write(urllib.request.urlopen(
                urllib.request.Request(url.group(1), headers=UA), timeout=180).read())
    salida = os.path.join(DEST, nombre + ".ttf")
    subprocess.run([sys.executable, "-m", "fontTools.subset", crudo,
                    "--text=" + "".join(sorted(usados)),
                    "--output-file=" + salida,
                    "--layout-features=*", "--drop-tables+=DSIG",
                    "--no-hinting", "--desubroutinize"], check=True,
                   capture_output=True)
    antes = os.path.getsize(crudo) / 1024.0
    despues = os.path.getsize(salida) / 1024.0
    total += despues
    print("  %-20s %5d glifos  %8.0f KB -> %6.1f KB" % (nombre, len(usados), antes, despues))
print("TOTAL en el APK: %.1f KB" % total)
