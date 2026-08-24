class_name LevelManager
extends RefCounted

## Configuración de niveles y capítulos. No es un singleton: GameManager
## mantiene una única instancia interna.

const MAX_LEVEL := 1000
const LEVELS_PER_CHAPTER := 100
const MYSTERY_BUG_PERIOD := 10

var chapter_configs := {
	1: {"name": "El Huerto de Tomates", "enemy_speed_mult": 1.0, "spawn_rate": 2.0, "background": "res://assets/sprites/backgrounds/chapter_1_huerto.jpg"},
	2: {"name": "El Invernadero", "enemy_speed_mult": 1.2, "spawn_rate": 1.8, "background": "res://assets/sprites/backgrounds/chapter_2_invernadero.jpg"},
	3: {"name": "La Cueva Subterránea", "enemy_speed_mult": 1.4, "spawn_rate": 1.6, "background": "res://assets/sprites/backgrounds/chapter_3_cueva.jpg"},
	4: {"name": "El Cultivo Radiactivo", "enemy_speed_mult": 1.6, "spawn_rate": 1.5, "background": "res://assets/sprites/backgrounds/chapter_4_radiactivo.jpg"},
	5: {"name": "El Pantano", "enemy_speed_mult": 1.7, "spawn_rate": 1.4, "background": "res://assets/sprites/backgrounds/chapter_5_pantano.jpg"},
	6: {"name": "Laboratorio Mutante", "enemy_speed_mult": 1.8, "spawn_rate": 1.3, "background": "res://assets/sprites/backgrounds/chapter_6_lab.jpg"},
	7: {"name": "Fábrica de Cascos", "enemy_speed_mult": 1.9, "spawn_rate": 1.2, "background": "res://assets/sprites/backgrounds/chapter_7_fabrica.jpg"},
	8: {"name": "Red de Túneles Express", "enemy_speed_mult": 2.1, "spawn_rate": 1.1, "background": "res://assets/sprites/backgrounds/chapter_8_tuneles.jpg"},
	9: {"name": "El Búnker Enemigo", "enemy_speed_mult": 2.3, "spawn_rate": 1.0, "background": "res://assets/sprites/backgrounds/chapter_9_bunker.jpg"},
	10: {"name": "El Núcleo Reina", "enemy_speed_mult": 2.5, "spawn_rate": 0.9, "background": "res://assets/sprites/backgrounds/chapter_10_nucleo.jpg"},
}

# Cada tier queda disponible desde ese nivel en adelante (acumulativo).
var enemy_unlock_tiers := {
	1: ["hormiga_obrera"],
	20: ["cucaracha_electrica"],
	50: ["escarabajo_blindado"],
	100: ["mosca_pesada"],
	150: ["grillo_saltarin"],
}

func get_chapter_for_level(level: int) -> int:
	return int((level - 1) / LEVELS_PER_CHAPTER) + 1

func get_level_config(level: int) -> Dictionary:
	var chapter := get_chapter_for_level(level)
	var chapter_config: Dictionary = chapter_configs.get(chapter, chapter_configs[1])

	return {
		"level": level,
		"chapter": chapter,
		"chapter_name": chapter_config.get("name", "Desconocido"),
		"background": chapter_config.get("background", ""),
		"spawn_rate": chapter_config.get("spawn_rate", 2.0),
		"enemy_speed_mult": chapter_config.get("enemy_speed_mult", 1.0),
		"time_limit": 30,
		"enemy_types": get_available_enemies(level),
		"has_mystery_bug": has_mystery_bug(level),
		"mystery_index": get_mystery_bug_index(level),
	}

func get_mystery_bug_index(level: int) -> int:
	# Nivel 1-9 -> 0 (sin misterio); 10-19 -> #1; 20-29 -> #2; etc.
	return int(level / MYSTERY_BUG_PERIOD)

func has_mystery_bug(level: int) -> bool:
	return get_mystery_bug_index(level) >= 1

func get_available_enemies(level: int) -> Array:
	var available: Array = []
	var tiers := enemy_unlock_tiers.keys()
	tiers.sort()
	for tier_level in tiers:
		if level >= tier_level:
			for enemy_type in enemy_unlock_tiers[tier_level]:
				if enemy_type not in available:
					available.append(enemy_type)
	return available

func get_chapter_name(chapter: int) -> String:
	return chapter_configs.get(chapter, {}).get("name", "Desconocido")
