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
  poder ver y probar el juego. Hay que reemplazarlas por arte final
  manteniendo los mismos nombres de archivo.
- **Audio**: no hay ningún `.ogg` todavía. `AudioManager` tolera archivos
  faltantes (imprime un aviso y sigue), así que el juego corre en
  silencio hasta que se agreguen `assets/sounds/sfx/*.ogg` y
  `assets/sounds/music/*.ogg` con los nombres que ya usa el código
  (`hit_<tipo>`, `taunt`, `mystery_revealed`, `level_complete`, `unlock`,
  `menu_theme`, etc).
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
