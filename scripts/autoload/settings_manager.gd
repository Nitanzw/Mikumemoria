extends Node

## Preferencias del jugador: volúmenes, tamaño de texto e idioma.
##
## Van en su propio archivo y NO en la partida guardada a propósito: si
## alguien borra el progreso, no tiene sentido que además se le vuelva a
## poner el audio al mango y el texto chico.

signal settings_changed

const SETTINGS_PATH := "user://settings.json"

## El audio salía al 100% y era demasiado: arranca a la mitad y cada uno
## lo sube si quiere. Es el default, no un tope.
const DEFAULT_VOLUME := 0.5
## Debajo de esto se considera silencio y el bus se apaga del todo, en vez
## de dejar un hilito audible.
const MUTE_THRESHOLD := 0.001

const TEXT_SCALES := {
	"chico": 0.9,
	"normal": 1.0,
	"grande": 1.15,
	"enorme": 1.3,
}

## Los 15 idiomas, cada uno escrito EN SU PROPIO IDIOMA. Es a propósito:
## alguien que abre el juego y no entiende el idioma en el que está
## necesita reconocer el suyo en la lista, y "日本語" lo reconoce, "Japonés"
## no. El orden va por cantidad de hablantes, no alfabético.
const LANGUAGES := {
	"en": "English",
	"zh_CN": "简体中文",
	"es": "Español",
	"hi": "हिन्दी",
	"ar": "العربية",
	"bn": "বাংলা",
	"pt": "Português",
	"ru": "Русский",
	"ur": "اردو",
	"ja": "日本語",
	"de": "Deutsch",
	"fr": "Français",
	"ko": "한국어",
	"it": "Italiano",
	"nl": "Nederlands",
}

## Fuentes que se cuelgan como respaldo de la fuente por defecto.
##
## La de Godot (Open Sans) cubre latino, cirílico y griego, y NADA de
## chino, japonés, coreano, árabe, devanagari ni bengalí — medido: de esos
## idiomas no tenía un solo glifo, así que el texto salía en cuadraditos.
##
## Van como fallback y no como fuente principal para no perder el look:
## el latino sigue dibujándose con Open Sans, y sólo los caracteres que
## Open Sans no tiene caen en la Noto que corresponda.
##
## Están recortadas a los glifos que el juego usa de verdad (ver
## tools/subset_fonts.py): enteras pesan 22 MB, recortadas 316 KB.
## Qué fuente de reserva necesita CADA idioma. Antes se colgaban las seis
## siempre, y eso tenía un costo que no era obvio: la altura de línea de
## un Label es la de la fuente MÁS ALTA de la cadena, y la Noto de
## bengalí y la de devanagari tienen ascendente y descendente enormes.
## Resultado: en castellano el texto se dibujaba con 54 px de alto de
## línea en vez de 35, todo separadísimo y ocupando el doble de lugar.
##
## Ahora se cuelga sólo la que hace falta para el idioma que está puesto,
## y se cambia al cambiar de idioma. Los idiomas de alfabeto latino no
## cuelgan ninguna: la fuente del juego ya los tiene.
const FONT_FALLBACKS := {
	"zh_CN": "res://assets/fonts/NotoSansSC.ttf",
	"ja": "res://assets/fonts/NotoSansJP.ttf",
	"ko": "res://assets/fonts/NotoSansKR.ttf",
	"ar": "res://assets/fonts/NotoSansArabic.ttf",
	"ur": "res://assets/fonts/NotoSansArabic.ttf",
	"hi": "res://assets/fonts/NotoSansDevanagari.ttf",
	"bn": "res://assets/fonts/NotoSansBengali.ttf",
}

## Idiomas que se escriben de derecha a izquierda.
const RTL_LANGUAGES := ["ar", "ur"]

var master_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME
var text_size: String = "normal"
var language: String = "es"
## Falso hasta que el jugador elige idioma la primera vez. Es lo que
## dispara la pantalla de selección al abrir el juego recién instalado.
var language_chosen: bool = false

## El mute va SEPARADO del volumen a propósito: si mutear pusiera la barra
## en cero, al volver no habría a dónde volver. Así el nivel se conserva y
## desmutear lo devuelve donde estaba.
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false

func _ready() -> void:
	# Primero el guardado, después la fuente: la Noto que se cuelga
	# depende del idioma, y antes de leer el guardado el idioma todavía
	# es el de fábrica.
	load_settings()
	_install_font_fallbacks()
	apply_all()
	# Cada nodo de texto que entra al árbol se ajusta solo. Hace falta
	# engancharse acá y no en cada pantalla porque media UI se construye
	# por código (la tienda arma sus casilleros a mano).
	get_tree().node_added.connect(_on_node_added)

