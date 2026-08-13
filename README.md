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

Hay **dos scripts equivalentes** para generar los 33 assets visuales del
juego (16 insectos, 5 armas, personaje, 10 fondos de capítulo, ícono) —
mismos prompts, mismo post-proceso de transparencia, misma interfaz de
línea de comandos:

- `tools/generate_sprites_gemini.py` — llama **directo** a la API de
  Google AI / Gemini, sin intermediario. Usalo si ya tenés cuenta de
  Google AI paga (evita el margen de OpenRouter).
- `tools/generate_sprites_openrouter.py` — pasa por OpenRouter, útil si
  no tenés cuenta directa de Google o preferís poder cambiar de modelo
  fácil (Flux, GPT Image, etc. con `--model`).

```bash
pip install pillow numpy

# Opción directa (Gemini):
export GEMINI_API_KEY="tu_clave"            # https://aistudio.google.com/apikey
python3 tools/generate_sprites_gemini.py --list
python3 tools/generate_sprites_gemini.py --asset hormiga_obrera   # probar UNO primero
python3 tools/generate_sprites_gemini.py --all --skip-existing

# Opción por OpenRouter:
export OPENROUTER_API_KEY="tu_clave"        # https://openrouter.ai/keys
python3 tools/generate_sprites_openrouter.py --all --skip-existing
```

⚠️ `generate_sprites_gemini.py` apunta al endpoint `/v1beta/interactions`
que describe la documentación pública, pero no lo pude probar contra una
llamada real antes de escribirlo — por eso corré primero `--asset
hormiga_obrera` (un solo sprite) y revisá que el `.png` haya salido bien
antes de tirar `--all` (que genera los 33 y gasta créditos reales). El
script imprime las claves de la respuesta cruda en el primer request de
cada corrida para poder diagnosticar rápido si el formato no coincide;
si el endpoint no existe (404), cae automáticamente al `generateContent`
clásico y estable.

`generate_sprites_openrouter.py` usa por defecto
**`google/gemini-3.1-flash-image`** ("Nano Banana 2", el mismo modelo que
`generate_sprites_gemini.py` pero vía [API de imágenes de
OpenRouter](https://openrouter.ai/docs/features/multimodal/image-generation)),
gama económica ("flash") — buena relación calidad/costo. Se puede
cambiar con `--model` (Flux, GPT Image, etc.).

Cómo se logra el fondo transparente en insectos/armas/personaje (los
fondos de capítulo y el ícono son opacos, no pasan por este paso): en
vez de confiar en que el modelo soporte transparencia nativa vía API, se
le pide el sujeto "aislado sobre fondo magenta plano (#FF00FF)" y
después un post-proceso local con Pillow/numpy vuelve transparente todo
lo parecido a ese magenta (con degradado suave en el borde). Cada sprite
se reencuadra después al tamaño exacto que ya esperan las escenas
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

## Qué falta (placeholders a reemplazar)

- **Arte**: `assets/sprites/**/*.png` son formas geométricas simples
  generadas por script (`gen_assets.py`, no incluido en el repo), solo para
  poder ver y probar el juego. El arte final se genera con
  `tools/generate_sprites_gemini.py` (o `generate_sprites_openrouter.py`)
  — ver "Generar sprites con Gemini o con OpenRouter" más arriba.
- **SFX**: `assets/sounds/sfx/*.wav` son sonidos placeholder sintetizados
  por script (`gen_audio.py`, no incluido en el repo) — ondas simples con
  envolvente, sin ninguna API externa. Cubren todo lo que dispara el código
  (`hit_<tipo_de_insecto>`, `taunt`, `mystery_revealed`, `level_complete`,
  `unlock`). Para reemplazar uno por uno real (Kenney.nl, freesound, etc.)
  basta con soltar un `.ogg` con el mismo nombre en esa carpeta — ver
  "Cómo reemplazar un asset" abajo.
- **Música**: hoy `assets/sounds/music/menu_theme.wav` y `level_theme_1.wav`
  son los mismos placeholders sintetizados. La música real se genera con
  **Suno** vía `tools/generate_music_suno.py` — ver "Generar música con
  Suno" más arriba.
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
- **Sonidos e íconos de Android** reales (`icon.png` actual es un ícono
  placeholder cuadrado).
