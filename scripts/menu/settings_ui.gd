extends Control

## Pantalla de ajustes: volúmenes, tamaño de texto e idioma.
## Todo se aplica y se guarda al toque, sin botón de "aceptar": en un
## juego de celular hacer que el jugador confirme un slider es fricción
## para nada, y además así escucha el cambio mientras arrastra.

const SLIDER_HEIGHT := 44
## Los dos estados del botón de mute. Salieron de una sola generación y
## recortados con el mismo encuadre, así que la corneta cae en el mismo
## lugar en los dos: al togglear cambian las ondas por la cruz y nada más.
const ICONO_SONIDO_ON := preload("res://assets/sprites/ui/ui_sonido_on.png")
const ICONO_SONIDO_OFF := preload("res://assets/sprites/ui/ui_sonido_off.png")
## Aire entre el ícono y el marco de madera del botón.
const ICONO_MARGEN := 5
## El botón va casi cuadrado a propósito. El TextureRect ajusta por el
## lado que sobra, así que en un botón chato la corneta se dibujaba a la
## mitad del alto y no se leía qué era.
const MUTE_BOTON := Vector2(56, 48)

@onready var rows: VBoxContainer = $Margin/VBox/Scroll/Rows
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
	# Franja de publicidad de abajo, y el margen para que no tape nada.
	BannerAd.mostrar(self)
	BannerAd.reservar($Margin)
	UITheme.style_wood_button(back_button)
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	_build()

