# APK de demo

`invasion_huerto_demo.apk` es un build de **Android debug/testing** para
probar el juego rápido en un dispositivo, sin tener que instalar Godot ni
el Android SDK. Firmado con una keystore de prueba generada para esta
build (no es la keystore de producción — para publicar en Play Store hay
que generar una propia y no commitearla).

**Qué tiene**: capítulo 1 completo (menú → nivel → tienda → árbol de
habilidades), con el arte y la música reales (no placeholders) de
`assets/`.

**Qué le falta a propósito, para entrar bajo el límite de 100MB de
GitHub**: la música de los capítulos 2 a 10 (`level_theme_2.mp3` a
`level_theme_10.mp3`) no está incluida en este build — el motor de Godot
por sí solo ya pesa ~71MB sin comprimir más. En el juego esto no rompe
nada: `game_level.gd` cae automáticamente a la música de `level_theme_1`
si la del capítulo actual no está empaquetada (mismo mecanismo que usa
cuando todavía no generaste la pista de un capítulo). Todos los sprites
y fondos de los 10 capítulos SÍ están incluidos.

**Cómo instalar**: pasá el `.apk` al teléfono (o descargalo directo desde
GitHub en el celular) y abrilo — Android va a pedir habilitar "instalar
apps de origenes desconocidos" para el navegador/gestor de archivos que
uses.

**Para un build completo** (con toda la música), corré la exportación
vos mismo desde el editor de Godot con `export_presets.cfg` tal cual
está en el repo (sin el `exclude_filter` que se usó solo para este demo).
