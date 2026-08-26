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

const COLOR_DONE := Color(0.30, 0.62, 0.32)
const COLOR_CURRENT := Color(1.0, 0.78, 0.20)
const COLOR_LOCKED := Color(0.26, 0.26, 0.30)
const COLOR_BOSS := Color(0.72, 0.22, 0.28)
const COLOR_BOSS_DONE := Color(0.45, 0.30, 0.42)

@onready var title: Label = $Margin/VBox/Title
@onready var subtitle: Label = $Margin/VBox/Subtitle
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var back_button: Button = $Margin/VBox/BackButton

var chapter: int = 1

func _ready() -> void:
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

func _build_cell(level: int) -> Button:
	var is_boss: bool = GameManager.level_manager.is_boss_level(level)
	var unlocked: bool = GameManager.is_level_unlocked(level)
	var completed: bool = level < GameManager.max_level_unlocked

	var button := Button.new()
	button.custom_minimum_size = CELL
	button.add_theme_font_size_override("font_size", 20 if level < 100 else 17)
	button.add_theme_constant_override("outline_size", 5)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0

	if not unlocked:
		style.bg_color = COLOR_BOSS.darkened(0.55) if is_boss else COLOR_LOCKED
		button.text = "🔒"
		button.disabled = true
	else:
		if is_boss:
			style.bg_color = COLOR_BOSS_DONE if completed else COLOR_BOSS
			button.text = "💀\n%d" % level
		else:
			style.bg_color = COLOR_DONE if completed else COLOR_CURRENT
			button.text = str(level)
		if completed:
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_color = Color(1, 1, 1, 0.35)
		button.pressed.connect(_on_level_pressed.bind(level))
		if level == GameManager.max_level_unlocked:
			_pulse(button)

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_stylebox_override("focus", style)
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