func _build() -> void:
	for child in rows.get_children():
		child.queue_free()

	rows.add_child(_section("Sonido"))
	rows.add_child(_volume_row("General", "Master", SettingsManager.master_volume))
	rows.add_child(_volume_row("Música", "Music", SettingsManager.music_volume))
	rows.add_child(_volume_row("Efectos", "SFX", SettingsManager.sfx_volume))

	rows.add_child(_section("Texto"))
	rows.add_child(_choice_row(
		SettingsManager.TEXT_SCALES.keys(),
		SettingsManager.text_size,
		func(value): SettingsManager.set_text_size(value),
		func(value): return str(value).capitalize()))

	rows.add_child(_section("Idioma"))
	rows.add_child(_choice_row(
		SettingsManager.LANGUAGES.keys(),
		SettingsManager.language,
		func(value): SettingsManager.set_language(value),
		func(value): return str(SettingsManager.LANGUAGES[value])))

	var note := Label.new()
	note.text = tr("La historia todavía está solo en español.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_body(note, 15)
	note.add_theme_color_override("font_color", Color(0.82, 0.76, 0.66))
	rows.add_child(note)

	rows.add_child(_section(""))
	var reset := Button.new()
	reset.text = tr("Volver a los valores de fábrica")
	reset.custom_minimum_size = Vector2(0, 54)
	reset.add_theme_font_size_override("font_size", 18)
	UITheme.style_wood_button(reset)
	reset.pressed.connect(func():
		SettingsManager.reset_to_defaults()
		AudioManager.play_sfx("unlock")
		_build())
	rows.add_child(reset)

## Encabezado con filete, igual que en la tienda.
func _section(title: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	box.add_child(spacer)
	if title != "":
		var label := Label.new()
		label.text = title
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_title(label, 22)
		box.add_child(label)
	return box

## Fila de volumen: nombre, porcentaje y barra. El porcentaje se actualiza
## mientras arrastrás, si no no sabés dónde quedaste.
func _volume_row(label_text: String, bus_name: String, value: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, MUTE_BOTON.y)
	header.add_theme_constant_override("separation", 8)

	# Mute a un toque. Va acá arriba y no como un paso más de la barra
	# porque son dos cosas distintas: "callate un rato" y "dejalo bajito".
	var mute := Button.new()
	mute.custom_minimum_size = MUTE_BOTON
	mute.focus_mode = Control.FOCUS_NONE
	header.add_child(mute)

	# El ícono va como hijo y no en `mute.icon`: la propiedad del Button lo
	# mete adentro del layout del texto y lo achica contra el borde. Un
	# TextureRect estirado al botón menos el margen lo deja centrado y del
	# tamaño que uno pide. IGNORE para que el toque siga siendo del botón.
	var mute_icon := TextureRect.new()
	mute_icon.name = "Icono"
	mute_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	mute_icon.offset_left = ICONO_MARGEN
	mute_icon.offset_top = ICONO_MARGEN
	mute_icon.offset_right = -ICONO_MARGEN
	mute_icon.offset_bottom = -ICONO_MARGEN
	mute_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mute_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mute_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mute.add_child(mute_icon)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_body(name_label, 19)
	header.add_child(name_label)

	var value_label := Label.new()
	value_label.text = "%d%%" % int(round(value * 100.0))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(64, 0)
	UITheme.style_body(value_label, 19)
	value_label.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	header.add_child(value_label)
	box.add_child(header)

	var slider := HSlider.new()
	_style_slider(slider)
	_refresh_mute(mute, slider, value_label, bus_name, value)
	mute.pressed.connect(func():
		SettingsManager.toggle_mute(bus_name)
		_refresh_mute(mute, slider, value_label, bus_name, slider.value)
		if not SettingsManager.is_muted(bus_name) and bus_name != "Music":
			AudioManager.play_sfx("splat"))

	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT)
	slider.value_changed.connect(func(new_value: float):
		SettingsManager.set_volume(bus_name, new_value)
		_refresh_mute(mute, slider, value_label, bus_name, new_value))
	# Un sonidito al soltar, para escuchar cómo quedaron los efectos.
	slider.drag_ended.connect(func(changed: bool):
		if changed and bus_name != "Music":
			AudioManager.play_sfx("splat"))
	box.add_child(slider)
	return box

## Pone el ícono, el porcentaje y el apagado de la fila según el estado.
## Muteado se muestra el porcentaje que quedará al volver, en gris: el
## nivel sigue ahí, solo que no se oye.
func _refresh_mute(mute: Button, slider: HSlider, value_label: Label,
		bus_name: String, value: float) -> void:
	var silenced := SettingsManager.is_muted(bus_name)
	var icon := mute.get_node_or_null("Icono") as TextureRect
	if icon:
		icon.texture = ICONO_SONIDO_OFF if silenced else ICONO_SONIDO_ON
	# Verde prendido / rojo apagado, el mismo par que usan los botones de
	# tamaño de texto e idioma más abajo. Así el estado se lee de una por
	# el color de la tabla, sin tener que mirar el ícono: la corneta de
	# bronce sobre madera es linda pero a 56px tiene poco contraste.
	UITheme.style_wood_button(mute,
		Color(0.95, 0.55, 0.5) if silenced else Color(0.52, 1.05, 0.55))
	value_label.text = "%d%%" % int(round(value * 100.0))
	value_label.add_theme_color_override("font_color",
		Color(0.7, 0.64, 0.58) if silenced else Color(1, 0.88, 0.5))
	slider.modulate = Color(1, 1, 1, 0.45 if silenced else 1.0)

## La HSlider por defecto es una línea gris de 4px, invisible sobre el
## fondo de la tienda. Se le pone la misma ranura y el mismo verde que las
## barras de nivel de la tienda, para que sea el mismo idioma visual.
func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.13, 0.07, 0.03, 0.95)
	track.set_corner_radius_all(7)
	track.border_color = Color(0.42, 0.30, 0.14)
	track.set_border_width_all(2)
	track.content_margin_top = 7.0
	track.content_margin_bottom = 7.0
	slider.add_theme_stylebox_override("slider", track)

	var filled := StyleBoxFlat.new()
	filled.bg_color = Color(0.44, 0.82, 0.24)
	filled.set_corner_radius_all(7)
	filled.content_margin_top = 7.0
	filled.content_margin_bottom = 7.0
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)

	var knob := StyleBoxFlat.new()
	knob.bg_color = Color(1.0, 0.86, 0.42)
	knob.set_corner_radius_all(14)
	knob.border_color = Color(0.42, 0.26, 0.06)
	knob.set_border_width_all(3)
	knob.content_margin_left = 14.0
	knob.content_margin_right = 14.0
	knob.content_margin_top = 14.0
	knob.content_margin_bottom = 14.0
	slider.add_theme_stylebox_override("grabber", knob)
	slider.add_theme_stylebox_override("grabber_highlight", knob)

## Fila de opciones excluyentes (tamaño de texto, idioma).
##
## Va en grilla de dos columnas y no en una fila: la madera de los botones
## tiene 40px de margen a cada lado, así que cuatro opciones en una línea
## medían más que los 540 de ancho y estiraban toda la pantalla, cortando
## hasta el botón de Volver que no tenía nada que ver.
func _choice_row(values: Array, current, on_pick: Callable, to_label: Callable) -> Control:
	var row := GridContainer.new()
	row.columns = 2 if values.size() > 2 else values.size()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for value in values:
		var button := Button.new()
		button.text = str(to_label.call(value))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 52)
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 17)
		# El elegido queda en verde, igual que el "Seguir" del resumen.
		# NO se deshabilita: el estado "disabled" de la madera es gris y
		# pisaba el verde, así que la opción activa se veía apagada en vez
		# de destacada, justo al revés de lo que hay que comunicar.
		# Volver a elegir lo mismo ya es un no-op más arriba.
		UITheme.style_wood_button(button, Color(0.52, 1.05, 0.55) if value == current else Color(1, 1, 1))
		button.pressed.connect(func():
			on_pick.call(value)
			AudioManager.play_sfx("unlock")
			_build())
		row.add_child(button)
	return row
