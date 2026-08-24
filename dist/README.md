# APK de demo — El Huerto de Sofía

`invasion_huerto_demo.apk` es un build de Android **release**, firmado
con una keystore de prueba (no es la keystore de producción — para
publicar en Play Store hay que generar una propia y no commitearla).
~38MB, arquitectura arm64-v8a solamente.

**Qué tiene**: capítulo 1 completo (intro con diálogo → menú → mapa de
mundos → nivel con tutorial la primera vez → tienda → árbol de
habilidades), con el arte, la música y los SFX reales (no placeholders)
de `assets/` — los SFX son CC0 de Kenney.nl. Orientación **fija en
vertical** (ver más abajo — fue un bug real, ya corregido), HUD con
fuente grande y contorno para que se lea bien, niveles de 30 segundos,
historia narrada por **Sofía** con retratos reales por emoción
(neutral/feliz/triste/enojada/preocupada/sorprendida). Los **5 insectos
comunes** tienen ciclo de caminata animado de 4 cuadros; los 10
incógnitos usan un cuadro fijo con balanceo procedural.

**Feedback del golpe**: al tocar la pantalla se ve el **arma equipada**
(el zapato viejo de arranque, o la que tengas puesta) bajando, aplastando
y levantándose en el punto del tap; al matar un insecto salta una
**salpicadura** con gotas, del color de ese bicho, más un **sonido de
aplastado**. La pantalla ahora **usa todo el alto** del celular — antes
`stretch/aspect` estaba en `keep` y dejaba franjas negras arriba y abajo
en pantallas 19.5:9, y el HUD se cortaba a los costados.

**Qué le falta a propósito, para mantener el tamaño chico**: la música
de los capítulos 2 a 10 (`level_theme_2.mp3` a `level_theme_10.mp3`) no
está incluida en este build. En el juego esto no rompe nada:
`game_level.gd` cae automáticamente a la música de `level_theme_1` si la
del capítulo actual no está empaquetada (mismo mecanismo que usa cuando
todavía no generaste la pista de un capítulo). Todos los sprites y
fondos de los 10 capítulos SÍ están incluidos.

**Cómo instalar**: pasá el `.apk` al teléfono (o descargalo directo desde
GitHub en el celular) y abrilo — Android va a pedir habilitar "instalar
apps de orígenes desconocidos" para el navegador/gestor de archivos que
uses.

**Sobre el bug de orientación** (arrastrado por varios builds, ya
resuelto de raíz): no era un problema del manifest de Android ni una
política de Samsung — era un **error de tipo en `project.godot`**.

En Godot 3, `display/window/handheld/orientation` era un string
(`"portrait"`); en **Godot 4 es un entero** (enum: `0`=Landscape,
`1`=Portrait, …). El proyecto lo tenía como string, y Godot lo convertía
silenciosamente a **0 = Landscape**. De ahí salía todo:

- Godot escribía `screenOrientation="landscape"` en el manifest generado
  (parecía que "Godot hardcodea landscape", no era eso).
- Parchear el manifest a mano **no arreglaba nada**, porque Godot llama a
  `setRequestedOrientation()` al arrancar con ese mismo 0 y esa llamada
  pisa el manifest. Estaba arreglando el lugar equivocado.
- Las franjas negras a los costados no eran letterboxing de Android:
  eran de Godot, encajando el contenido vertical (540×960) con
  `stretch/aspect="keep"` dentro de una ventana horizontal.

La corrección real es una línea: `window/handheld/orientation=1` (entero,
sin comillas). Está explicado en detalle, con los comandos para
verificar el **tipo** de la setting y el manifest binario del APK, en el
`README.md` de la raíz, sección "Orientación en Android:
`handheld/orientation` es un ENTERO, no un string".

**Para un build completo** (con toda la música), corré la exportación
vos mismo desde el editor de Godot — `export_presets.cfg` está limpio en
el repo (sin `exclude_filter`), pero acordate de aplicar el fix de
orientación de todos modos.
