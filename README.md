# El Huerto de Sofía 🐛

Proyecto Godot 4.x implementado a partir de la guía [`invasión_huerto_godot_guia.md`](invasi%C3%B3n_huerto_godot_guia.md).
El **capítulo 1 es jugable de punta a punta**: menú → nivel con spawner de
insectos, tap para golpear, combos, insecto incógnito, fin de nivel, tienda
y árbol de habilidades.

> 🖼️ **[Ver la galería](GALERIA.md)** — capturas del juego andando y las
> 68 imágenes del arte (insectos, armas, fondos, las 6 expresiones de
> Sofía y los 5 ciclos de caminata) más las capturas de los 4 menús,
> todo en una sola página.
>
> 📱 **[Bajar el APK](dist/el_huerto_de_sofia.apk)** — v0.4.0, build
> completo (los 10 capítulos con su música). Ver
> [`dist/README.md`](dist/README.md) para qué trae y cómo instalarlo.
>
> 🎨 **[Pedido de arte](ARTE_PEDIDO.md)** — los 48 prompts con los que se
> generó el arte actual (personaje, insectos, armas, fondos, menú), por
> si querés regenerar alguno. **Ya está todo integrado.**

## Cómo probarlo

1. Abre la carpeta del proyecto con **Godot 4.3+** (`project.godot` en la raíz).
2. Al abrir por primera vez, Godot va a reimportar todas las imágenes
   (tarda un rato la primera vez, después queda cacheado).
3. Ejecuta la escena principal (F5). Arranca en `scenes/story/story_intro.tscn`
   (la intro con la historia, solo la primera vez; después salta directo al
   menú — ver "Historia, diálogo y tutorial" más abajo).
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

## El arte: cómo se generó y cómo regenerarlo

El arte actual (68 imágenes) se generó con **Nano Banana** (Gemini
Image), a mano, a partir de los prompts de
[`ARTE_PEDIDO.md`](ARTE_PEDIDO.md). Ese documento tiene, para cada
asset, el prompt exacto, el tamaño y el nombre de archivo que espera el
motor — si querés rehacer alguno, empezá por ahí.

Dos cosas del proceso que conviene saber si vas a regenerar algo:

**El personaje se mantiene igual entre imágenes gracias a una imagen de
referencia.** Se genera un retrato primero, se itera hasta que cierra, y
después ESE archivo se adjunta en cada prompt siguiente. Sin eso, cada
imagen sale con otra cara. Lo mismo con los insectos: la hormiga
aprobada es la referencia de estilo de los otros 15.

**El fondo transparente se pide en verde, no en magenta.** Probado: con
magenta el modelo no respeta el color exacto y encima les mete tonos
rosados a las patas de los bichos marrones, que después el recorte se
come.

### Ciclos de caminata: se enganchan por nombre de archivo

`insect.gd` no lleva una lista de cuadros por bicho. Busca por convención
`assets/sprites/insects/<tipo>_walk_0.png` .. `_walk_3.png`, y si
encuentra **más de uno** arma el ciclo; si no, usa el sprite fijo
`<tipo>.png`. O sea que agregar la animación de un insecto es generar los
4 PNG y nada más — cero cambios de código:

```bash
export OPENROUTER_API_KEY=...
python3 tools/generate_sprites_openrouter.py --walk-sheet mantis_cronometro_walk
```

El "más de uno" importa: si se armara el `SpriteFrames` con cero cuadros
cargados, el insecto quedaría **invisible** en vez de caer al sprite
fijo. Por eso primero se juntan las texturas y recién ahí se decide.

Los **15 insectos** (5 comunes + 10 incógnitos) tienen ciclo. Los
incógnitos animan tanto cuando aparecen como incógnita (`mystery_bug.gd`)
como cuando reaparecen de tipo avanzado (`insect.gd`): las dos escenas
pasan por el mismo `_apply_sprite_data`.

