# APK de demo

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
historia narrada por Don Beto con **retratos reales por emoción**
(neutral/feliz/triste/enojado/preocupado, ya no es un tinte simulado).
`hormiga_obrera` (el bicho del nivel 1 y del tutorial) tiene un **ciclo
de caminata animado real** de 4 frames; el resto de los insectos todavía
usa un solo sprite estático con balanceo/rebote procedural.

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

**Sobre el bug de orientación**: son en realidad DOS bugs de exportación
de Godot 4.7.1 sobre Android, no uno — hace falta arreglar los dos o el
juego arranca de costado (con márgenes negros, hay que rotar el celular
para verlo bien):

1. El manifest de Android empaqueta `screenOrientation="landscape"`
   hardcodeado, ignorando la configuración del proyecto.
2. Un manifest generado (`release/AndroidManifest.xml`) pisa
   `resizeableActivity` a `"true"` vía un merge de Gradle
   (`tools:replace`), aunque el manifest principal del proyecto ya pide
   `"false"` — y una activity marcada como resizeable hace que Android
   ignore el orientation lock del punto 1 en varios dispositivos, incluso
   con el `screenOrientation` ya arreglado. Este segundo bug es el que
   se me había pasado en el build anterior.

Los dos hace falta parchearlos a mano en el manifest y compilar con
Gradle directamente en vez de con el exportador de Godot por CLI. Está
documentado paso a paso (con el comando para verificar que las dos cosas
quedaron bien antes de repartir el APK) en el `README.md` de la raíz del
repo, sección "Gotcha de exportación Android". Si volvés a generar este
APK vos mismo, seguí esos pasos o el build te va a salir en horizontal
de nuevo.

**Para un build completo** (con toda la música), corré la exportación
vos mismo desde el editor de Godot — `export_presets.cfg` está limpio en
el repo (sin `exclude_filter`), pero acordate de aplicar el fix de
orientación de todos modos.
