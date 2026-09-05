class_name AdsService
extends RefCounted

## PUBLICIDAD. Hoy es una SIMULACIÓN: dibuja un cartel a pantalla completa
## con una cuenta regresiva y avisa cuando "termina" el anuncio.
##
## Está separado del resto a propósito. El día que se enchufe AdMob de
## verdad hay que cambiar SOLO este archivo: el juego llama siempre a
## `mostrar_con_premio()` y `mostrar_entre_niveles()`, y no sabe ni le
## importa quién sirve el anuncio. Ver scripts/services/LEEME.md.
##
## Dos tipos, y la diferencia importa:
##
##   - CON PREMIO (rewarded): lo pide el jugador tocando un botón, se ve
##     entero y paga algo. Es el que no molesta y el que más plata deja
##     por impresión.
##   - ENTRE NIVELES (interstitial): aparece solo. Va con cuentagotas y
##     nunca justo después de perder — ese es el que hace desinstalar.

## Cuánto dura el simulado. El de verdad dura lo que dure.
const DURACION_PREMIO := 5.0
const DURACION_ENTRE_NIVELES := 4.0
## Antes de esto no se puede cerrar el de entre niveles.
const ESPERA_PARA_CERRAR := 2.0

static func mostrar_con_premio(padre: Node, titulo: String, al_terminar: Callable) -> void:
	if padre == null or not is_instance_valid(padre):
		return
	if not Store.can_watch_rewarded():
		_aviso(padre, "Por hoy no quedan más anuncios con premio.\nVolvé mañana.")
		return
	print(AdsConfig.aviso("recompensado", AdsConfig.recompensado()))
	_abrir(padre, titulo, DURACION_PREMIO, true, func():
		Store.note_rewarded_watched()
		if al_terminar.is_valid():
			al_terminar.call())

static func mostrar_entre_niveles(padre: Node, al_terminar: Callable = Callable()) -> void:
	if padre == null or not is_instance_valid(padre):
		return
	if not Store.should_show_interstitial():
		if al_terminar.is_valid():
			al_terminar.call()
		return
	Store.note_interstitial_shown()
	print(AdsConfig.aviso("intersticial", AdsConfig.intersticial()))
	_abrir(padre, "Publicidad", DURACION_ENTRE_NIVELES, false, al_terminar)

# --- El cartel simulado ---

static func _abrir(padre: Node, titulo: String, duracion: float, con_premio: bool,
		al_terminar: Callable) -> void:
	var capa := CanvasLayer.new()
	# Arriba de todo: el diálogo va en 3, el borde del modo extremo en 2.
	capa.layer = 20
	padre.get_tree().root.add_child(capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.04, 0.05, 0.06, 1.0)
	capa.add_child(fondo)

	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_left = 40.0
	caja.offset_right = -40.0
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 18)
	capa.add_child(caja)

	var sello := Label.new()
	sello.text = "ANUNCIO SIMULADO"
	sello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sello.add_theme_font_size_override("font_size", 15)
	sello.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	caja.add_child(sello)

	var titulo_label := Label.new()
	titulo_label.text = titulo
	titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo_label.add_theme_font_size_override("font_size", 27)
	titulo_label.add_theme_color_override("font_color", Color(1, 0.93, 0.72))
	caja.add_child(titulo_label)

	var cuenta := Label.new()
	cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cuenta.add_theme_font_size_override("font_size", 21)
	cuenta.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86))
	caja.add_child(cuenta)

	var nota := Label.new()
	nota.text = "Acá va el anuncio de verdad cuando esté enchufado AdMob."
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_font_size_override("font_size", 14)
	nota.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	caja.add_child(nota)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, 54)
	cerrar.disabled = true
	UITheme.style_wood_button(cerrar)
	caja.add_child(cerrar)

	# El estado va en un Diccionario y no en variables sueltas porque las
	# lambdas de GDScript capturan las locales POR VALOR: `restante -= 0.1`
	# adentro de la lambda modificaba una copia y la cuenta regresiva se
	# quedaba clavada en 5. Un Diccionario se captura por referencia.
	var estado := {"restante": duracion, "terminado": false}

	var cerrar_todo := func(dar_premio: bool):
		if estado["terminado"]:
			return
		estado["terminado"] = true
		capa.queue_free()
		if dar_premio and al_terminar.is_valid():
			al_terminar.call()

	cerrar.pressed.connect(func(): cerrar_todo.call(true))

	# El reloj vive colgado de la capa, así se muere con ella si alguien
	# cambia de escena en el medio.
	var reloj := Timer.new()
	reloj.wait_time = 0.1
	capa.add_child(reloj)
	reloj.timeout.connect(func():
		estado["restante"] -= 0.1
		var queda: float = estado["restante"]
		if queda > 0.0:
			cuenta.text = "%s en %d…" % ["Premio" if con_premio else "Seguí", int(ceil(queda))]
			# El de premio no se puede saltear: si se saltea, no se cobra.
			# El de entre niveles se puede cerrar después de unos segundos,
			# que es lo que pide Google y lo que pide el sentido común.
			cerrar.disabled = con_premio or queda > duracion - ESPERA_PARA_CERRAR
		else:
			cuenta.text = "¡Listo!" if con_premio else ""
			cerrar.disabled = false
			cerrar.text = "Cobrar" if con_premio else "Seguir"
			reloj.stop())
	reloj.start()

static func _aviso(padre: Node, texto: String) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 20
	padre.get_tree().root.add_child(capa)
	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.04, 0.05, 0.06, 0.9)
	capa.add_child(fondo)
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_left = 46.0
	caja.offset_right = -46.0
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 20)
	capa.add_child(caja)
	var label := Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 21)
	caja.add_child(label)
	var boton := Button.new()
	boton.text = "Bueno"
	boton.custom_minimum_size = Vector2(0, 54)
	UITheme.style_wood_button(boton)
	boton.pressed.connect(func(): capa.queue_free())
	caja.add_child(boton)
