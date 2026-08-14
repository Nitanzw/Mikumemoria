# APK de demo

`invasion_huerto_demo.apk` es un build de Android **release**, firmado
con una keystore de prueba (no es la keystore de producción — para
publicar en Play Store hay que generar una propia y no commitearla).
~38.9MB, arquitectura arm64-v8a solamente.

**Qué tiene**: capítulo 1 completo (menú → nivel → tienda → árbol de
habilidades), con el arte y la música reales (no placeholders) de
`assets/`. Orientación **fija en vertical** (ver más abajo — fue un bug
real, ya corregido), HUD con fuente grande y contorno para que se lea
bien, insectos con animación de balanceo/rebote, niveles de 30 segundos.

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

**Sobre el bug de orientación**: Godot 4.7.1 empaqueta el manifest de
Android con `screenOrientation="landscape"` hardcodeado, ignorando la
configuración del proyecto — hace falta parchear el manifest a mano y
compilar con Gradle directamente en vez de con el exportador de Godot
por CLI. Está documentado paso a paso en el `README.md` de la raíz del
repo, sección "Gotcha de exportación Android". Si volvés a generar este
APK vos mismo, seguí esos pasos o el build te va a salir en horizontal
de nuevo.

**Para un build completo** (con toda la música), corré la exportación
vos mismo desde el editor de Godot — `export_presets.cfg` está limpio en
el repo (sin `exclude_filter`), pero acordate de aplicar el fix de
orientación de todos modos.
