class_name BillingService
extends RefCounted

## COMPRAS DENTRO DEL JUEGO. Hoy es una SIMULACIÓN: muestra el cartel de
## confirmación con el precio y, si el jugador acepta, entrega la compra
## sin cobrar nada.
##
## Igual que con la publicidad, esto está aparte para que el día que se
## enchufe Google Play Billing haya que tocar SOLO este archivo. El resto
## del juego llama a `comprar()` y pregunta `Store.has(id)`.
##
## Lo único que NO puede quedar simulado el día de la publicación es la
## restauración: si alguien reinstala, sus compras tienen que volver
## solas. Con Play Billing eso es consultar las compras del usuario al
## abrir el juego y llamar a `Store.grant()` por cada una. Ver LEEME.md.

static func comprar(padre: Node, id: String, al_terminar: Callable = Callable()) -> void:
	var datos := IapData.datos(id)
	if datos.is_empty() or padre == null or not is_instance_valid(padre):
		return
	if IapData.es_permanente(id) and Store.has(id):
		return

	var capa := CanvasLayer.new()
	capa.layer = 20
	padre.get_tree().root.add_child(capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.05, 0.04, 0.03, 0.9)
	capa.add_child(fondo)

	var tarjeta := PanelContainer.new()
	tarjeta.set_anchors_preset(Control.PRESET_CENTER)
	tarjeta.anchor_left = 0.0
	tarjeta.anchor_right = 1.0
	tarjeta.offset_left = 30.0
	tarjeta.offset_right = -30.0
	tarjeta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tarjeta.grow_vertical = Control.GROW_DIRECTION_BOTH
	tarjeta.add_theme_stylebox_override("panel", UITheme.card_style())
	capa.add_child(tarjeta)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	tarjeta.add_child(caja)

	var sello := Label.new()
	sello.text = "COMPRA SIMULADA · no se cobra nada"
	sello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sello.add_theme_font_size_override("font_size", 14)
	sello.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	caja.add_child(sello)

	var titulo := Label.new()
	titulo.text = str(datos.get("titulo", id))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_title(titulo, 26)
	caja.add_child(titulo)

	if datos.has("detalle"):
		var detalle := Label.new()
		detalle.text = str(datos["detalle"])
		detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.style_body(detalle, 17)
		caja.add_child(detalle)

	var precio := Label.new()
	precio.text = IapData.precio(id)
	precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	precio.add_theme_font_size_override("font_size", 30)
	precio.add_theme_color_override("font_color", Color(1, 0.85, 0.42))
	caja.add_child(precio)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	caja.add_child(fila)

	var cancelar := Button.new()
	cancelar.text = "Ahora no"
	cancelar.custom_minimum_size = Vector2(0, 56)
	cancelar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_wood_button(cancelar)
	cancelar.pressed.connect(func(): capa.queue_free())
	fila.add_child(cancelar)

	var confirmar := Button.new()
	confirmar.text = "Comprar"
	confirmar.custom_minimum_size = Vector2(0, 56)
	confirmar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_wood_button(confirmar, Color(1.1, 1.25, 0.9))
	confirmar.pressed.connect(func():
		capa.queue_free()
		Store.grant(id)
		if al_terminar.is_valid():
			al_terminar.call())
	fila.add_child(confirmar)
