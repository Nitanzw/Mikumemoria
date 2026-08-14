extends Control

## Mapa de mundos: un nodo por capítulo (10), en zigzag de abajo hacia
## arriba (capítulo 1 abajo, 10 arriba). Estado por nodo: bloqueado,
## actual (jugable), completado. Al entrar, hace scroll animado hasta
## el nodo actual — es el "se mueve solo, un poco animado" que se pidió
## para las transiciones de capítulo.

const CHAPTER_COUNT := 10
const NODE_SPACING_Y := 150.0
const TOP_MARGIN := 100.0
const BOTTOM_MARGIN := 120.0
const ZIGZAG_X := 110.0
const NODE_SIZE := 96.0

const COLOR_LOCKED := Color(0.3, 0.3, 0.32)
const COLOR_CURRENT := Color(1.0, 0.8, 0.2)
const COLOR_DONE := Color(0.4, 0.75, 0.4)

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var map_area: Control = $ScrollContainer/MapArea
@onready var back_button: Button = $BackButton

var _chapter_nodes: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	_build_map()
	await get_tree().process_frame
	_scroll_to_current()

func _build_map() -> void:
	var total_height: int = int(CHAPTER_COUNT * NODE_SPACING_Y + TOP_MARGIN + BOTTOM_MARGIN)
	map_area.custom_minimum_size = Vector2(0, total_height)

	for chapter in range(1, CHAPTER_COUNT + 1):
		var node := _build_chapter_node(chapter, total_height)
		map_area.add_child(node)
		_chapter_nodes[chapter] = node

func _build_chapter_node(chapter: int, total_height: int) -> Control:
	var y: float = total_height - BOTTOM_MARGIN - chapter * NODE_SPACING_Y
	var zigzag: float = ZIGZAG_X if chapter % 2 == 0 else -ZIGZAG_X
	var center_x := 270.0

	# El wrapper lleva la posición Y real (así world_map.gd puede leer
	# node.position.y para saber dónde scrollear); button/label solo
	# llevan offsets relativos a ese wrapper.
	var wrapper := Control.new()
	wrapper.position = Vector2(0, y - NODE_SIZE / 2.0)

	var button := Button.new()
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.position = Vector2(center_x + zigzag - NODE_SIZE / 2.0, 0.0)
	button.text = str(chapter)
	button.add_theme_font_size_override("font_size", 30)

	var name_label := Label.new()
	name_label.text = GameManager.level_manager.get_chapter_name(chapter)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(center_x - 90.0, NODE_SIZE + 4.0)
	name_label.custom_minimum_size = Vector2(180, 40)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = int(NODE_SIZE / 2.0)
	style.corner_radius_top_right = int(NODE_SIZE / 2.0)
	style.corner_radius_bottom_left = int(NODE_SIZE / 2.0)
	style.corner_radius_bottom_right = int(NODE_SIZE / 2.0)

	if chapter < GameManager.current_chapter:
		style.bg_color = COLOR_DONE
		button.text = "✓"
		button.disabled = true
	elif chapter == GameManager.current_chapter:
		style.bg_color = COLOR_CURRENT
		button.pressed.connect(_on_play_pressed)
		_pulse(button)
	else:
		style.bg_color = COLOR_LOCKED
		button.text = "🔒"
		button.disabled = true

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_stylebox_override("hover", style)

	wrapper.add_child(button)
	wrapper.add_child(name_label)
	return wrapper

func _pulse(node: Control) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(node, "scale", Vector2(1.08, 1.08), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

func _scroll_to_current() -> void:
	var node: Control = _chapter_nodes.get(GameManager.current_chapter)
	if not node:
		return
	var target: int = clampi(int(node.position.y - scroll.size.y / 2.0), 0, map_area.custom_minimum_size.y)
	var tween := create_tween()
	tween.tween_property(scroll, "scroll_vertical", target, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
