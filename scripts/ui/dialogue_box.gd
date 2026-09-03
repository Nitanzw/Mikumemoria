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

## El globo crece HACIA ARRIBA: el pico se queda abajo, apuntando a
## Sofía, así que lo que se mueve es el borde de arriba.
const BUBBLE_BOTTOM := 466.0
const BUBBLE_MIN_HEIGHT := 250.0
## No subir más allá de acá, para no comerse la barra del HUD.
const BUBBLE_TOP_LIMIT := 100.0
## Márgenes del VBox adentro del globo (ver la escena) más aire para que
## la última línea no quede debajo de la flechita de continuar.
const BUBBLE_PAD_X := 52.0
const BUBBLE_PAD_Y := 40.0
## Aire de más abajo del texto. Tiene que alcanzar para la flechita de
## continuar, que va anclada abajo a la derecha y se superpone al área de
## texto: con poco aire, la última línea le quedaba encima.
const BUBBLE_SLACK := 42.0

## Cuánto tarda en entrar el marco de la viñeta.
const BAND_FADE := 0.22

## El HUD se esconde mientras Sofía habla.
##
## Al principio se hizo al revés -se lo dejó a la vista y se acomodaron
## los efectos para no taparlo- y quedaba raro: puntaje, reloj y barras de
## vida flotando encima de una viñeta de cómic. Y no informan nada, porque
## durante un diálogo el nivel está pausado. La viñeta se lee mejor sola.
const HUD_FADE := 0.18

@onready var portrait: SofiaPortrait = $SofiaPortrait
@onready var bubble: Panel = $Bubble
@onready var tail: Panel = $Tail
@onready var name_label: Label = $Bubble/VBox/NameLabel
@onready var text_label: Label = $Bubble/VBox/TextLabel
@onready var continue_hint: Label = $Bubble/ContinueHint
@onready var rayos: TextureRect = $Fondo/Rayos
@onready var marco: Array[ColorRect] = [$MarcoArriba, $MarcoAbajo, $MarcoIzq, $MarcoDer]

var _arrow_phase: float = 0.0
var _arrow_base_y: float = 0.0

var _lines: Array = []
var _index: int = -1
var _full_text: String = ""
var _typing: bool = false
var _char_progress: float = 0.0

func _ready() -> void:
	continue_hint.visible = false
	_mostrar_hud(false)
	_entrar_bandas()

## Esconde o devuelve el HUD de la partida.
##
## Va por grupo y no por ruta: el mismo diálogo se usa en la intro, en el
## tutorial y en el mapa de mundos, donde no hay HUD. Si no hay ninguno,
## esto no hace nada.
func _mostrar_hud(visible_: bool) -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		var capa := hud as CanvasLayer
		if capa == null:
			continue
		# Se anima el hijo raíz y no el CanvasLayer, que no tiene modulate.
		for hijo in capa.get_children():
			var control := hijo as CanvasItem
			if control == null:
				continue
			var t := create_tween()
			t.tween_property(control, "modulate:a", 1.0 if visible_ else 0.0, HUD_FADE)
	await get_tree().process_frame
	_arrow_base_y = continue_hint.position.y

## La viñeta entra: el marco aparece y los rayos giran un poco al entrar.
##
## Antes acá había dos bandas negras que tapaban a Sofía por arriba y por
## abajo, porque el retrato era un busto y sin taparlo se veía cortado.
## Ahora la figura va ENTERA, así que no hay nada que esconder: el marco
## es marco de viñeta, no un parche.
func _entrar_bandas() -> void:
	for borde: ColorRect in marco:
		borde.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(borde, "modulate:a", 1.0, BAND_FADE)
	# Los rayos entran girando un poco y creciendo: es el golpe de viñeta
	# que hace que la charla se sienta un momento y no una pausa.
	var desde := rayos.scale
	rayos.modulate.a = 0.0
	rayos.pivot_offset = rayos.size * 0.5
	# Entra GRANDE y se achica hasta su tamaño, nunca al revés: los rayos
	# ocupan la pantalla entera, así que arrancar en 0.86 dejaría un
	# marco vacío alrededor durante la entrada — justo el efecto cortado
	# que había que sacar.
	rayos.scale = desde * 1.14
	rayos.rotation = -0.08
	var tr := create_tween().set_parallel(true)
	tr.tween_property(rayos, "modulate:a", 0.5, BAND_FADE * 1.4)
	tr.tween_property(rayos, "scale", desde, BAND_FADE * 1.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tr.tween_property(rayos, "rotation", 0.0, BAND_FADE * 1.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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

## Devuelve el HUD sin tween: el nodo está por destruirse y un tween
## creado acá se muere con él, dejando el HUD invisible para siempre.
func _devolver_hud() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		var capa := hud as CanvasLayer
		if capa == null:
			continue
		for hijo in capa.get_children():
			var control := hijo as CanvasItem
			if control:
				control.modulate.a = 1.0

func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_devolver_hud()
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
	_ajustar_globo()
	_pop_bubble()

## Estira el globo para que entre TODO el texto de la línea.
##
## Era un panel de alto fijo (250px) y el Label adentro simplemente
## recortaba lo que sobraba: con una línea larga, o con el tamaño de
## texto en "grande", la última frase quedaba cortada por la mitad y no
## había forma de leerla.
##
## Se mide con la fuente y el tamaño EFECTIVOS del Label, no con los de
## la escena: SettingsManager reescala los Label con un override de tema,
## así que el tamaño real depende del ajuste que eligió el jugador.
func _ajustar_globo() -> void:
	var ancho: float = get_viewport().get_visible_rect().size.x - 44.0 - BUBBLE_PAD_X
	var alto := BUBBLE_PAD_Y + BUBBLE_SLACK
	for etiqueta: Label in [name_label, text_label]:
		var fuente := etiqueta.get_theme_font("font")
		var tam := etiqueta.get_theme_font_size("font_size")
		if fuente == null:
			continue
		var texto: String = _full_text if etiqueta == text_label else etiqueta.text
		alto += fuente.get_multiline_string_size(
			texto, HORIZONTAL_ALIGNMENT_LEFT, ancho, tam).y
	# La separación del VBox entre las dos etiquetas.
	alto += 6.0

	var arriba: float = maxf(BUBBLE_BOTTOM - maxf(alto, BUBBLE_MIN_HEIGHT), BUBBLE_TOP_LIMIT)
	bubble.offset_top = arriba
	bubble.offset_bottom = BUBBLE_BOTTOM
	# El pivote del rebote va al centro del globo nuevo, si no el pop lo
	# escala desde un punto que ya no le corresponde y se ve descentrado.
	bubble.pivot_offset = Vector2(bubble.size.x * 0.5, (BUBBLE_BOTTOM - arriba) * 0.5)

## El globo entra con un rebote corto en cada línea. Sin esto el texto
## cambia solo y no se nota que arrancó una frase nueva.
func _pop_bubble() -> void:
	for node: Control in [bubble, tail]:
		node.scale = Vector2(BUBBLE_POP, BUBBLE_POP)
		var tween := create_tween()
		tween.tween_property(node, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
