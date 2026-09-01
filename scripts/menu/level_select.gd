extends Control

## Selector de niveles de un capítulo: grilla de 100 niveles con su
## estado, para poder **rejugar** cualquiera ya superado (como el mapa de
## Mario). Rejugar no pisa el avance: `GameManager.max_level_unlocked`
## va aparte de `current_level`.
##
## A qué capítulo entra lo decide `GameManager.selected_chapter`, que
## setea el mapa de mundos antes de cambiar de escena.

const COLUMNS := 5
const CELL := Vector2(84, 84)

## Paleta en tonos tierra/madera para que los casilleros no parezcan
## botones de formulario pegados encima del pergamino dibujado.
const COLOR_DONE := Color(0.36, 0.55, 0.26)
const COLOR_CURRENT := Color(0.98, 0.74, 0.22)
const COLOR_LOCKED := Color(0.35, 0.29, 0.22)
const COLOR_BOSS := Color(0.66, 0.24, 0.22)
const COLOR_BOSS_DONE := Color(0.44, 0.28, 0.30)

@onready var title: Label = $Margin/VBox/Title
@onready var subtitle: Label = $Margin/VBox/Subtitle
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var back_button: Button = $Margin/VBox/BackButton

var chapter: int = 1

func _ready() -> void:
	UITheme.style_title(title, 26)
	UITheme.style_body(subtitle, 17)
	subtitle.add_theme_color_override("font_color", Color(0.93, 0.88, 0.75))
	UITheme.style_wood_button(back_button)
	back_button.custom_minimum_size = Vector2(0, 62)

	chapter = GameManager.selected_chapter
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/world_map.tscn"))

	title.text = "%d. %s" % [chapter, GameManager.level_manager.get_chapter_name(chapter)]
	var done := _levels_completed_in_chapter()
	subtitle.text = "%d / %d niveles · los 💀 son jefes" % [done, LevelManager.LEVELS_PER_CHAPTER]

	grid.columns = COLUMNS
	_build_grid()
	await get_tree().process_frame
	_scroll_to_current()

func _levels_completed_in_chapter() -> int:
	var first := (chapter - 1) * LevelManager.LEVELS_PER_CHAPTER + 1
	var last := chapter * LevelManager.LEVELS_PER_CHAPTER
	# max_level_unlocked apunta al primero NO jugado, así que los
	# completados de este capítulo son los que quedaron por debajo.
	return clampi(GameManager.max_level_unlocked - first, 0, last - first + 1)

func _build_grid() -> void:
	var first := (chapter - 1) * LevelManager.LEVELS_PER_CHAPTER + 1
	for offset in range(LevelManager.LEVELS_PER_CHAPTER):
		grid.add_child(_build_cell(first + offset))

func _build_cell(level: int) -> Control:
	var is_boss: bool = GameManager.level_manager.is_boss_level(level)
	var unlocked: bool = GameManager.is_level_unlocked(level)
	var completed: bool = level < GameManager.max_level_unlocked

	# Panel con Label adentro y no Button: un Button se come el arrastre y
	# la grilla de 100 niveles solo se podía deslizar desde los huecos.
	# Ver UITheme.make_tappable.
	var button := Panel.new()
	button.custom_minimum_size = CELL

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20 if level < 100 else 17)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	button.add_child(label)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	# Sobre el pergamino, sin borde y sombra los casilleros se pierden
	# contra el dibujo del mapa.
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	# Un borde oscuro en todos los casilleros los hace leer como fichas
	# apoyadas sobre el mapa y no como rectángulos de color plano.
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.16, 0.10, 0.05, 0.75)

	if not unlocked:
		style.bg_color = COLOR_BOSS.darkened(0.55) if is_boss else COLOR_LOCKED
		label.text = "🔒"
		label.modulate = Color(1, 1, 1, 0.7)
	else:
		if is_boss:
			style.bg_color = COLOR_BOSS_DONE if completed else COLOR_BOSS
			label.text = "💀\n%d" % level
		else:
			style.bg_color = COLOR_DONE if completed else COLOR_CURRENT
			label.text = str(level)
		if completed:
			style.border_color = Color(1, 0.96, 0.85, 0.4)
		UITheme.make_tappable(button, _on_level_pressed.bind(level))
		if level == GameManager.max_level_unlocked:
			# El nivel al que toca entrar: borde dorado grueso + latido.
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_color = Color(1, 0.92, 0.55)
			_pulse(button)

	button.add_theme_stylebox_override("panel", style)
	return button

func _pulse(node: Control) -> void:
	node.pivot_offset = CELL / 2.0
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(node, "scale", Vector2(1.09, 1.09), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

func _scroll_to_current() -> void:
	var scroll := $Margin/VBox/Scroll as ScrollContainer
	var first := (chapter - 1) * LevelManager.LEVELS_PER_CHAPTER + 1
	var index: int = clampi(GameManager.max_level_unlocked - first, 0, LevelManager.LEVELS_PER_CHAPTER - 1)
	var row: int = int(index / COLUMNS)
	var target: int = maxi(int(row * (CELL.y + 10.0) - scroll.size.y / 2.0), 0)
	var tween := create_tween()
	tween.tween_property(scroll, "scroll_vertical", target, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_level_pressed(level: int) -> void:
	# Los niveles de jefe consumen vida al perder, así que ni dejamos
	# entrar si no queda ninguna.
	if GameManager.level_manager.is_boss_level(level) and not GameManager.has_lives():
		subtitle.text = "Sin vidas. Regeneran solas, o recargalas en el menú."
		return
	GameManager.current_level = level
	GameManager.current_chapter = GameManager.level_manager.get_chapter_for_level(level)
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