Dos cosas que costaron y quedaron resueltas en el generador:

**No pidas líneas de grilla.** El prompt pedía "a thin black grid line
dividing it into 4 cells" y el modelo las dibujaba donde quería: en la
hoja de `hormiga_obrera` puso líneas cada 1/4 del ancho, pero cada bicho
ocupaba 2 columnas. Aun cortando en el lugar correcto quedaba una línea
cruzando el medio de cada cuadro. Ahora se piden las 4 poses separadas
por **fondo vacío** y el corte se hace en el medio de ese hueco, que no
deja nada que borrar.

**Sacá el croma por celda, no sobre la hoja.** El recorte borra el fondo
*conectado al borde*; las líneas de la grilla partían el fondo en
regiones que no tocaban ese borde, así que sobrevivían como bloques de
verde vivo adentro del cuadro (le pasó a `mantis_cronometro`, que quedó
con 54% de transparencia en vez de 72%). Recortando cada celda ya
separada, su fondo toca su propio borde y sale entero.

La hoja cruda de cada sheet se guarda en `assets/sprites/_sheets_raw/`
(gitignoreada): partirla y recortarla es post-proceso local, así que se
puede reajustar el corte sin volver a pagar la generación.

### Herramientas de post-proceso

Las imágenes llegan con fondo verde y, en el caso de las caminatas, como
una grilla 2×2. Dos scripts las dejan listas para el motor:

```bash
pip install pillow numpy scipy

# 1. Sacar el fondo croma (una imagen o una carpeta entera)
python3 tools/chroma_key.py assets/sprites/insects/ --in-place

# 2. Partir las grillas de caminata en los 4 cuadros que espera el motor
python3 tools/split_sheet.py assets/sprites/insects/*_walk.png --grid 2x2 --size 128x128
```

`chroma_key.py` no borra "todo lo que se parezca al verde", porque hay
sujetos verdes (el grillo, la malla del matamoscas). Samplea el color
real del borde, hace flood-fill desde ahí para borrar **solo el fondo
conectado al borde**, limpia aparte las manchas de fondo atrapadas
dentro del sujeto con una tolerancia mucho más estricta, y hace despill
para que no quede un halo verde en los contornos.

`split_sheet.py` escala los 4 cuadros con **el mismo factor** (el del
cuadro más grande) en vez de encajar cada uno por separado: si no, el
bicho cambiaría de tamaño entre cuadros y la caminata latiría.

### Peso de las imágenes

Los 10 fondos de capítulo y el del menú son 1080×2340. En PNG pesaban
41MB en total; se guardan como **JPG calidad 92** (7.8MB, diferencia
media 1.4/255 — indistinguible) y se importan con `compress/mode=1`
(lossy) en sus `.import`. Sin ese segundo paso el APK pasa de 38MB a
59MB, porque Godot los empaqueta sin pérdida por defecto.

### Scripts de generación por API (alternativa)

Quedan `tools/generate_sprites_openrouter.py` y
`tools/generate_sprites_gemini.py`, que generan por API en vez de a
mano. Se usaron para la primera versión del arte. Siguen sirviendo si
querés automatizar, pero los prompts que tienen adentro son los del
estilo viejo — los buenos están en `ARTE_PEDIDO.md`.

- **Nunca commitees las API keys.** Variable de entorno o `.env`
  (gitignoreado).
- `generate_sprites_gemini.py`: el endpoint `/v1beta/interactions` solo
  acepta `mime_type: "image/jpeg"` (`image/png` da 400). Si da 429 con
  `"free_tier_requests, limit: 0"`, no es exceso de pedidos: falta
  habilitar facturación en el proyecto de Cloud de esa key.

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
  (balanceo + rebote procedural, encima de la animación de caminata real
  en `hormiga_obrera`, ver abajo) y un tema global con fuente más grande
  para que el HUD y los botones se vean bien en un celular real. Ver
  "Orientación en Android" abajo: la causa real era un error de tipo en
  `project.godot`, no configuración del manifest.