## Cuelga de la fuente por defecto la Noto que necesita el idioma actual,
## y sólo esa. Vale para TODA la interfaz: no hay que tocar ni un Label.
func _install_font_fallbacks() -> void:
	var ruta: String = str(FONT_FALLBACKS.get(language, ""))
	_poner_fallbacks([ruta] if ruta != "" else [])

## Cuelga TODAS las Noto de una. La necesita la pantalla de selección de
## idioma, que es el único lado donde conviven los 15 alfabetos: ahí sí
## hace falta poder dibujar chino, árabe y bengalí en la misma lista, y
## el alto de línea de más no importa porque son quince renglones sueltos.
func install_all_fallbacks() -> void:
	_poner_fallbacks(FONT_FALLBACKS.values())

func _poner_fallbacks(rutas: Array) -> void:
	var base := ThemeDB.fallback_font
	if base == null:
		return
	var caidas: Array[Font] = []
	var puestas: Array = []
	for ruta in rutas:
		if ruta in puestas:
			continue
		puestas.append(ruta)
		if ResourceLoader.exists(ruta):
			caidas.append(load(ruta))
		else:
			push_warning("[Settings] falta la fuente %s: ese idioma va a salir en cuadraditos" % ruta)
	base.fallbacks = caidas

func is_rtl(code: String = "") -> bool:
	return (code if code != "" else language) in RTL_LANGUAGES

## Idioma sugerido según el que tiene puesto el celular, para que la
## pantalla de selección arranque con esa opción marcada. Si el idioma del
## sistema no está entre los 15, cae en inglés.
func suggested_language() -> String:
	var sistema := OS.get_locale()
	if LANGUAGES.has(sistema):
		return sistema
	var corto := sistema.split("_")[0]
	for code in LANGUAGES:
		if code == corto or code.begins_with(corto + "_"):
			return code
	return "en"

func get_text_scale() -> float:
	return float(TEXT_SCALES.get(text_size, 1.0))

func apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	TranslationServer.set_locale(language)

## El oído no es lineal: a media barra, un 0.5 lineal se escucha casi
## igual de fuerte. linear_to_db da la curva que hace que la mitad de la
## barra suene como la mitad.
func _apply_bus(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	if is_muted(bus_name) or value <= MUTE_THRESHOLD:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(value, 0.0, 1.0)))

