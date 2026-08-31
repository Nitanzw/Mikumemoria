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

const LANGUAGES := {
	"es": "Español",
	"en": "English",
}

var master_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME
var text_size: String = "normal"
var language: String = "es"

func _ready() -> void:
	load_settings()
	apply_all()
	# Cada nodo de texto que entra al árbol se ajusta solo. Hace falta
	# engancharse acá y no en cada pantalla porque media UI se construye
	# por código (la tienda arma sus casilleros a mano).
	get_tree().node_added.connect(_on_node_added)

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
	if value <= MUTE_THRESHOLD:
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
	_apply_bus(bus_name, value)
	save_settings()
	settings_changed.emit()

func set_text_size(size_name: String) -> void:
	if not TEXT_SCALES.has(size_name) or size_name == text_size:
		return
	text_size = size_name
	_rescale_tree(get_tree().root)
	save_settings()
	settings_changed.emit()

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

func reset_to_defaults() -> void:
	master_volume = DEFAULT_VOLUME
	music_volume = DEFAULT_VOLUME
	sfx_volume = DEFAULT_VOLUME
	text_size = "normal"
	language = "es"
	apply_all()
	_rescale_tree(get_tree().root)
	save_settings()
	settings_changed.emit()