- **Ajuste a pantalla**: `window/stretch/aspect="expand"`. Con `"keep"`
  (lo que había antes) un celular 19.5:9 quedaba con franjas negras
  arriba y abajo, porque el viewport de diseño es 540x960 (9:16). Con
  `expand` el viewport crece en alto hasta la proporción real del
  dispositivo, así que **el fondo y Sofía no pueden vivir en
  coordenadas fijas**: `game_level.gd::_setup_background()` escala el
  fondo en modo "cover" contra `get_viewport_rect()` y reubica a Don
  Sofía contra el borde de abajo real. Si agregás más elementos fijos a
  la escena de juego, acordate de posicionarlos igual.
- **Feedback del golpe**: al tocar se instancia `WeaponStrike`
  (`scenes/effects/weapon_strike.tscn`), que muestra el arma equipada
  bajando, achatándose en el impacto y levantándose — el sprite sale de
  `WeaponSystem.WEAPONS[...].sprite`, así que siempre se ve el arma que
  está equipada de verdad, y su tamaño escala con el radio del arma. Al
  morir un insecto, `SplatEffect`
  (`scenes/effects/splat_effect.tscn`) dibuja una salpicadura con gotas
  (todo con `_draw()`, sin sprites nuevos) del color definido en
  `Insect.SPLAT_COLORS` para ese tipo, y suena el SFX `splat`.
- **Historia y diálogo**: guión completo en `scripts/data/story_data.gd`
  (intro, un gancho por capítulo, tutorial, final). `DialogueBox`
  (`scripts/ui/dialogue_box.gd`) es un componente reutilizable con
  retrato de Sofía, texto tipo máquina de escribir y avance por tap.
  Cada emoción (feliz, triste, enojada, preocupada, sorprendida, neutral) tiene su
  propio sprite real (`assets/sprites/character/sofia_<emocion>.png`,
  generados con Nano Banana, ver ARTE_PEDIDO.md), con salto de
  énfasis y parpadeo procedural periódico encima (`sofia_portrait.gd`).
  Si a alguna emoción le faltara el archivo, cae a un tinte de color sobre
  el sprite neutral en vez de romperse.
- **Insectos animados**: los 5 comunes tienen ciclo de caminata real de 4 frames
  (`assets/sprites/insects/hormiga_obrera_walk_0..3.png`, generado como un
  sprite-sheet 2x2 en una sola llamada a la API para que los frames sean
  consistentes entre sí, después partido en post-proceso). El resto de
  los insectos usa un solo frame estático — mismo nodo `AnimatedSprite2D`
  para todos (`insect.gd._apply_sprite_data`), así agregar más ciclos de
  caminata más adelante es solo generar los frames y sumarlos a
  `walk_frames` en `INSECT_DATA`.
- **Intro estilo "cómic"** (`scenes/story/story_intro.tscn`): se muestra
  la primera vez que se abre el juego (con botón "Saltar"), y se puede
  volver a ver desde "Historia" en el menú principal.
- **Tutorial del nivel 1**: Sofía explica tap/burla/combo/incógnito
  antes de que arranque el primer nivel jugado (una sola vez).
- **Intro de capítulo**: la primera vez que se entra a cada capítulo
  nuevo, un diálogo corto de Sofía da contexto antes de que arranque
  el timer del nivel.
- **Mapa de mundos** (`scenes/menu/world_map.tscn`): reemplaza el
  "Jugar" directo a nivel. Un nodo circular por capítulo (bloqueado,
  actual con pulso, completado), con scroll animado hasta el capítulo
  actual al entrar. Al completar un nivel que cruza a un capítulo nuevo,
  vuelve al mapa (con el mismo scroll animado) en vez de saltar directo
  al siguiente nivel; dentro del mismo capítulo sigue yendo directo,
  para no interrumpir el ritmo.

