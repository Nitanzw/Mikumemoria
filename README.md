# ¡Invasión en el Huerto! 🐛

Proyecto Godot 4.x implementado a partir de la guía `invasión_huerto_godot_guia.md`.
El **capítulo 1 es jugable de punta a punta**: menú → nivel con spawner de
insectos, tap para golpear, combos, insecto incógnito, fin de nivel, tienda
y árbol de habilidades.

## Cómo probarlo

1. Abre la carpeta del proyecto con **Godot 4.3+** (`project.godot` en la raíz).
2. Al abrir por primera vez Godot reimportará todos los `.png` (son
   placeholders generados por script, no arte final — ver abajo).
3. Ejecuta la escena principal (F5). Arranca en `scenes/menu/main_menu.tscn`.
4. En escritorio, los clics de mouse se emulan como toques
   (`emulate_touch_from_mouse=true`), así que no hace falta un dispositivo
   táctil para probar.

## Generar música con Suno

`tools/generate_music_suno.py` llama a la [API de Suno](https://docs.sunoapi.org)
para generar la música definitiva del juego (reemplaza los `.wav`
placeholder). Es un script Python de la librería estándar, sin
dependencias que instalar.

```bash
export SUNO_API_KEY="tu_clave"          # https://sunoapi.org/api-key
python3 tools/generate_music_suno.py --list                 # ver las 11 pistas definidas
python3 tools/generate_music_suno.py --track menu_theme      # generar una
python3 tools/generate_music_suno.py --all --skip-existing   # generar todo lo que falte
```

Por cada pista: crea la tarea (`POST /api/v1/generate`), espera con
polling (`GET /api/v1/generate/record-info`) y descarga el `.mp3` a
`assets/sounds/music/<nombre>.mp3`. No hace falta tocar GDScript después:
`AudioManager` ya prioriza `.mp3` sobre el `.wav` placeholder.

Pistas definidas: `menu_theme` y `level_theme_1` (ya usadas por el
código) más `level_theme_2` a `level_theme_10`, una por capítulo de
`LevelManager`. `game_level.gd` reproduce `level_theme_<capítulo actual>`
si existe, y si no, cae en `level_theme_1` — así el juego nunca se queda
sin música mientras se van generando los capítulos restantes.

Notas importantes:
- **Nunca commitees `SUNO_API_KEY`.** Usá variable de entorno o copiá
  `.env.example` a `.env` (ya está en `.gitignore`).
- Suno borra los archivos generados a los **15 días**: por eso el script
  descarga y guarda el `.mp3` en el repo en vez de dejar que el juego
  dependa de la URL remota.
- Cada corrida de `--track`/`--all` gasta créditos de tu cuenta de Suno;
  usá `--skip-existing` para no regenerar lo que ya está bien.
- Los prompts de cada pista (estilo, título, descripción) están en el
  diccionario `TRACKS` al principio del script — se pueden ajustar y
  volver a correr para otra versión de la misma pista.

## Generar sprites con Gemini o con OpenRouter

Ya generados y commiteados los 33 assets visuales (16 insectos, 5 armas,
personaje, 10 fondos de capítulo, ícono) con
`tools/generate_sprites_openrouter.py` — el arte "final" actual del
juego viene de ahí, no de los placeholders geométricos originales.
Quedan dos scripts equivalentes por si querés regenerar algo (mismos
prompts, mismo post-proceso, misma interfaz de línea de comandos):

- `tools/generate_sprites_gemini.py` — llama **directo** a la API de
  Google AI / Gemini, sin intermediario. Usalo si ya tenés cuenta de
  Google AI paga (evita el margen de OpenRouter) *y* tenés facturación
  habilitada en el proyecto de Cloud asociado a tu API key (ver
  advertencia abajo — es un paso aparte de pagar Gemini como app).
- `tools/generate_sprites_openrouter.py` — pasa por OpenRouter. Es el
  que efectivamente se usó para generar el arte actual, con
  `google/gemini-3.1-flash-lite-image` ("Nano Banana 2 Lite" — la
  variante económica, ~$0.034 por sprite, $1.12 en total las 33).

```bash
pip install pillow numpy scipy

# Opción directa (Gemini):
export GEMINI_API_KEY="tu_clave"            # https://aistudio.google.com/apikey
python3 tools/generate_sprites_gemini.py --asset hormiga_obrera   # probar UNO primero
python3 tools/generate_sprites_gemini.py --all          # sin --skip-existing si querés regenerar todo

# Opción por OpenRouter:
export OPENROUTER_API_KEY="tu_clave"        # https://openrouter.ai/keys
python3 tools/generate_sprites_openrouter.py --all
```

⚠️ Ojo con `--skip-existing`: como los 33 archivos ya existen (ya sea el
arte generado o, antes, el placeholder geométrico), esa flag se los
salteará a TODOS. Usala solo para completar assets puntuales que
todavía no tengas; para regenerar algo que ya existe, corré sin ella o
borrá el `.png` primero.

⚠️ `generate_sprites_gemini.py`: confirmado que el endpoint
`/v1beta/interactions` existe y funciona, pero solo acepta
`mime_type: "image/jpeg"` (`image/png` da 400 — no importa, el
post-proceso decodifica cualquier formato). Si te da 429 con
`"free_tier_requests, limit: 0"`, no es por exceso de pedidos —
significa que falta habilitar facturación en el proyecto de Cloud de
esa API key (distinto de pagar Gemini como app), en
console.cloud.google.com/billing.

Cómo se logra el fondo transparente en insectos/armas/personaje (los
fondos de capítulo y el ícono son opacos, no pasan por este paso): se le
pide al modelo el sujeto "aislado sobre fondo magenta plano (#FF00FF)",
pero en la práctica el modelo no siempre respeta ese color exacto (salió
un lila apagado en las pruebas) — así que el post-proceso con
Pillow/numpy/scipy NO asume un color fijo: samplea el color real del
borde de la imagen y hace flood-fill (componentes conexas) desde ahí,
volviendo transparente solo el fondo *conectado al borde* (con blur
suave en el límite de la máscara). Esto evita agujerear el sujeto si por
casualidad tiene un tono parecido en el medio, a costa de a veces dejar
alguna manchita de fondo aislada que no toca el borde (se vio un caso
chico en `zapato_viejo.png`, cosmético, no bloquea nada). Cada sprite se
reencuadra después al tamaño exacto que ya esperan las escenas
(`insect.tscn`/`mystery_bug.tscn` esperan 128×128, `main_game.tscn`
espera el personaje en un lienzo ~200×320, fondos a 540×960).

Notas importantes:
- **Nunca commitees `OPENROUTER_API_KEY`.** Mismo mecanismo que
  `SUNO_API_KEY`: variable de entorno o `.env` (gitignoreado).
- Cada asset generado cuesta créditos de tu cuenta de OpenRouter; el
  script imprime el costo reportado por request y el total al final. Usá
  `--skip-existing` para no regenerar lo que ya está bien.
- Los prompts de cada asset (uno por insecto/arma/fondo/etc., con un
  sufijo de estilo compartido `STYLE_SUFFIX` para mantener consistencia
  visual) están en el diccionario `ASSETS` al principio del script.

## Qué está implementado

- **Autoloads**: `GameManager`, `SaveManager`, `AudioManager`, `EventManager`.
- **Progreso persistente** en `user://invasion_huerto_save.json`: nivel,
  monedas, armas desbloqueadas, árbol de habilidades y progreso de cada
  insecto incógnito (ver nota abajo).
- **Insectos comunes** con datos por tipo (velocidad/vida/puntos/moneda) y
  comportamiento de burla (taunt) cuando fallas un golpe cerca de ellos.
- **Insecto incógnito**: aparece en los niveles 10-19, 20-29, etc. Su
  progreso de revelación se guarda por índice en `GameManager`, así que
  persiste entre los 10 niveles de su ventana (esto corrige un bug del
  documento original: ahí el progreso vivía solo en la instancia de la
  escena y se perdía al cambiar de nivel).
- **Arma / daño / radio** centralizados en `WeaponSystem`, para que la
  tienda y el jugador nunca queden desincronizados.
- **Árbol de habilidades** con 3 ramas (Fuerza, Fortuna, Precisión) y costo
  creciente por nivel.
- **HUD**, pantalla de fin de nivel, tienda y árbol de habilidades
  funcionales con datos reales de `GameManager`.
- **Sistema de combo** con multiplicador de puntos que crece cada 5 golpes
  seguidos y se resetea al fallar.
- `export_presets.cfg` con un preset base de Android (min SDK 24, arm64-v8a,
  Gradle build). Antes de exportar necesitas configurar el Android SDK y
  las plantillas de exportación en **Editor → Configuración del Editor →
  Exportación → Android**, además de una keystore de debug/release.
- **Orientación fija en vertical** — animaciones idle en los insectos
  (balanceo + rebote procedural, sin sprite-sheet) y un tema global con
  fuente más grande para que el HUD y los botones se vean bien en un
  celular real. Ver "Gotcha de exportación Android" abajo sobre la
  orientación: es un bug real de la plantilla de Godot 4.7, no solo
  configuración del proyecto.
- **Historia y diálogo**: guión completo en `scripts/data/story_data.gd`
  (intro, un gancho por capítulo, tutorial, final). `DialogueBox`
  (`scripts/ui/dialogue_box.gd`) es un componente reutilizable con
  retrato de Don Beto, texto tipo máquina de escribir y avance por tap.
  Como no hay sprites de expresión todavía, las "emociones" (feliz,
  triste, enojado, preocupado) se simulan sobre el único sprite
  existente con tinte de color + un salto de énfasis, más un parpadeo
  procedural periódico (`don_beto_portrait.gd`) — reemplazable por arte
  real de expresiones sin tocar la API pública del componente.
- **Intro estilo "cómic"** (`scenes/story/story_intro.tscn`): se muestra
  la primera vez que se abre el juego (con botón "Saltar"), y se puede
  volver a ver desde "Historia" en el menú principal.
- **Tutorial del nivel 1**: Don Beto explica tap/burla/combo/incógnito
  antes de que arranque el primer nivel jugado (una sola vez).
- **Intro de capítulo**: la primera vez que se entra a cada capítulo
  nuevo, un diálogo corto de Don Beto da contexto antes de que arranque
  el timer del nivel.
- **Mapa de mundos** (`scenes/menu/world_map.tscn`): reemplaza el
  "Jugar" directo a nivel. Un nodo circular por capítulo (bloqueado,
  actual con pulso, completado), con scroll animado hasta el capítulo
  actual al entrar. Al completar un nivel que cruza a un capítulo nuevo,
  vuelve al mapa (con el mismo scroll animado) en vez de saltar directo
  al siguiente nivel; dentro del mismo capítulo sigue yendo directo,
  para no interrumpir el ritmo.

## Bugs del documento original que se corrigieron

- `class_name` de los scripts autoload (`GameManager`, `SaveManager`,
  `AudioManager`) coincidía con el nombre del propio autoload — Godot
  rechaza esa combinación al compilar. Se quitó `class_name` de esos tres
  scripts (siguen siendo accesibles como singletons globales).
- `Player.gd` usaba una clase `Circle2D` que no existe en Godot; se
  reemplazó por `scenes/effects/hit_effect.tscn` (un anillo dibujado con
  `_draw()` que se expande y desvanece).
- Un insecto en "burla" (`is_taunting`) se congelaba en vez de moverse más
  rápido, porque `_physics_process` cortaba antes de aplicar `velocity`.
- El progreso de revelación del incógnito no sobrevivía entre niveles (ver
  arriba).
- `on_level_complete()` guardaba `current_level + 1` en el archivo pero
  nunca actualizaba `current_level` en memoria, así que "siguiente nivel"
  no avanzaba realmente sin recargar el guardado.

## ⚠️ Gotcha de exportación Android: orientación bloqueada en horizontal

Probado contra Godot **4.7.1** real (no solo leído en la doc): la opción
`screen/orientation` que existía en `export_presets.cfg` en versiones
anteriores de Godot **ya no existe** — el exportador la ignora en
silencio. Lo único que debería importar es el project setting
`display/window/handheld/orientation` (`window/handheld/orientation` en
`[display]` dentro de `project.godot`, ya seteado en `"portrait"`), pero
en la práctica el build Gradle de Android sigue empaquetando
`android:screenOrientation="landscape"` **hardcodeado** en
`android/build/src/{main,debug,release}/AndroidManifest.xml` — Godot no
reescribe ese valor al exportar (al menos no de forma confiable en esta
versión). Si exportás desde la UI del editor puede que este paso sí
funcione bien (usa un flujo distinto a `--export-release`/`--export-debug`
por CLI); si no, la forma confirmada de arreglarlo:

```bash
# 1. Exportar una vez para que Godot regenere android/build/ con el resto
#    de la configuración (assets, versión, etc.) — el manifest va a
#    quedar en landscape, no importa.
godot --headless --export-release "Android" build/android/app.apk

# 2. Forzar portrait a mano en los 3 manifests del proyecto Gradle:
sed -i 's/android:screenOrientation="landscape"/android:screenOrientation="portrait"/g' \
  android/build/src/debug/AndroidManifest.xml \
  android/build/src/release/AndroidManifest.xml \
  android/build/src/main/AndroidManifest.xml

# 3. Compilar con Gradle directamente (Godot ya no vuelve a tocar el
#    manifest si no volvés a llamar --export-*), pasándole las mismas
#    propiedades que usa internamente:
cd android/build
./gradlew assembleRelease \
  -Pexport_package_name=com.invasionhuerto.game \
  -Pexport_version_code=1 -Pexport_version_name=0.1.0 \
  -Pexport_version_min_sdk=24 -Pexport_version_target_sdk=34 \
  -Pexport_enabled_abis=arm64-v8a \
  -Prelease_keystore_file=/ruta/a/tu.keystore \
  -Prelease_keystore_password=TU_PASS -Prelease_keystore_alias=TU_ALIAS \
  -Pperform_zipalign=true -Pperform_signing=true

# El APK final queda en:
# android/build/build/outputs/apk/standard/release/android_release.apk
```

Si esto se corrige en una versión más nueva de Godot, o si exportar
desde la UI del editor sí respeta la orientación (no lo pude probar acá,
solo por CLI), este workaround dejará de hacer falta — probá primero un
export normal y solo recurrí a este proceso si el APK te sigue saliendo
en horizontal.

## Qué falta

Ya resuelto (no son placeholders): el **arte** (33 sprites, ver más
arriba) y la **música** (11 pistas por Suno, ver más arriba). Queda:

- **SFX**: `assets/sounds/sfx/*.wav` siguen siendo placeholder sintetizados
  por script (`gen_audio.py`, no incluido en el repo) — ondas simples con
  envolvente, sin ninguna API externa. Cubren todo lo que dispara el código
  (`hit_<tipo_de_insecto>`, `taunt`, `mystery_revealed`, `level_complete`,
  `unlock`). Para reemplazar uno por uno real (Kenney.nl, freesound, etc.)
  basta con soltar un `.ogg` con el mismo nombre en esa carpeta — ver
  "Cómo reemplazar un asset" abajo.
- **Cómo reemplazar un asset de audio**: `AudioManager._resolve_path()`
  prueba `.ogg`, después `.mp3`, y por último `.wav` (el orden es a
  propósito: `.ogg` para bancos de sonido definitivos, `.mp3` para lo que
  genera Suno, `.wav` como placeholder de último recurso). Alcanza con
  soltar el archivo con el nombre correcto — no hace falta tocar código.
  La música loopea reconectando la señal `finished` del reproductor en
  vez de depender de metadata de loop del archivo. `AudioManager` tolera
  archivos faltantes (imprime un aviso y continúa).
- **Capítulos 2-10**: `LevelManager` ya tiene su configuración (velocidad,
  cadencia de spawn, fondo), pero solo hay biomas gameplay-probados para
  el capítulo 1; conviene revisar el ritmo de dificultad real al jugar.
- **Rotación de incógnitos revelados**: hoy, al revelarse, un incógnito se
  suma a la colección (`unlocked_insects`) pero no vuelve a aparecer como
  enemigo "normal" en niveles futuros — eso requeriría escenas/sprites
  dedicados por cada uno de los 100 incógnitos, fuera del alcance de este
  primer pase.
- **Íconos de Android**: `icon.png` ya es arte generado (no geométrico),
  pero conviene revisar que se vea bien en las distintas resoluciones
  que pide un adaptive icon de Android antes de publicar.
- **Expresiones reales de Don Beto**: hoy las emociones en el diálogo
  (feliz/triste/enojado/preocupado) son un tinte de color + animación
  sobre el único sprite que existe (ver "Historia y diálogo" arriba).
  Se puede reemplazar por sprites de expresión reales (generados con
  `generate_sprites_gemini.py`/`openrouter.py`, agregando esos assets al
  diccionario `ASSETS`) sin tocar la lógica de `DialogueBox` ni
  `DonBetoPortrait` — solo habría que cargar la textura correspondiente
  en `set_emotion()` en vez de aplicar un tinte.
