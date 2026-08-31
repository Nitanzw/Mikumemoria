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

## Música: por qué sonaba a arcade y siempre igual

Dos problemas distintos que se sentían como uno.

**Sonaba a 8-bit** porque los prompts lo pedían literalmente: el de
`level_theme_1` decía *"estilo 8-bit/chiptune, tempo rapido"*. Contra el
arte pintado del juego quedaba fuera de lugar, y a tempo rápido cansaba
en pocos niveles. El set entero se regeneró **acústico** — guitarra,
ukelele, marimba, mandolina, cajón — con dinámica pareja y pensado para
escucharse largo rato.

**Sonaba siempre la misma** porque la pista se elegía **por capítulo**, y
un capítulo son 100 niveles: te comías `level_theme_1` cien veces
mientras las otras nueve no sonaban nunca. Ahora rota **por nivel**, con
un paso primo respecto de la cantidad de pistas para que la rotación no
quede emparejada con los niveles de jefe (cada 5). Son 14 pistas de nivel
más el menú, y las peleas de jefe tienen la suya (`boss_theme`).

**Sobre el peso**: 16 pistas en el estéreo de 200kbps que devuelve Suno
son 65MB y el APK no entra en GitHub. Se reencodean a **mono 96kbps** —
es música de fondo en un parlante de celular, el estéreo no aporta — y
quedan en 33MB, menos que las 11 pistas de antes:

```bash
ffmpeg -i pista.mp3 -ac 1 -b:a 96k salida.mp3
```

Ojo con las pistas cortas: Suno a veces devuelve una de 48s en vez de
~190s. Vale la pena chequear duraciones y regenerar la que salga corta.

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

Los ciclos van en el **mismo estilo** que el arte fijo (`POLISHED_STYLE`,
el de Sofía, los fondos y la UI). Antes usaban `STYLE_SUFFIX`, que el
propio código marca como "el estilo viejo, plano": el bicho cambiaba de
dibujo entre estar quieto y caminar.

Tres cosas que costaron y quedaron resueltas en el generador:

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

**Normalizá la escala en post-proceso, no a fuerza de prompts.** El
modelo dibuja cada pose del tamaño que se le ocurre: a `mosca_pesada` le
salían cuadros con 32% de diferencia de alto y el bicho latía de tamaño
al caminar. Reforzar el prompt con "IDENTICAL SIZE" y regenerar no
alcanzó (probado dos veces, volvió a salir disparejo). `_normalize_scale`
mide la caja opaca de cada cuadro y la lleva a la mediana de **alto** —
el alto y no el ancho, porque lo que cambia legítimamente entre poses es
a lo ancho: alas que se abren, lombriz que se estira. Quedó en 0-2% de
variación. Ojo con el lienzo: tiene que entrar el cuadro más ancho de la
serie y con margen **proporcional**, si no un sujeto más ancho que alto
sale recortado (le pasó a la lombriz estirada).

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

## Dificultad: por qué el juego se volvía más fácil al avanzar

Tres cosas se arreglaron juntas, porque el problema era el mismo: **el
jugador se hacía más fuerte y el juego no**.

**1. No había escalado dentro del capítulo.** `enemy_speed_mult` venía
solo de la config del capítulo, y un capítulo son **100 niveles**. Ibas
comprando armas y subiendo el árbol mientras los bichos del nivel 99
eran idénticos a los del 1. Ahora la dificultad sube por **escalones de
10 niveles** (`LevelManager.get_difficulty_tier`): +8% de velocidad, los
bichos salen un 6% más seguido y suman +1 de vida cada 3 escalones. En
cada escalón nuevo Sofía lo dice en voz alta, una sola vez por escalón
(rejugar el nivel 10 no repite el cartel).

**2. La vida de los jefes era fija.** Entre el arma, la rama Fuerza y los
guantes, el daño del jugador llega a **7x** el inicial; la vida del jefe
solo iba de 20 a 68. Con equipo completo la Reina Primordial caía en 10
golpes. Ahora la vida del jefe escala con el escalón del nivel
(`BossData.TIER_HEALTH_STEP`), y las peleas quedan en 20-44 golpes sobre
los 90 segundos — un golpe cada 2 a 4.5 segundos, contando las ventanas
en que el jefe es invulnerable.

**3. Los jefes se peleaban todos igual.** Ver abajo.

## Jefes: movimiento y patrones