## Jefes, vidas y selector de niveles

- **Pelea de jefe cada 5 niveles** (`LevelManager.is_boss_level`). Dos
  barras: la del jefe y la de Sofía (`PLAYER_MAX_HP`), y 90 segundos en
  vez de 30. Si se acaba el tiempo con el jefe vivo, se pierde igual.
- **10 arquetipos de jefe** en `scripts/data/boss_data.gd`, que se
  recorren en orden y al completar la vuelta reaparecen escalados
  (`get_boss_config(id, cycle)`). Lo que los distingue no es la vida:
  son las **habilidades** (`scripts/core/boss.gd`).
  - `summon` invoca refuerzos y **mientras haya uno vivo el jefe no
    recibe daño** — hay que limpiar la pantalla primero. Es la mecánica
    de "invocar insectos que impidan pegarle".
  - `shield` aguanta 4 golpes seguidos; `burrow` lo hace invulnerable y
    lo reubica; `dash` embiste a Sofía (con aviso previo para que sea
    esquivable); `spit` tira proyectiles, que se destruyen tocándolos;
    `steal` te roba monedas al pegarte; `split` crea copias que mueren
    de un golpe; `heal` lo cura si lo dejás tranquilo; `haste` lo
    acelera; `enrage` se activa bajo el 30% de vida.
  - Cuando el jefe no puede recibir daño se pone semitransparente y su
    barra se tiñe de azul, para que se entienda que pegarle ahí no sirve.
- **Vidas** (`GameManager`): 3, se gastan solo al perder contra un jefe.
  Regeneran una cada 10 minutos de tiempo **real** — se guarda el
  timestamp Unix y al cargar se calcula cuántas corresponden, así
  también suma el tiempo con el juego cerrado. Se pueden recargar
  pagando monedas desde el menú.
- **Selector de niveles** (`scenes/menu/level_select.tscn`): el mapa de
  mundos ahora entra a una grilla con los 100 niveles del capítulo, con
  su estado y los de jefe marcados. Permite **rejugar** cualquiera ya
  superado. Para que rejugar no borre el avance, el progreso vive en
  `max_level_unlocked`, separado de `current_level`; el mapa se basa en
  `get_max_chapter_unlocked()` y no en `current_chapter`, que retrocede
  al rejugar.
- **14 tipos de insecto** con rangos amplios de vida (1 a 8) y velocidad
  (45 a 320), y variación por spawn (`SPEED_VARIANCE_MIN/MAX`) para que
  dos bichos del mismo tipo no se muevan idénticos. Las variantes
  avanzadas reusan el arte de los incógnitos, que antes solo se veía al
  revelarlos.

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
- **`SaveManager.save_game()` descartaba casi todo lo que se le pasaba.**
  Tenía una lista blanca de 7 campos y copiaba uno por uno; cualquier
  cosa que `GameManager` agregara al diccionario se perdía en silencio,
  sin error. Por eso `story_seen`, `tutorial_seen`,
  `seen_chapter_intros` y `mystery_progress` no sobrevivían a cerrar el
  juego: la intro y el tutorial reaparecían en cada arranque y el
  progreso de revelación de los incógnitos se reseteaba. Ahora el
  esquema lo define `GameManager._build_save_dict()` y SaveManager
  guarda el diccionario completo, así sumar un campo no requiere tocar
  las dos puntas.

## ⚠️ Orientación en Android: `handheld/orientation` es un ENTERO, no un string

**Esta es la causa raíz de todo el problema de orientación** — costó
varios intentos fallidos encontrarla, así que vale la pena dejarla
escrita con detalle.

