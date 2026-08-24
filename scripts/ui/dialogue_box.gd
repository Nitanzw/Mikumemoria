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

@onready var portrait: SofiaPortrait = $Dim/Panel/SofiaPortrait
@onready var name_label: Label = $Dim/Panel/HBox/VBox/NameLabel
@onready var text_label: Label = $Dim/Panel/HBox/VBox/TextLabel
@onready var continue_hint: Label = $Dim/Panel/HBox/VBox/ContinueHint

var _lines: Array = []
var _index: int = -1
var _full_text: String = ""
var _typing: bool = false
var _char_progress: float = 0.0

func _ready() -> void:
	continue_hint.visible = false

func show_dialogue(lines: Array) -> void:
	_lines = lines
	_index = -1
	_advance()

func _process(delta: float) -> void:
	if not _typing:
		return
	_char_progress += delta * CHARS_PER_SECOND
	var char_count: int = mini(int(_char_progress), _full_text.length())
	text_label.text = _full_text.substr(0, char_count)
	if char_count >= _full_text.length():
		_typing = false
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
	continue_hint.visible = false
	text_label.text = ""
