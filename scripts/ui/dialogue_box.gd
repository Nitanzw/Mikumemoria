class_name DialogueBox
extends CanvasLayer

## Caja de diálogo reutilizable: retrato de Sofía + nombre + texto con
## efecto máquina de escribir. Se instancia dinámicamente donde haga
## falta (intro, tutorial) con DialogueBox.show_dialogue(lineas).
## Un tap mientras tipea completa la línea al toque; un tap con la línea
## ya completa avanza a la siguiente. Emite `finished` y se autodestruye
## al terminar todas las líneas.

signal finished

const CHARS_PER_SECOND := 38.0

## Cuánto se encoge el globo al aparecer, y la altura del rebote de la
## flechita de continuar.
const BUBBLE_POP := 0.94
const ARROW_BOB := 5.0

@onready var portrait: SofiaPortrait = $SofiaPortrait
@onready var bubble: Panel = $Bubble
@onready var tail: Panel = $Tail
@onready var name_label: Label = $Bubble/VBox/NameLabel
@onready var text_label: Label = $Bubble/VBox/TextLabel
@onready var continue_hint: Label = $Bubble/ContinueHint

var _arrow_phase: float = 0.0
var _arrow_base_y: float = 0.0

var _lines: Array = []
var _index: int = -1
var _full_text: String = ""
var _typing: bool = false
var _char_progress: float = 0.0

func _ready() -> void:
	continue_hint.visible = false
	await get_tree().process_frame
	_arrow_base_y = continue_hint.position.y

func show_dialogue(lines: Array) -> void:
	_lines = lines
	_index = -1
	_advance()

func _process(delta: float) -> void:
	# La flecha late aunque no pase nada más: es lo que le dice al jugador
	# que la pantalla está esperándolo a él y no colgada.
	if continue_hint.visible:
		_arrow_phase += delta * 3.4
		continue_hint.position.y = _arrow_base_y + absf(sin(_arrow_phase)) * ARROW_BOB

	if not _typing:
		return
	_char_progress += delta * CHARS_PER_SECOND
	var char_count: int = mini(int(_char_progress), _full_text.length())
	text_label.text = _full_text.substr(0, char_count)
	if char_count >= _full_text.length():
		_typing = false
		portrait.set_talking(false)
		continue_hint.visible = true

func _unhandled_input(event: InputEvent) -> void:
	var touch_event := event as InputEventScreenTouch
	if touch_event and touch_event.pressed:
		get_viewport().set_input_as_handled()
		_on_tap()

func _on_tap() -> void:
	if _typing:
		_finish_typing_instantly()
	else:
		_advance()

func _finish_typing_instantly() -> void:
	_char_progress = _full_text.length()
	text_label.text = _full_text
	_typing = false
	portrait.set_talking(false)
	continue_hint.visible = true

func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		finished.emit()
		queue_free()
		return

	var line: Dictionary = _lines[_index]
	name_label.text = str(line.get("speaker", ""))
	portrait.set_emotion(str(line.get("emotion", "neutral")))

	_full_text = str(line.get("text", ""))
	_char_progress = 0.0
	_typing = true
	portrait.set_talking(true)
	continue_hint.visible = false
	text_label.text = ""
	_pop_bubble()

## El globo entra con un rebote corto en cada línea. Sin esto el texto
## cambia solo y no se nota que arrancó una frase nueva.
func _pop_bubble() -> void:
	for node: Control in [bubble, tail]:
		node.scale = Vector2(BUBBLE_POP, BUBBLE_POP)
		var tween := create_tween()
		tween.tween_property(node, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