En **Godot 3**, `display/window/handheld/orientation` era un **string**
(`"portrait"` / `"landscape"`). En **Godot 4 es un entero** (un enum de
`DisplayServer.ScreenOrientation`). Las settings vecinas
(`window/stretch/mode`, `window/stretch/aspect`) **sí** siguen siendo
strings, así que la mezcla es muy fácil de hacer sin darse cuenta — y
Godot **no** avisa del error: acepta el string, lo convierte a entero,
y como no es numérico da **0**, que en ese enum es **Landscape**.

```ini
# ❌ MAL (sintaxis de Godot 3 — Godot 4 lo lee como 0 = Landscape)
window/handheld/orientation="portrait"

# ✅ BIEN (Godot 4)
window/handheld/orientation=1
```

Valores del enum: `0`=Landscape, `1`=Portrait, `2`=Reverse Landscape,
`3`=Reverse Portrait, `4`=Sensor Landscape, `5`=Sensor Portrait,
`6`=Sensor.

Lo traicionero es que el síntoma **no** parece un problema de tipos:

- Godot escribe `android:screenOrientation="landscape"` en el manifest
  generado (`android/build/src/release/AndroidManifest.xml`), porque
  está leyendo 0. Da la impresión de que "Godot hardcodea landscape",
  que fue mi primera conclusión equivocada.
- Y aunque parchees el manifest a mano a `portrait`, **el juego igual
  arranca en horizontal**: Godot llama a `setRequestedOrientation()` en
  tiempo de ejecución al iniciar la activity, con ese mismo 0, y esa
  llamada **pisa lo que diga el manifest**. Por eso parchear el manifest
  no arregla nada — es el lugar equivocado.
- El resultado visual confunde más todavía: la ventana queda en
  landscape y Godot, con `stretch/aspect="keep"`, encaja el contenido
  vertical (540x960) centrado ahí adentro. Se ve *derecho pero angosto,
  con franjas negras a los costados*, que parece "letterboxing de
  Android en pantallas grandes" y no lo es.

Para verificar el tipo (no el valor — el **tipo**) sin adivinar:

```bash
cat > /tmp/check.gd <<'EOF'
extends SceneTree
func _init():
	for p in ProjectSettings.get_property_list():
		if p.name == "display/window/handheld/orientation":
			var v = ProjectSettings.get_setting(p.name)
			print("declarado=", p.type, " real=", typeof(v), " valor=", v)
	quit()
EOF
godot --headless --path . --script /tmp/check.gd
# declarado=2 real=2  -> OK (2 = int en ambos)
# declarado=2 real=4  -> ROTO (4 = String), lo lee como 0 = Landscape
```

Y para confirmar el resultado en el APK ya compilado, mirando el
manifest **binario real** que quedó adentro (no un intermedio de Gradle):

```bash
aapt2 dump xmltree --file AndroidManifest.xml ruta/al.apk | grep -i screenOrientation
# screenOrientation=1  -> PORTRAIT  (constantes de Android, no las de Godot)
# screenOrientation=0  -> LANDSCAPE
```

### Sobre el manifest: dos cosas menores, ya no críticas

Con la setting bien puesta, Godot escribe `portrait` solo en
`release/AndroidManifest.xml` al exportar. Quedan dos detalles que no
causan el bug pero conviene dejar coherentes si compilás con Gradle a
mano (`main/AndroidManifest.xml` es una plantilla estática que Godot no
reescribe, y el flavor `release` pisa `resizeableActivity` a `true` vía
`tools:replace`):

```bash
sed -i \
  -e 's/android:screenOrientation="landscape"/android:screenOrientation="portrait"/g' \
  -e 's/android:resizeableActivity="true"/android:resizeableActivity="false"/g' \
  android/build/src/main/AndroidManifest.xml \
  android/build/src/release/AndroidManifest.xml
```

### Compilar con Gradle directamente

Solo hace falta si vas a parchear el manifest a mano como arriba (con la
setting arreglada, un `--export-release` normal ya alcanza). Godot no
vuelve a tocar el manifest mientras no llames de nuevo a `--export-*`:

