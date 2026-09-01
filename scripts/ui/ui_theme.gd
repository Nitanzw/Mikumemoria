class_name UITheme
extends RefCounted

## Estilos compartidos de los menús (tienda, habilidades, mapa, menú
## principal). Están acá y no repetidos en cada pantalla para que
## cambiar el arte de un botón o de una tarjeta se haga en un solo lugar.

const WOOD_BUTTON := "res://assets/sprites/ui/button_wood.png"
const CARD_PANEL := "res://assets/sprites/ui/panel_card.png"
const COIN_ICON := "res://assets/sprites/ui/coin.png"

## Márgenes de 9-slice. El cartel de madera tiene tornillos en las puntas
## y un borde tallado: si se estirara entero se deformarían, así que se
## estira solo el centro.
## Ojo: estos márgenes se miden sobre la textura YA RECORTADA a su
## contenido opaco. Las imágenes salieron del generador con mucho margen
## transparente alrededor; si no se recortan, el 9-slice estira la parte
## vacía y la madera queda corrida respecto del contenido.
const WOOD_MARGIN_X := 40.0
const WOOD_MARGIN_Y := 20.0
const CARD_MARGIN_X := 48.0
const CARD_MARGIN_Y := 44.0


## Distancia que puede moverse el dedo y que el gesto siga contando como
## toque. Más que esto es un arrastre y no dispara nada.
const TAP_SLOP := 14.0

## Hace que un Control responda al toque SIN comerse el arrastre.
##
## El problema que resuelve: un Button adentro de un ScrollContainer se
## queda con el evento, así que el contenedor nunca ve el gesto y la lista
## solo se puede deslizar desde los huecos entre casilleros. `scroll_deadzone`
## no alcanza, porque el deadzone actúa sobre eventos que al contenedor
## nunca le llegan.
##
## Con MOUSE_FILTER_PASS el nodo recibe el evento y además lo deja subir al
## contenedor, así que se puede deslizar desde cualquier lado. A cambio hay
## que detectar el toque a mano: se guarda dónde empezó y cuánto se movió,
## y solo cuenta como toque si el dedo casi no se corrió.
static func make_tappable(control: Control, on_tap: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	var state := {"holding": false, "start": Vector2.ZERO, "moved": 0.0}
	control.gui_input.connect(func(event: InputEvent) -> void:
		var position := Vector2.ZERO
		var pressed := false
		var is_click := false

		var touch := event as InputEventScreenTouch
		if touch:
			is_click = true
			pressed = touch.pressed
			position = touch.position
		else:
			var mouse := event as InputEventMouseButton
			if mouse and mouse.button_index == MOUSE_BUTTON_LEFT:
				is_click = true
				pressed = mouse.pressed
				position = mouse.position

		if is_click:
			if pressed:
				state["holding"] = true
				state["start"] = position
				state["moved"] = 0.0
			elif state["holding"]:
				state["holding"] = false
				var corrido: float = maxf(
					position.distance_to(state["start"]), float(state["moved"]))
				if corrido <= TAP_SLOP:
					on_tap.call()
			return

		# El acumulado importa además de la distancia final: si alguien
		# baja, sube y suelta donde empezó, eso fue un scroll, no un toque.
		if not state["holding"]:
			return
		var drag := event as InputEventScreenDrag
		if drag:
			state["moved"] = float(state["moved"]) + drag.relative.length()
			return
		var motion := event as InputEventMouseMotion
		if motion:
			state["moved"] = float(state["moved"]) + motion.relative.length()
	)

## Aplica la textura de cartel de madera a un botón, con sus estados.
## Si el asset no existe, no toca nada y el botón queda con el tema por
## defecto (así el juego no se rompe si falta una imagen).
## `tint` permite destacar el botón principal de una pantalla sin pedir
## otra textura: se multiplica sobre la madera. Verde para "seguir",
## que es la acción que uno busca con el pulgar sin leer.
static func style_wood_button(button: Button, tint: Color = Color(1, 1, 1)) -> void:
	if not ResourceLoader.exists(WOOD_BUTTON):
		return
	var wood: Texture2D = load(WOOD_BUTTON)
	button.add_theme_stylebox_override("normal", _wood_box(wood, tint))
	button.add_theme_stylebox_override("hover", _wood_box(wood, tint * 1.12))
	button.add_theme_stylebox_override("pressed", _wood_box(wood, tint * 0.82))
	button.add_theme_stylebox_override("focus", _wood_box(wood, tint))
	# Un botón deshabilitado (ya comprado, o sin monedas) se ve apagado
	# pero conserva la madera, para que se lea como el mismo objeto.
	button.add_theme_stylebox_override("disabled", _wood_box(wood, Color(0.55, 0.52, 0.5)))

	button.add_theme_color_override("font_color", Color(1, 0.98, 0.9))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.6))
	button.add_theme_color_override("font_disabled_color", Color(0.82, 0.78, 0.72))
	button.add_theme_color_override("font_outline_color", Color(0.24, 0.13, 0.05))
	button.add_theme_constant_override("outline_size", 5)

static func _wood_box(wood: Texture2D, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = wood
	style.modulate_color = tint
	style.texture_margin_left = WOOD_MARGIN_X
	style.texture_margin_right = WOOD_MARGIN_X
	style.texture_margin_top = WOOD_MARGIN_Y
	style.texture_margin_bottom = WOOD_MARGIN_Y
	return style

## Tarjeta de madera para las filas de una lista.
static func card_style() -> StyleBox:
	if ResourceLoader.exists(CARD_PANEL):
		var style := StyleBoxTexture.new()
		style.texture = load(CARD_PANEL)
		style.texture_margin_left = CARD_MARGIN_X
		style.texture_margin_right = CARD_MARGIN_X
		style.texture_margin_top = CARD_MARGIN_Y
		style.texture_margin_bottom = CARD_MARGIN_Y
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 12.0
		style.content_margin_bottom = 12.0
		return style
	return _fallback_card()

static func _fallback_card() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.14, 0.10, 0.85)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style

## Panel oscuro translúcido, para que el texto se lea sobre un fondo
## ilustrado sin taparlo del todo.
static func scrim_style(alpha: float = 0.55) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, alpha)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

## Título de pantalla, con contorno para que se lea sobre cualquier fondo.
static func style_title(label: Label, size: int = 30) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_color_override("font_color", Color(1, 0.97, 0.88))

static func style_body(label: Label, size: int = 19) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_color_override("font_color", Color(1, 0.98, 0.94))

## Fila "🪙 1234" con el ícono real de moneda en vez del emoji.
static func build_coin_row(amount: int, font_size: int = 22) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)

	if ResourceLoader.exists(COIN_ICON):
		var icon := TextureRect.new()
		icon.texture = load(COIN_ICON)
		icon.custom_minimum_size = Vector2(font_size + 8, font_size + 8)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	var label := Label.new()
	label.text = str(amount)
	style_body(label, font_size)
	label.add_theme_color_override("font_color", Color(1, 0.87, 0.45))
	row.add_child(label)
	return row
