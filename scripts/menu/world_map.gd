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
@onready var title: Label = $TitlePanel/Title
@onready var title_panel: PanelContainer = $TitlePanel

var _chapter_nodes: Dictionary = {}

func _ready() -> void:
	title_panel.add_theme_stylebox_override("panel", UITheme.scrim_style(0.5))
	UITheme.style_title(title, 26)
	UITheme.style_wood_button(back_button)
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.custom_minimum_size = Vector2(0, 60)
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

## Ícono centrado sobre el nodo del capítulo, en vez de un emoji de la
## fuente del sistema.
func _poner_icono(nodo: Control, path: String, size: float) -> void:
	var icono := UITheme.icon_rect(path, size)
	if icono == null:
		return
	icono.set_anchors_preset(Control.PRESET_CENTER)
	icono.position = Vector2(-size * 0.5, -size * 0.5)
	nodo.add_child(icono)

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
	button.add_theme_constant_override("outline_size", 6)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	var name_label := Label.new()
	name_label.text = GameManager.level_manager.get_chapter_name(chapter)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(center_x - 90.0, NODE_SIZE + 4.0)
	name_label.custom_minimum_size = Vector2(180, 40)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UITheme.style_body(name_label, 18)

	var style := StyleBoxFlat.new()
	# Borde claro alrededor del nodo: sobre el pergamino ilustrado, sin
	# borde los círculos se confunden con el dibujo del mapa.
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_color = Color(0.98, 0.94, 0.84, 0.9)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	style.corner_radius_top_left = int(NODE_SIZE / 2.0)
	style.corner_radius_top_right = int(NODE_SIZE / 2.0)
	style.corner_radius_bottom_left = int(NODE_SIZE / 2.0)
	style.corner_radius_bottom_right = int(NODE_SIZE / 2.0)

	if chapter < GameManager.get_max_chapter_unlocked():
		# Los capítulos ya superados quedan entrables: es la única forma
		# de volver a jugar sus niveles desde el selector.
		style.bg_color = COLOR_DONE
		button.text = ""
		_poner_icono(button, UITheme.ICON_CHECK, NODE_SIZE * 0.5)
		button.pressed.connect(_on_chapter_pressed.bind(chapter))
	elif chapter == GameManager.get_max_chapter_unlocked():
		style.bg_color = COLOR_CURRENT
		button.pressed.connect(_on_chapter_pressed.bind(chapter))
		_pulse(button)
	else:
		style.bg_color = COLOR_LOCKED
		button.text = ""
		_poner_icono(button, UITheme.ICON_LOCK, NODE_SIZE * 0.5)
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
	var node: Control = _chapter_nodes.get(GameManager.get_max_chapter_unlocked())
	if not node:
		return
	var target: int = clampi(int(node.position.y - scroll.size.y / 2.0), 0, map_area.custom_minimum_size.y)
	var tween := create_tween()
	tween.tween_property(scroll, "scroll_vertical", target, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Entrar a un capítulo abre su selector de niveles, no el nivel directo:
## así se puede elegir cuál jugar o rejugar.
func _on_chapter_pressed(chapter: int) -> void:
	GameManager.selected_chapter = chapter
	get_tree().change_scene_to_file("res://scenes/menu/level_select.tscn")