Antes **todos** los jefes hacían lo mismo: patrullar de izquierda a
derecha a la altura fija `TOP_MARGIN`, y sortear una habilidad al azar
cada 3-5 segundos. Cambiaba el sprite y la vida, no la pelea.

**Movimiento**: cada jefe tiene el suyo (`movement` en `BossData`) —
`zigzag`, `swoop` (baja en picada y vuelve), `strafe` (ráfagas laterales
con pausas), `blink` (reaparece lejos), `orbit`, `pendulum` (frena en las
puntas, y ahí es cuando le pegás), `erratic`, `advance` (baja de a poco
hacia Sofía a medida que pierde vida) y el `patrol` de siempre.

**Patrón de ataque**: la lista `pattern` se recorre **en orden y en
bucle**, no al azar. Eso es lo que hace que la pelea se pueda aprender:
sabés que después de la invocación viene la embestida. Si el ataque que
toca no se puede usar ahora (ya hay minions, ya hay escudo), pasa al
siguiente en vez de perder el turno.

**Fases**: al 60% y al 30% de vida el jefe cambia de fase. En cada una
ataca más seguido (`PHASE_COOLDOWNS`: de 2.2-3.2s a 0.9-1.6s), se acelera
un 18%, invoca un refuerzo más y **desbloquea una habilidad nueva**
(`phase_unlocks`). Lo anuncia, así se entiende que se puso peor.

**Los minions** iban a 1.1x de velocidad y llegaban tardísimo: daba
tiempo de limpiarlos sin despeinarse. Ahora van a 2x, y más en las
vueltas siguientes al roster.

## Vidas de la pelea: barra abajo y números grandes

Las dos vidas van en un panel abajo de la pantalla, con el número exacto
debajo de cada barra. Fueron pasando por tres formas: horizontales arriba
y abajo, verticales a los costados, y ahora esta. La diferencia real no
es estética — **con el número a la vista la vida puede crecer**, que es
lo que habilita mejorarla en la tienda y que los jefes peguen más fuerte
con la dificultad.

Sofía arranca con **1000** y el jefe con 2000-6800 según cuál sea. Los
números de `BossData` siguen siendo chicos y legibles para tunear (20,
26, 30...): `Boss.HP_SCALE` los multiplica al cargar, y el daño que entra
se multiplica por lo mismo, así los **golpes-para-matar quedaron
exactamente iguales** a los que ya estaban balanceados.

**El daño del jefe ahora escala.** Antes era fijo: un jefe del nivel 95
pegaba igual que el del nivel 5, así que con el botiquín comprado las
peleas tardías dejaban de doler. Ahora sale de `BossData.BASE_DAMAGE`
(200 = cinco golpes desde vida llena, lo mismo que aguantaba con los 5
corazones viejos) y sube con el escalón de dificultad y con la vuelta al
roster. Los refuerzos y los escupitajos pegan una fracción de eso, así
todo escala junto.

Dos bugs de orden que esto destapó:

- `_setup_background()` decide a qué altura va Sofía según
  `is_boss_level`, pero esa variable se asignaba **después** de llamarla.
  Con el panel nuevo abajo, eso la dejaba tapada en todas las peleas.
- Las señales del jefe se conectaban **después** de `boss.setup()`, y
  `setup()` es justo quien emite `health_changed` con la vida inicial: ese
  primer aviso se perdía. Con la barra vieja no se notaba (arrancaba
  llena por defecto), pero con el número a la vista el jefe decía
  **"0 / 0"** hasta que le pegabas por primera vez.

Nada entra debajo del panel de abajo tampoco: los insectos tienen pared
dura arriba **y abajo** (el tirón del rumbo es blando y no alcanzaba), y
el jefe ya estaba cubierto por `ARENA_BOTTOM_MARGIN`.

## El HUD de partida

Era un panel translúcido plano de **215px** — casi un cuarto de la
pantalla de un celular, y con el aspecto de una caja de debug. Ahora es
un marco de **132px** armado con cuatro piezas generadas:

| Pieza | Cómo se usa |
|---|---|
| `hud_bar` | NinePatchRect estirado a lo ancho |
| `hud_medallion` | Círculo central, con el reloj adentro |
| `hud_badge` | Las dos placas de las puntas |
| `hud_ribbon` | Banda con el nombre del nivel |

