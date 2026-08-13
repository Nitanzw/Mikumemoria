extends Node

## SAVE MANAGER - Persistencia de datos (autoload "SaveManager").
## Sin class_name: coincidiría con el nombre del autoload y Godot
## rechaza esa combinación al compilar.

const SAVE_PATH := "user://invasion_huerto_save.json"
const SAVE_VERSION := 1

func save_game(data: Dictionary) -> bool:
	var save_data := {
		"version": SAVE_VERSION,
		"current_level": data.get("current_level", 1),
		"coins": data.get("coins", 0),
		"unlocked_insects": data.get("unlocked_insects", []),
		"unlocked_weapons": data.get("unlocked_weapons", ["zapato_viejo"]),
		"equipped_weapon": data.get("equipped_weapon", "zapato_viejo"),
		"skill_tree": data.get("skill_tree", {}),
		"timestamp": Time.get_unix_time_from_system(),
	}

	var json_string := JSON.stringify(save_data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file:
		file.store_string(json_string)
		print("[SaveManager] Juego guardado en: %s" % SAVE_PATH)
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
