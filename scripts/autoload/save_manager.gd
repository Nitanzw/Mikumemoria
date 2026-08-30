extends Node

## SAVE MANAGER - Persistencia de datos (autoload "SaveManager").
## Sin class_name: coincidiría con el nombre del autoload y Godot
## rechaza esa combinación al compilar.

const SAVE_PATH := "user://invasion_huerto_save.json"
const SAVE_VERSION := 1

## Guarda TODO lo que le pase GameManager.
##
## Antes esta función tenía una lista blanca de campos y copiaba uno por
## uno; cualquier cosa nueva que GameManager agregara al diccionario se
## descartaba en silencio, sin error ni aviso. Eso hacía que
## `story_seen`, `seen_tutorials`, `seen_chapter_intros` y
## `mystery_progress` no sobrevivieran a cerrar el juego: la intro y el
## tutorial volvían a aparecer en cada arranque y el progreso de
## revelación de los incógnitos se perdía.
##
## Ahora el esquema lo define GameManager._build_save_dict() y acá solo
## se agregan los metadatos del archivo. Si mañana se suma un campo, se
## guarda solo.
func save_game(data: Dictionary) -> bool:
	var save_data := data.duplicate(true)
	save_data["version"] = SAVE_VERSION
	save_data["timestamp"] = Time.get_unix_time_from_system()

	var json_string := JSON.stringify(save_data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file:
		file.store_string(json_string)
		return true

	push_warning("[SaveManager] Error al guardar: no se pudo abrir el archivo")
	return false

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No hay archivo guardado")
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("[SaveManager] Error al leer archivo de guardado")
		return {}

	var json_string := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(json_string)

	if error == OK and json.data is Dictionary:
		print("[SaveManager] Guardado cargado exitosamente")
		return json.data

	push_warning("[SaveManager] Error al parsear el JSON de guardado")
	return {}

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(SAVE_PATH)
		if error == OK:
			print("[SaveManager] Archivo de guardado eliminado")