func set_volume(bus_name: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus_name:
		"Master": master_volume = value
		"Music": music_volume = value
		"SFX": sfx_volume = value
		_: return
	if value > MUTE_THRESHOLD:
		set_muted(bus_name, false)
	_apply_bus(bus_name, value)
	save_settings()
	settings_changed.emit()

func get_volume(bus_name: String) -> float:
	match bus_name:
		"Master": return master_volume
		"Music": return music_volume
		"SFX": return sfx_volume
	return 1.0

func is_muted(bus_name: String) -> bool:
	match bus_name:
		"Master": return master_muted
		"Music": return music_muted
		"SFX": return sfx_muted
	return false

func set_muted(bus_name: String, muted: bool) -> void:
	match bus_name:
		"Master": master_muted = muted
		"Music": music_muted = muted
		"SFX": sfx_muted = muted
		_: return
	_apply_bus(bus_name, get_volume(bus_name))
	save_settings()
	settings_changed.emit()

func toggle_mute(bus_name: String) -> void:
	set_muted(bus_name, not is_muted(bus_name))

func set_text_size(size_name: String) -> void:
	if not TEXT_SCALES.has(size_name) or size_name == text_size:
		return
	text_size = size_name
	_rescale_tree(get_tree().root)
	save_settings()
	settings_changed.emit()

## Marca que el jugador ya eligió, para no volver a preguntarle.
func confirm_language(code: String) -> void:
	language_chosen = true
	if LANGUAGES.has(code) and code != language:
		language = code
		TranslationServer.set_locale(language)
		_install_font_fallbacks()
	save_settings()

func set_language(code: String) -> void:
	if not LANGUAGES.has(code) or code == language:
		return
	language = code
	TranslationServer.set_locale(code)
	# La fuente de reserva depende del idioma: se cambia acá y no al
	# arrancar, porque el idioma se puede cambiar en cualquier momento.
	_install_font_fallbacks()
	save_settings()
	settings_changed.emit()

# --- Tamaño de texto ---

## Se guarda el tamaño original la primera vez que se toca un nodo, así
## reescalar dos veces no acumula: siempre se parte del original.
const ORIGINAL_SIZE_META := "_base_font_size"

func _on_node_added(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		_rescale_node(node)

func _rescale_tree(root: Node) -> void:
	_rescale_node(root)
	for child in root.get_children():
		_rescale_tree(child)

func _rescale_node(node: Node) -> void:
	var control := node as Control
	if control == null:
		return
	if not (control is Label or control is Button or control is RichTextLabel):
		return

	# Antes de cualquier atajo: el vigilante de ancho tiene que quedar
	# enganchado aunque el nodo no tenga override propio de tamaño.
	_vigilar_ancho(control)

	var base: int
	if control.has_meta(ORIGINAL_SIZE_META):
		base = int(control.get_meta(ORIGINAL_SIZE_META))
	else:
		# Sin override propio no hay nada que reescalar: el nodo usa el
		# tamaño del tema y tocarlo acá le clavaría uno fijo.
		if not control.has_theme_font_size_override("font_size"):
			return
		base = control.get_theme_font_size("font_size")
		control.set_meta(ORIGINAL_SIZE_META, base)

	control.add_theme_font_size_override("font_size", maxi(int(round(base * get_text_scale())), 8))

# --- Que el texto entre en su caja ---
#
## Traducir rompe layouts: "Combo" en alemán es "Höchste Kombo" y en
## bengalí ocupa todavía más. Los Label de una sola línea con clip_text
## no avisan nada cuando eso pasa — simplemente recortan la palabra a la
## mitad, y del lado del jugador parece un bug del juego.
##
## Por eso el ancho se vigila solo: cuando un Label de una línea no entra
## en su caja, se le baja el cuerpo de letra de a un punto hasta que
## entre, con un piso para no volverlo ilegible. Es la misma idea que la
## del globo de diálogo, pero para las etiquetas sueltas.
const FIT_MIN_SCALE := 0.62

func _vigilar_ancho(control: Control) -> void:
	if not (control is Label):
		return
	if not control.resized.is_connected(_on_control_resized):
		control.resized.connect(_on_control_resized.bind(control))
	fit_label(control)

func _on_control_resized(control: Control) -> void:
	if is_instance_valid(control):
		fit_label(control)

## Achica la letra de un Label de una línea hasta que entre en su ancho.
## Se puede llamar a mano después de cambiarle el texto por código, que
## es lo único que el `resized` no cubre (cambiar el texto no siempre
## cambia el tamaño del nodo).
func fit_label(control: Control) -> void:
	var etiqueta := control as Label
	if etiqueta == null or not etiqueta.clip_text:
		return
	if etiqueta.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return
	if etiqueta.text.is_empty() or etiqueta.size.x <= 1.0:
		return
	var fuente := etiqueta.get_theme_font("font")
	if fuente == null:
		return

	var base: int
	if etiqueta.has_meta(ORIGINAL_SIZE_META):
		base = int(etiqueta.get_meta(ORIGINAL_SIZE_META))
	else:
		base = etiqueta.get_theme_font_size("font_size")
		etiqueta.set_meta(ORIGINAL_SIZE_META, base)

	var tam: int = maxi(int(round(float(base) * get_text_scale())), 8)
	var piso: int = maxi(int(round(float(tam) * FIT_MIN_SCALE)), 8)
	while tam > piso and fuente.get_string_size(
			etiqueta.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam).x > etiqueta.size.x:
		tam -= 1
	if tam != etiqueta.get_theme_font_size("font_size"):
		etiqueta.add_theme_font_size_override("font_size", tam)

# --- Persistencia ---

func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		push_warning("[Settings] no se pudo escribir %s" % SETTINGS_PATH)
		return
	file.store_string(JSON.stringify({
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"text_size": text_size,
		"language": language,
		"language_chosen": language_chosen,
		"master_muted": master_muted,
		"music_muted": music_muted,
		"sfx_muted": sfx_muted,
	}))
	file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	master_volume = clampf(float(parsed.get("master_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	music_volume = clampf(float(parsed.get("music_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	var size_name := str(parsed.get("text_size", "normal"))
	text_size = size_name if TEXT_SCALES.has(size_name) else "normal"
	var code := str(parsed.get("language", "es"))
	language = code if LANGUAGES.has(code) else "es"
	language_chosen = bool(parsed.get("language_chosen", false))
	master_muted = bool(parsed.get("master_muted", false))
	music_muted = bool(parsed.get("music_muted", false))
	sfx_muted = bool(parsed.get("sfx_muted", false))

func reset_to_defaults() -> void:
	master_volume = DEFAULT_VOLUME
	music_volume = DEFAULT_VOLUME
	sfx_volume = DEFAULT_VOLUME
	text_size = "normal"
	language = "es"
	master_muted = false
	music_muted = false
	sfx_muted = false
	apply_all()
	_rescale_tree(get_tree().root)
	save_settings()
	settings_changed.emit()