Las cuatro están **recortadas a su bbox de alfa** antes de usarse: sin
eso el 9-slice estira el margen transparente y el marco queda corrido
respecto del texto (el mismo problema que ya había aparecido con
`button_wood` y `panel_card`).

Las etiquetas dejaron de decir "Puntos:" y "🪙": el emblema de cada placa
(estrella y moneda) ya dice qué es cada número, y en 540px de ancho esas
palabras eran las que obligaban a agrandar todo.

El combo, el nombre del jefe y los avisos van **debajo** de la barra, en
`UnderBar`, para que el marco quede siempre igual y no salte de altura.

**Nada entra debajo de la barra.** El tirón del rumbo hacia el centro no
alcanzaba: los bichos igual se metían, y tapearlos ahí abajo es a ciegas.
Ahora `Insect.PLAY_TOP_INSET` es una **pared dura** — se los baja y se
les invierte el rumbo si algo los empujó arriba — y el borde superior
quedó fuera de los puntos de aparición.

Los **jefes quedaban directamente atrapados**: su techo era
`TOP_MARGIN * 0.45`, o sea 99px, **arriba** de la barra de 132px. Los que
suben (swoop, zigzag, blink) se metían debajo del marco y no se los podía
ni ver ni golpear. Ahora `boss.gd` lee la misma constante que los
insectos, así hay un solo número que define dónde empieza la zona
jugable.

## La historia no interrumpe: se cuenta mientras jugás

Al abrir el juego había **siete líneas de intro más cinco de tutorial**:
doce taps antes de ver un insecto. Nadie quiere leer eso para empezar.

