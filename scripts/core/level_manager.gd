class_name LevelManager
extends RefCounted

## Configuración de niveles y capítulos. No es un singleton: GameManager
## mantiene una única instancia interna.

const MAX_LEVEL := 1000
const LEVELS_PER_CHAPTER := 100
const MYSTERY_BUG_PERIOD := 10

## Cada cuántos niveles toca pelea de jefe (5, 10, 15, ...).
const BOSS_PERIOD := 5

## Cada cuántos niveles sube la dificultad, y cuánto sube.
const DIFFICULTY_PERIOD := 10
const TIER_SPEED_STEP := 0.08     # +8% de velocidad por escalón
const TIER_SPAWN_MULT := 0.94     # los bichos salen un 6% más seguido
const MIN_SPAWN_RATE := 0.55      # piso, para que no sea imposible
## +5 de vida por escalón (o sea, cada 10 niveles). Antes eran 2 y no
## alcanzaba: el arma sube +2 de daño por MEJORA y hay 10 mejoras por
## arma, así que en lo que tardás en subir un escalón de dificultad (+2
## de vida) podías comprar varias mejoras (+2 cada una). Con la primera
## arma al máximo en el nivel 40 matabas todo de un toque.
##
## Con 5 el jugador al día tarda 2 o 3 golpes, que es donde el nivel se
## siente. Se puede subir sin miedo a trabar el juego porque un nivel
## normal se gana sobreviviendo los 30 segundos, no matando una cuota:
## más vida cambia cuántos matás, no si ganás. Y el ingreso casi no
## cambia, porque el cuello de botella es cada cuánto aparece un bicho,
## no cuántas veces alcanzás a tapear.
const HP_PER_TIER := 5
## Los jefes duran hasta que cae uno de los dos, pero con un techo: si se
## acaba el tiempo y el jefe sigue vivo, se pierde una vida.
const BOSS_TIME_LIMIT := 90

var chapter_configs := {
	1: {"name": "El Huerto de Tomates", "enemy_speed_mult": 1.0, "spawn_rate": 1.1, "background": "res://assets/sprites/backgrounds/chapter_1_huerto.jpg"},
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
	8: ["cucaracha_electrica"],
	18: ["escarabajo_blindado"],
	30: ["mosca_pesada"],
	45: ["grillo_saltarin"],
	# A partir de acá entran las variantes: alternan uno rápido y frágil
	# con uno lento y duro, para que la mezcla en pantalla obligue a
	# priorizar en vez de tapear al azar.
	70: ["mutante_volador"],
	95: ["lombriz_gigante"],
	120: ["hormiga_ladrona"],
	150: ["abejorro_pinata"],
	190: ["mantis_cronometro"],
	240: ["rayo_insecto"],
	300: ["escarabajo_radiactivo"],
	380: ["centella_blindada"],
	480: ["coraza_antigua"],
}

func get_chapter_for_level(level: int) -> int:
	return int((level - 1) / LEVELS_PER_CHAPTER) + 1

func get_level_config(level: int) -> Dictionary:
	var chapter := get_chapter_for_level(level)
	var chapter_config: Dictionary = chapter_configs.get(chapter, chapter_configs[1])

	# La dificultad sube por escalones de 10 niveles DENTRO del capítulo.
	# Antes solo variaba por capítulo, y un capítulo son 100 niveles: te
	# ibas mejorando el arma y el árbol mientras los bichos seguían
	# exactamente iguales, así que el juego se volvía más fácil a medida
	# que avanzabas.
	var tier := get_difficulty_tier(level)

	return {
		"level": level,
		"chapter": chapter,
		"chapter_name": chapter_config.get("name", "Desconocido"),
		"background": chapter_config.get("background", ""),
		"spawn_rate": maxf(float(chapter_config.get("spawn_rate", 2.0)) * pow(TIER_SPAWN_MULT, tier), MIN_SPAWN_RATE),
		"enemy_speed_mult": float(chapter_config.get("enemy_speed_mult", 1.0)) * (1.0 + tier * TIER_SPEED_STEP),
		"enemy_health_bonus": tier * HP_PER_TIER,
		"difficulty_tier": tier,
		"time_limit": BOSS_TIME_LIMIT if is_boss_level(level) else 30,
		"enemy_types": get_available_enemies(level),
		"has_mystery_bug": has_mystery_bug(level) and not is_boss_level(level),
		"mystery_index": get_mystery_bug_index(level),
		"is_boss": is_boss_level(level),
		"boss_id": get_boss_id(level),
	}

## Los niveles múltiplo de BOSS_PERIOD son pelea de jefe.
func is_boss_level(level: int) -> bool:
	return level % BOSS_PERIOD == 0

## Qué jefe toca. Hay 10 arquetipos y se recorren en orden, repitiendo el
## ciclo a medida que se avanza (el nivel 5 es el jefe 1, el 10 el 2, ...,
## el 50 el 10, el 55 vuelve al 1 pero más fuerte, ver get_boss_config).
## Escalón de dificultad: sube uno cada DIFFICULTY_PERIOD niveles.
## El nivel 10 entra en el escalón 1, el 20 en el 2, y así.
func get_difficulty_tier(level: int) -> int:
	return int(level / DIFFICULTY_PERIOD)

## True en los niveles donde el escalón cambia (10, 20, 30...), para
## avisarle al jugador que los bichos se pusieron más duros.
func is_difficulty_step(level: int) -> bool:
	return level > 0 and level % DIFFICULTY_PERIOD == 0

func get_boss_id(level: int) -> int:
	if not is_boss_level(level):
		return 0
	var index := int(level / BOSS_PERIOD)
	return ((index - 1) % BossData.BOSS_COUNT) + 1

## Cuántas vueltas completas al roster llevamos: cada vuelta el jefe
## aparece con más vida y más rápido.
func get_boss_cycle(level: int) -> int:
	if not is_boss_level(level):
		return 0
	return int((int(level / BOSS_PERIOD) - 1) / BossData.BOSS_COUNT)

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