```bash
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

(Nota aparte: la opción `screen/orientation` que existía en
`export_presets.cfg` en versiones viejas de Godot ya no existe en 4.7 —
el exportador la ignora en silencio. La orientación se controla
únicamente desde el project setting de arriba.)

### Dos trampas del build de Android que cuestan MB y tiempo

**1. El APK sale 3x más grande de lo que debería.** Con `minSdk > 29` el
Android Gradle Plugin empaqueta los `.so` **sin comprimir**, para poder
mapear las páginas directo desde el APK. `libgodot_android.so` pasa a
ocupar 67.8MB en vez de los 22.9MB que ocupa deflateado, y el APK se va
a 134MB (arriba del límite de 100MB por archivo de GitHub). La solución
es una línea en `export_presets.cfg`:

```ini
gradle_build/compress_native_libraries=true
```

No pierdas tiempo buscando símbolos de depuración: los `.so` de la
plantilla oficial ya vienen strippeados, `llvm-strip --strip-unneeded`
no les saca ni un byte. Es puramente cómo se guardan en el zip.

**2. `godot --import` rompe el build de Android.** El editor escanea
todo el proyecto, entra a `android/build/res/` y le deja un `.import` al
lado de cada `.webp` (los íconos y el splash). Después `aapt2` corta el
build con:

```
res/mipmap-xxhdpi-v4/icon.webp.import: Error: The file name must end with .xml or .png
```

Por eso hay un **`android/.gdignore`** commiteado: le dice al editor que
no toque el proyecto de gradle. Si ya te pasó:

```bash
find android -name "*.import" -delete
```

**3. Todo lo que esté dentro del proyecto viaja al APK.** Godot importa
cualquier carpeta de `res://`, use el juego esos archivos o no. Estaban
entrando las hojas crudas de los sprite sheets y las capturas del README:
11.4MB de peso muerto, más caché huérfana de assets ya borrados. Por eso
hay un `.gdignore` en `docs/` y en `assets/sprites/_sheets_raw/`. Si
sospechás que hay basura empaquetada:

```bash
rm -rf .godot/imported          # se regenera sola en el próximo --import
```

### Firmar sin commitear la keystore

El exportador lee la keystore de release de variables de entorno, así no
hay que ponerla en `export_presets.cfg`:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/ruta/a/tu.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=tu_alias
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=tu_password
godot --headless --export-release "Android" dist/el_huerto_de_sofia.apk
```

## Qué falta

Ya resuelto (no son placeholders): el **arte** (38 sprites + el ciclo de
caminata de 4 frames de `hormiga_obrera`, ver más arriba), la **música**
(11 pistas por Suno, ver más arriba) y los **SFX** (ver abajo). Queda:

- **SFX**: `assets/sounds/sfx/*.ogg` son sonidos reales CC0 de
  [Kenney.nl](https://kenney.nl) (packs "Impact Sounds", "Interface
  Sounds" y "Music Jingles" — dominio público, no requieren atribución,
  descargados directo del sitio sin API key). Cubren todo lo que dispara
  el código (`hit_<tipo_de_insecto>`, `splat`, `taunt`,
  `mystery_revealed`, `level_complete`, `unlock`). Los `.wav` sintetizados anteriores se
  borraron. Para reemplazar alguno por otro distinto basta con soltar un
  `.ogg`/`.mp3`/`.wav` con el mismo nombre en esa carpeta — ver "Cómo
  reemplazar un asset" abajo.
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
- **Más ciclos de caminata**: hoy solo `hormiga_obrera` tiene animación de
  caminata real (4 frames); el resto de los insectos usa un solo frame
  estático + el balanceo procedural. Para sumarle un ciclo a otro tipo:
  `python3 tools/generate_sprites_openrouter.py --walk-sheet <nombre>`
  (definir el spec en `WALK_SHEETS` primero) y agregar la lista
  `walk_frames` a esa entrada en `Insect.INSECT_DATA`.
