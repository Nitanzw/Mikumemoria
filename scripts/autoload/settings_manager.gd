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
const FONT_FALLBACKS := [
	"res://assets/fonts/NotoSansSC.ttf",
	"res://assets/fonts/NotoSansJP.ttf",
	"res://assets/fonts/NotoSansKR.ttf",
	"res://assets/fonts/NotoSansArabic.ttf",
	"res://assets/fonts/NotoSansDevanagari.ttf",
	"res://assets/fonts/NotoSansBengali.ttf",
]

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
	_install_font_fallbacks()
	load_settings()
	apply_all()
	# Cada nodo de texto que entra al árbol se ajusta solo. Hace falta
	# engancharse acá y no en cada pantalla porque media UI se construye
	# por código (la tienda arma sus casilleros a mano).
	get_tree().node_added.connect(_on_node_added)

## Cuelga las Noto de la fuente por defecto. Se hace una sola vez, al
## arrancar, y vale para TODA la interfaz: no hay que tocar ni un Label.
func _install_font_fallbacks() -> void:
	var base := ThemeDB.fallback_font
	if base == null:
		return
	var caidas: Array[Font] = []
	for ruta in FONT_FALLBACKS:
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
	save_settings()

func set_language(code: String) -> void:
	if not LANGUAGES.has(code) or code == language:
		return
	language = code
	TranslationServer.set_locale(code)
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
