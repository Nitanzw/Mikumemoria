class_name DailyRewardPopup
extends RefCounted

## REGALO DIARIO. Aparece solo al entrar al menú, una vez por día.
##
## La racha de 7 días es la parte que importa: el regalo del primer día
## no hace volver a nadie, el del séptimo sí, y lo que hace volver el
## martes es no querer perder los seis días que ya lleva. Por eso se
## muestran los siete casilleros y no sólo el de hoy.
##
## El anuncio para duplicar es opcional y va abajo: el regalo se cobra
## igual sin mirar nada, así el que no quiere publicidad no siente que le
## están cobrando el regalo.

const CASILLA := Vector2(58, 66)

static func mostrar(padre: Node) -> void:
	if padre == null or not Store.daily_available():
		return

	var capa := CanvasLayer.new()
	capa.layer = 15
	padre.get_tree().root.add_child(capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.05, 0.04, 0.03, 0.88)
	capa.add_child(fondo)

	var tarjeta := PanelContainer.new()
	tarjeta.set_anchors_preset(Control.PRESET_CENTER)
	tarjeta.anchor_left = 0.0
	tarjeta.anchor_right = 1.0
	tarjeta.offset_left = 24.0
	tarjeta.offset_right = -24.0
	tarjeta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tarjeta.grow_vertical = Control.GROW_DIRECTION_BOTH
	tarjeta.add_theme_stylebox_override("panel", UITheme.card_style())
	capa.add_child(tarjeta)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	tarjeta.add_child(caja)

	var titulo := Label.new()
	titulo.text = TranslationServer.translate("Regalo diario")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_title(titulo, 30)
	caja.add_child(titulo)

	var dia := Store.daily_day()
	var racha := Label.new()
	racha.text = TranslationServer.translate("Día %d de 7") % dia
	racha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_body(racha, 18)
	caja.add_child(racha)

	caja.add_child(_fila_de_dias(dia))

	var premio := Store.daily_reward()
	var detalle := Label.new()
	detalle.text = _texto_premio(premio)
	detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_theme_font_size_override("font_size", 22)
	detalle.add_theme_color_override("font_color", Color(1, 0.85, 0.42))
	caja.add_child(detalle)

	var cobrar := Button.new()
	cobrar.text = TranslationServer.translate("Cobrar")
	cobrar.custom_minimum_size = Vector2(0, 56)
	UITheme.style_wood_button(cobrar)
	caja.add_child(cobrar)

	var doble := Button.new()
	doble.text = TranslationServer.translate("Ver anuncio y cobrar el doble")
	doble.custom_minimum_size = Vector2(0, 52)
	doble.add_theme_font_size_override("font_size", 18)
	UITheme.style_wood_button(doble, Color(1.15, 1.25, 0.85))
	doble.visible = Store.can_watch_rewarded()
	caja.add_child(doble)

	var cerrar := func(con_doble: bool):
		Store.claim_daily(con_doble)
		AudioManager.play_sfx("unlock")
		capa.queue_free()

	cobrar.pressed.connect(func(): cerrar.call(false))
	doble.pressed.connect(func():
		# El premio se entrega en el callback del anuncio, nunca antes:
		# si se entregara al abrirlo, se cobraría sin mirarlo.
		AdsService.mostrar_con_premio(padre, TranslationServer.translate("Regalo doble"), func(): cerrar.call(true)))

static func _fila_de_dias(dia_actual: int) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 4)
	for i in range(Store.DAILY_REWARDS.size()):
		var casilla := PanelContainer.new()
		casilla.custom_minimum_size = CASILLA
		var estilo := StyleBoxFlat.new()
		var hoy: bool = (i + 1) == dia_actual
		var pasado: bool = (i + 1) < dia_actual
		estilo.bg_color = Color(0.86, 0.68, 0.28) if hoy else (Color(0.35, 0.30, 0.24) if pasado else Color(0.20, 0.18, 0.15))
		estilo.set_corner_radius_all(10)
		estilo.set_border_width_all(2)
		estilo.border_color = Color(1, 0.9, 0.6, 0.85) if hoy else Color(0, 0, 0, 0.35)
		casilla.add_theme_stylebox_override("panel", estilo)

		var dentro := VBoxContainer.new()
		dentro.alignment = BoxContainer.ALIGNMENT_CENTER
		dentro.add_theme_constant_override("separation", 0)
		casilla.add_child(dentro)

		var numero := Label.new()
		numero.text = str(i + 1)
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero.add_theme_font_size_override("font_size", 15)
		numero.add_theme_color_override("font_color", Color(0.15, 0.12, 0.08) if hoy else Color(0.85, 0.82, 0.76))
		dentro.add_child(numero)

		var valor := Label.new()
		var premio: Dictionary = Store.DAILY_REWARDS[i]
		valor.text = str(int(premio.get("monedas", 0))) if premio.has("monedas") else ""
		if premio.has("vidas") and not premio.has("monedas"):
			valor.text = "+%d ♥" % int(premio["vidas"])
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		valor.clip_text = true
		valor.add_theme_font_size_override("font_size", 14)
		valor.add_theme_color_override("font_color", Color(0.2, 0.15, 0.06) if hoy else Color(0.95, 0.82, 0.45))
		dentro.add_child(valor)

		fila.add_child(casilla)
	return fila

static func _texto_premio(premio: Dictionary) -> String:
	var partes: Array[String] = []
	if int(premio.get("monedas", 0)) > 0:
		partes.append(TranslationServer.translate("%d monedas") % int(premio["monedas"]))
	if int(premio.get("vidas", 0)) > 0:
		partes.append(TranslationServer.translate("%d vidas") % int(premio["vidas"]))
	return " + ".join(partes)