Ahora la apertura son **dos líneas** ("me están saqueando el huerto,
ayudame") y arranca. Todo lo que se sacó no se perdió: está en
`STORY_BEATS`, repartido por nivel (3, 6, 12, 18, 25, 32, 45, 60), de a
una o dos líneas por vez.

## Mini tutoriales por hito, no de golpe al principio

El tutorial viejo soltaba las cinco reglas juntas antes del primer nivel
y después no explicaba nada más. Las mecánicas que aparecen mucho más
tarde —objetos pasivos, poderes activos— no las explicaba nadie: había
que adivinar que existían.

Ahora cada consejo sale **cuando hace falta**
(`GameManager.get_pending_tutorial`), una sola vez:

| Tutorial | Cuándo aparece |
|---|---|
| `jefe` | Al entrar al primer nivel de jefe |
| `poderes` | Apenas comprás tu primer poder activo |
| `objetos` | Cuando te alcanza para el primer objeto y no tenés ninguno |
| `tienda` | Cuando te alcanza para la primera arma |
| `vidas` | La primera vez que perdés una |
| `combo` | La primera vez que encadenás varios golpes |

Se devuelve **el primero que aplique**, así nunca se encadenan dos
tutoriales en el mismo nivel.

## Los insectos se quedaban pegados a los bordes

Un tester lo reportó y era un bug real: los bichos nacen fuera de la
pantalla apuntando al centro, pero a los **0.6-1.4 segundos**
`randomize_direction()` elegía un rumbo **totalmente al azar sin mirar
dónde estaban**. Muchos se daban vuelta antes de llegar a entrar y se
iban por donde vinieron; los que quedaban rondaban el borde, donde casi
no se ven y son un garrón de tapear.

Tres arreglos en `insect.gd`:

- El rumbo nuevo se mezcla con un vector **hacia el centro**, pesado por
  lo cerca del borde que esté (`EDGE_PULL_CURVE`): en el medio se mueve
  libre, contra el borde se da vuelta.
- **No cambia de rumbo hasta haber entrado** a la pantalla.
- La "zona jugable" excluye la franja del HUD arriba y la de Sofía abajo,
  así no se esconden detrás del panel translúcido.

Y desde el nivel 1 hay más bichos: `MAX_INSECTS_ON_SCREEN` de 9 a 14, el
`spawn_rate` del capítulo 1 de 2.0s a 1.1s, y **4 insectos ya presentes**
al arrancar para no empezar mirando un huerto vacío.

## Los ataques del jefe se pueden anular

Antes, una vez que el jefe empezaba un ataque salía sí o sí: lo único que
quedaba era esquivar. Ahora **embestida, invocación y escupitajo tienen
una ventana** (`_telegraph`) en la que pegarle al jefe **cancela el
ataque** y lo deja aturdido un rato. Eso es lo que hace que valga la pena
mirar lo que hace el jefe en vez de tapear al vacío.

El chequeo va **antes** que el escudo y los minions a propósito: si fuera
después, un jefe escudado nunca podría interrumpirse, que es justo cuando
más se necesita.

Además atacan bastante más seguido: `PHASE_COOLDOWNS` pasó de 2.2-3.2s a
1.3-2.0s en la primera fase, y de 0.9-1.6s a 0.5-0.9s en la última. Con
los números viejos el jefe se pasaba la pelea paseando.

## La tienda tiene dos vistas

Con 18 artículos, la lista con nombre y descripción obligaba a scrollear
muchísimo. Ahora hay un botón arriba que alterna:

- **Cuadrícula** (por defecto): grilla de íconos tipo market, con el
  precio o el nivel comprado abajo. Tocando uno se abre su ficha con la
  descripción y el botón de comprar.
- **Lista**: la vista detallada de siempre.

La ficha reusa la misma tarjeta que la vista de lista, para no tener dos
formas distintas de mostrar lo mismo. La vista elegida se guarda.

Y desde el resumen de un nivel se puede **ir derecho a la tienda**: antes
había que volver al menú, entrar a la tienda y rehacer todo el camino
hasta el nivel. El botón "Volver" de la tienda sabe de dónde viniste.

## Progresión para 1000 niveles, no para 35

El juego tiene `MAX_LEVEL = 1000`, pero se compraba todo antes del nivel
40 y después no quedaba nada en qué gastar durante 960 niveles. Ahora hay
**180 compras** repartidas a lo largo de todo el juego: un hito cada 25 o
30 niveles.

**Las armas tienen 10 niveles y forman una cadena.** No se puede comprar
la siguiente hasta tener la anterior al nivel 10. El daño es una escalera
pareja de 50 escalones:

| Arma | Daño nivel 1 → 10 | Subirla entera |
|---|---|---|
| Zapato Viejo | 1 → 19 | 11.550 |
| Chancla de Goma | 23 → 41 | 30.550 |
| Matamoscas Metálico | 45 → 63 | 49.550 |
| Sartén de Hierro | 67 → 85 | 68.550 |
| Pala Electrificada | 89 → 107 | 87.550 |

El costo del escalón es lineal (`300 + 190 × escalón`) a propósito: el
ingreso por nivel también crece lineal, así el ritmo de compra queda
parejo en vez de acelerarse al final.

**Los objetos también tienen 10 niveles y van en cadena**, pero en **dos
cadenas separadas** — pasivos por un lado y poderes por otro. Si fueran
una sola, el lanzallamas quedaría detrás de los nueve pasivos y no se
vería nunca.

- Pasivos: guantes → botiquín → lupa → frasco → repelente → reloj de
  arena → trébol → delantal → botas (249.916 monedas, 90 compras)
- Poderes: reloj de bolsillo → campo → tormenta → lanzallamas (192.005
  monedas, 40 compras)

### Cómo se eligieron los números

Simulando la partida completa: el ingreso de 1000 niveles da ~690.000
monedas, y el costo total de las 180 compras es 689.671. Con un jugador
que compra apenas puede, la progresión queda así:

| Hito | Nivel |
|---|---|
| Zapato al máximo | 105 |
| Chancla | 124 |
| Guantes al máximo | 167 |
| Matamoscas | 343 |
| Campo expansivo | 407 |
| Sartén | 586 |
| Pala | 789 |
| Pala al máximo | 887 |
| Lanzallamas | 899 |
| Lanzallamas al máximo | **970** |

Termina en el 970 de 1000, con ~36.000 monedas de sobra — que es justo el
colchón para los usos de poderes (se pagan cada vez) y las recargas de
vidas.

### El árbol de habilidades rompía el tuning

`get_damage_multiplier` devolvía `1.0 + tier × 0.2`, o sea **×2 al
máximo**. Cuando las armas hacían 1 o 2 de daño eso era un empujón chico.
Con la escalera nueva, ese mismo ×2 regalaba **+107 de daño por 4.800
monedas** — el árbol entero cuesta menos que un escalón de arma tardío — y
dejaba sin sentido las 50 mejoras.

Ahora la rama Fuerza suma **daño plano** (+3 por escalón, +15 al máximo),
igual que los guantes. Nada multiplica al arma: el arma pone la base y
todo lo demás suma encima.

### Efectos reescalados

Los objetos tenían 2 o 3 niveles; con 10, varios efectos se pasaban de
rosca. `+5s de tiempo por nivel` eran +50 segundos en un nivel de 30;
`+10% de crítico` era 100% de crítico. Quedaron: crítico 5%/nivel (50% al
máximo), monedas 6% (60%), tiempo 1,5s (15s), radio 5 (50), lentitud de
refuerzos 5% (50%), daño de guantes 2 (20), vida del botiquín 250 (2.500).

El delantal usaba una tabla `[0, 4, 3]` indexada por nivel, que con 10
niveles no cierra. Ahora es fórmula: bloquea 1 golpe de cada 6 en el nivel
1 y 1 de cada 2 en el 10 — nunca 1 de cada 1, porque invulnerable no.

### Guardados viejos

`unlocked_weapons` era una lista sin niveles. `_load_weapon_levels()` la
convierte dándole nivel 1 a cada arma que ya estaba comprada, en vez de
perder el progreso.

## Las mejoras ahora hacen falta de verdad

El rebalance de precios anterior estaba incompleto y el tester tenía razón
todavía. Yo había mirado sólo la recompensa de fin de nivel, pero
`Insect.die()` también llama a `add_coins(coin_reward)` **por cada bicho
muerto**, y ésa era la parte grande: con 31 muertes por nivel a 10 monedas
cada una, el fin de nivel (~86) era el 20% del ingreso. Simulando la
progresión con los números que había: la Pala se compraba en el nivel 14.

Eran tres problemas encadenados, no uno:

**1. La vida de los insectos casi no subía.** Era `+1 cada 3 escalones`, o
sea +1 cada 30 niveles. Una hormiga tenía 1 de vida hasta el nivel 29:
un toque, siempre. Ahora es `+2 por escalón` (un escalón cada 10 niveles):

| Nivel | Hormiga | Coraza Antigua |
|---|---|---|
| 1 | 1 | 8 |
| 10 | 3 | 10 |
| 20 | 5 | 12 |
| 50 | 11 | 18 |
| 100 | 21 | 28 |

**2. Las armas no servían para nada.** Hacían `1, 1, 1, 2, 2` de daño. El
Matamoscas de 900 monedas pegaba igual que el Zapato gratis; lo único que
cambiaba era el radio. Ahora la escalera es `1, 2, 3, 5, 8`, y la tienda
ya mostraba "Daño N · Radio N", así que la diferencia se ve antes de
comprar.

**3. Sobraban monedas.** Las recompensas por bicho bajaron a ~1/5 (la
hormiga de 10 a 2, el escarabajo de 30 a 6, la coraza de 70 a 14).

El resultado, simulado sobre las constantes reales:

| | Antes | Ahora |
|---|---|---|
| Ingreso por nivel (L1 / L20 / L100) | 396 / 728 / 543 | 148 / 188 / 258 |
| Chancla / Matamoscas / Sartén / Pala | L1 / L4 / L8 / L14 | L3 / L9 / L19 / L35 |
| Golpes por bicho **comprando** | 1 siempre | 1 hasta el 10, 2 desde el 20, 3 en el 100 |
| Golpes por bicho **sin comprar** | 1 siempre | 6 en el nivel 20, 12 en el 50 |

Esa última fila es el mecanismo: si comprás, el juego se mantiene ágil; si
no, la misma hormiga te lleva 6 toques y matás 7 bichos por nivel en vez
de 22. La presión no viene de un cartel, viene de que no llegás.

### Los jefes había que compensarlos

Un jefe come `daño × HP_SCALE`, así que cuadruplicar el daño de las armas
le cuarteaba la pelea: la Reina Primordial pasaba de 65 golpes a 16 y se
derretía. Por eso `BossData.WEAPON_REBALANCE = 2.6` multiplica la vida de
todos los jefes. Golpes para matar, con el arma que te corresponde:

| Nivel | Jefe | Golpes |
|---|---|---|
| 5 | Hormiga Ladrona de Diamantes | 26 |
| 20 | Escarabajo Radiactivo | 43 |
| 50 | Reina Primordial | 42 |
| 100 | Reina Primordial | 62 |

## Rebalance de economía: el dinero sobraba

Un tester llegó al nivel 7 con plata suficiente para el arma más cara del
juego. Revisando de dónde salía, el problema no eran los precios: era el
bonus de combo.

La recompensa de nivel era `50 + nivel*2 + combo_max*5`. Cuando subí la
cantidad de insectos en pantalla (de 9 a 14) y aceleré el spawn (2.0s a
1.1s), las rachas se volvieron mucho más largas sin querer, y ese `*5` sin
tope pasó a ser la mayor parte del ingreso. Es decir: el que rompió la
economía fui yo, en otro cambio.

Se ajustaron las dos puntas:

| | Antes | Ahora |
|---|---|---|
| Base por nivel | 50 | 25 |
| Bonus por nivel | `nivel * 2` | `nivel` |
| Bonus por combo | `combo * 5`, sin tope | `combo * 2`, tope 60 |
| Chancla / Matamoscas / Sartén / Pala | 200 / 500 / 900 / 1500 | 350 / 900 / 1800 / 3200 |
| Objetos pasivos | — | ×1.5 sobre el precio base |

El tope de combo (`MAX_COMBO_COINS`) es la parte importante: premia
encadenar golpes, pero deja de escalar solo porque haya más bichos en
pantalla.

Simulando la progresión con los números viejos (combo máximo creciendo con
el nivel) sale exactamente lo que reportó el tester: la **Sartén al nivel
7** y la Pala al 11. Con los nuevos:

| Arma | Antes | Ahora |
|---|---|---|
| Chancla | nivel 2 | nivel 6 |
| Matamoscas | nivel 4 | nivel 13 |
| Sartén | nivel 7 | nivel 22 |
| Pala | nivel 11 | nivel 35 |
| Lanzallamas (poder más caro) | — | nivel 47 |

El ingreso por nivel terminado queda en ~52 monedas en el nivel 1, 70 en el
7, 105 en el 20 y 185 en el 100 (antes: 117, 159, 250 y 810).

## El resumen de nivel dejó de parecer un placeholder

Era un panel gris con tres líneas de texto. Ahora usa el mismo lenguaje de
madera y oro que el resto del juego:

- Cartel dorado arriba (`res_banner`) con **"¡COMBO PERFECTO!"** y la
  racha en grande. **Solo aparece con combo 5 o más**: un "x2" en un
  cartel enorme queda ridículo. Cuando no está, todo el bloque de abajo
  sube 100px solo, así no queda un agujero.
- Moño verde (`hud_ribbon`) montado **sobre el borde de la placa**, con el
  título en mayúscula ("¡PERFECCIÓN EN EL HUERTO!"), que cambia según cómo
  te fue. Antes flotaba suelto arriba y el panel se leía como tres piezas
  sueltas en vez de un objeto.
- Placa de madera (`res_plaque`) con cuatro tiras (`res_row`): **medalla
  del nivel** (Huerto Perfecto / Buena Mano / Jardinero, según la racha),
  puntos, racha y recompensa, cada una con su ícono. Los números van con
  separador de miles (`1.725`, no `1725`).
- Tres botones: Menú y Tienda en madera, y **Seguir en verde** — es la
  acción que uno busca con el pulgar sin leer. El verde sale de tintar la
  misma textura de madera, no de un asset nuevo.

El velo de fondo bajó de 0.72 a 0.45 de opacidad: el huerto se sigue
viendo detrás, que es lo que hace que la pantalla se sienta parte del
juego y no un cartel pegado encima.

Las filas y la nota van dentro de un **rebaje oscuro** (un `StyleBoxFlat`
redondeado sobre la madera). Sin él las tiras flotaban sobre una tabla
plana y el centro del panel se veía vacío.

**Entra animado.** Antes aparecía de golpe. Ahora el panel entra con un
rebote corto (`TRANS_BACK`), el cartel de racha hace su propio pop, las
filas aparecen escalonadas de a una, y el puntaje y las monedas **suben
desde cero** en medio segundo, así el número del nivel se siente ganado
en vez de aparecer ya escrito. Todo dura menos de un segundo: no te hace
esperar para tocar "Seguir".

Un detalle de implementación que cuesta encontrar: los pivotes de escala
se calculan **después de esperar un cuadro**. Los nodos viven en un
`VBoxContainer` y hasta que el contenedor no acomoda, `size` vale cero,
así que las tiras escalarían desde la esquina en vez del centro. Por eso
la pantalla se hace visible con el velo en alpha 0 y recién al cuadro
siguiente arranca la animación.

## Sofía no se dibuja durante la partida

Aparecía abajo del todo, recortada por el borde de la pantalla y sin
animación. No aportaba nada jugable y se veía mal, así que el sprite va
oculto.

El nodo se conserva igual, porque marca el punto al que apuntan las
embestidas y los escupitajos del jefe. Ese punto sigue subiendo 265px en
las peleas de jefe (contra 60px en un nivel normal) para no quedar
detrás del panel de vidas de abajo — si se borrara el nodo, el jefe
apuntaría al fondo de la pantalla.

En la derrota se reusa la misma placa: desaparecen el cartel de racha, la
medalla y la fila de monedas, la placa **se encoge** lo que ocupaban esas
filas (si no queda madera vacía), los íconos pasan a corazones, y "Seguir"
se convierte en "Otra vez" (o se esconde si no quedan vidas).

## La tienda no scrolleaba bien

Reportaron que la lista "se pega, o se mueve para un solo lado". El
`ScrollContainer` tenía `scroll_deadzone = 0`, así que cualquier `Button`
hijo se quedaba con el arrastre apenas lo tocabas: el scroll solo
funcionaba si empezabas el gesto justo en un hueco entre tarjetas.

Con `scroll_deadzone = 18` el contenedor deja pasar los primeros 18px de
movimiento antes de decidir si es un scroll o un toque. Aplicado en
`shop.tscn`, `skill_tree.tscn`, `level_select.tscn` y `world_map.tscn`.

## Objetos pasivos (`ItemSystem`)

La tienda tiene dos secciones. Las **armas** se equipan de a una; los
**objetos** son mejoras por niveles que hacen efecto solas y están
pensadas para aguantar las peleas de jefe:

**Pasivos** — hacen efecto solos:

| Objeto | Qué hace |
|---|---|
| Guantes de Trabajo | +1 de daño plano por nivel |
| Botiquín de la Abuela | +2 corazones en las peleas de jefe |
| Delantal Reforzado | Bloquea 1 de cada N golpes recibidos |
| Repelente Casero | Los refuerzos del jefe vienen más lentos |
| Trébol de la Suerte | +10% de golpe crítico (daño doble) |
| Frasco de Monedas | +15% de monedas al terminar el nivel |
| Reloj de Arena | +5 segundos de nivel |
| Lupa del Abuelo | Más radio de golpe |
| Botas de Goma | Te perdona fallos sin cortarte el combo |

**Poderes activos** — aparecen como botón en la pantalla de juego:

| Poder | Qué hace | Desbloqueo | Por uso |
|---|---|---|---|
| Reloj de Bolsillo | Cámara lenta unos segundos | 900 | 60 |
| Campo Expansivo | El próximo golpe abarca muchísimo más | 1400 | 90 |
| Tormenta de Rayos | Golpea a TODOS los insectos en pantalla | 2200 | 150 |
| Lanzallamas | Quema todo alrededor durante unos segundos | 3200 | 220 |

Los poderes se pagan **dos veces**: el desbloqueo y cada activación. Sin
el costo por uso serían gratis para siempre después de la primera compra
y romperían el juego; así hay que elegir cuándo vale la pena la moneda.
Subir de nivel un poder no encarece el uso, lo hace más fuerte.

Tres detalles que no son obvios:

- El **crítico se tira una vez por tap**, no por insecto. Si se tirara
  por insecto, un tap que agarra a cinco daría cinco tiradas y el trébol
  valdría mucho más de lo que dice.
- El **Campo Expansivo se gasta acierte o no**. Si solo se gastara al
  acertar, se podría dejar cargado indefinidamente tocando al vacío.
- La **cámara lenta no alarga el nivel**: `Engine.time_scale` escala el
  delta de `_process`, así que sin corregirlo el reloj también se frenaría
  y el objeto haría dos cosas a la vez. El contador se lleva a tiempo real
  dividiendo por `time_scale`. Y como `time_scale` es global y sobrevive
  al cambio de escena, se restaura en `_exit_tree`: si no, salir del nivel
  con la cámara lenta activa dejaba **todo el juego** lento para siempre.

El daño de los guantes se suma **después** del multiplicador del árbol, a
propósito: si se sumara antes, la rama Fuerza lo escalaría y dos mejoras
baratas juntas se volverían enormes. Y el Delantal cuenta golpes en vez
de tirar al azar, para que se pueda confiar en cuándo te toca aguantar
uno.

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
