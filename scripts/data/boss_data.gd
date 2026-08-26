class_name BossData
extends RefCounted

## Los 10 arquetipos de jefe. Aparecen cada 5 niveles en orden, y al
## completar la vuelta vuelven a empezar más fuertes (ver
## LevelManager.get_boss_cycle).
##
## Cada jefe se define por sus **habilidades**, que es lo que lo hace
## distinto de un insecto con mucha vida. Las habilidades disponibles
## están abajo en ABILITIES; cada jefe usa 2 o 3.

const BOSS_COUNT := 10

## Cuánto sube la vida y la velocidad por cada vuelta completa al roster.
const CYCLE_HEALTH_MULT := 1.6
const CYCLE_SPEED_MULT := 1.12

# --- Habilidades ---
#
# summon    : invoca minions. Mientras haya minions vivos el jefe queda
#             escudado y NO recibe daño — hay que limpiar la pantalla
#             primero. Es la habilidad "que impida pegarle".
# burrow    : se hunde, queda invulnerable unos segundos y reaparece en
#             otro lado.
# shield    : levanta un escudo que aguanta N golpes seguidos; si dejás
#             de pegarle, se recupera.
# dash      : carga contra Sofía. Si llega, te saca una vida.
# spit      : escupe proyectiles hacia Sofía.
# steal     : cuando te pega, además te roba monedas.
# split     : se divide en copias; solo una es la real (las falsas
#             desaparecen de un golpe).
# heal      : si pasás demasiado tiempo sin pegarle, se cura.
# haste     : se acelera a sí mismo y a sus minions por un rato.
# enrage    : bajo el 30% de vida, se pone mucho más rápido y agresivo.

const BOSSES := {
	1: {
		"name": "Hormiga Ladrona de Diamantes",
		"title": "la que te vacía los bolsillos",
		"sprite": "res://assets/sprites/insects/hormiga_ladrona.png",
		"health": 18,
		"speed": 170.0,
		"abilities": ["steal", "summon"],
		"taunt": "¡Eh! ¡Esas monedas son mías!",
	},
	2: {
		"name": "Abejorro Piñata",
		"title": "el que explota en bichos",
		"sprite": "res://assets/sprites/insects/abejorro_pinata.png",
		"health": 22,
		"speed": 150.0,
		"abilities": ["summon", "haste"],
		"taunt": "Cada golpe le saca más bichos de adentro.",
	},
	3: {
		"name": "Mantis Cronómetro",
		"title": "la que te roba el tiempo",
		"sprite": "res://assets/sprites/insects/mantis_cronometro.png",
		"health": 26,
		"speed": 140.0,
		"abilities": ["haste", "dash", "summon"],
		"taunt": "El reloj corre más rápido cuando ella quiere.",
	},
	4: {
		"name": "Escarabajo Radiactivo",
		"title": "el que no se deja tocar",
		"sprite": "res://assets/sprites/insects/escarabajo_radiactivo.png",
		"health": 32,
		"speed": 80.0,
		"abilities": ["shield", "spit"],
		"taunt": "Ese caparazón aguanta. Pegale seguido, sin aflojar.",
	},
	5: {
		"name": "Lombriz Gigante",
		"title": "la que se hunde y aparece",
		"sprite": "res://assets/sprites/insects/lombriz_gigante.png",
		"health": 30,
		"speed": 70.0,
		"abilities": ["burrow", "heal", "summon"],
		"taunt": "Si la perdés de vista, se cura.",
	},
	6: {
		"name": "Mutagénesis Voladora",
		"title": "la que se multiplica",
		"sprite": "res://assets/sprites/insects/mutante_volador.png",
		"health": 28,
		"speed": 220.0,
		"abilities": ["split", "dash"],
		"taunt": "Solo una de todas esas es la de verdad.",
	},
	7: {
		"name": "Centella Blindada",
		"title": "la que carga y embiste",
		"sprite": "res://assets/sprites/insects/centella_blindada.png",
		"health": 38,
		"speed": 130.0,
		"abilities": ["shield", "dash", "haste"],
		"taunt": "Blindada y con ganas de chocarte.",
	},
	8: {
		"name": "Rayo Insecto",
		"title": "el que no vas a poder seguir",
		"sprite": "res://assets/sprites/insects/rayo_insecto.png",
		"health": 26,
		"speed": 380.0,
		"abilities": ["haste", "split", "enrage"],
		"taunt": "Es rapidísimo. Anticipá, no persigas.",
	},
	9: {
		"name": "Coraza Antigua",
		"title": "el que trae guardias",
		"sprite": "res://assets/sprites/insects/coraza_antigua.png",
		"health": 48,
		"speed": 60.0,
		"abilities": ["summon", "shield", "heal"],
		"taunt": "No te va a dejar acercarte solo.",
	},
	10: {
		"name": "Reina Primordial",
		"title": "la que empezó todo",
		"sprite": "res://assets/sprites/insects/reina_primordial.png",
		"health": 60,
		"speed": 110.0,
		"abilities": ["summon", "shield", "spit", "heal", "enrage"],
		"taunt": "Todo lo que aprendiste, junto. Suerte.",
	},
}

## Qué insectos invoca cada jefe como minions. Se eligen a propósito
## entre los tipos que ya sabe manejar el spawner normal.
const SUMMON_POOL := ["hormiga_obrera", "cucaracha_electrica", "mosca_pesada", "grillo_saltarin"]

## Devuelve la config de un jefe ya escalada según la vuelta al roster.
## cycle 0 son los primeros 10 jefes (niveles 5 a 50); cycle 1 son los
## siguientes 10 (55 a 100), con más vida y velocidad, y así.
static func get_boss_config(boss_id: int, cycle: int = 0) -> Dictionary:
	var base: Dictionary = BOSSES.get(boss_id, BOSSES[1])
	var config := base.duplicate(true)
	if cycle > 0:
		config["health"] = int(round(float(base["health"]) * pow(CYCLE_HEALTH_MULT, cycle)))
		config["speed"] = float(base["speed"]) * pow(CYCLE_SPEED_MULT, cycle)
		config["name"] = "%s +%d" % [base["name"], cycle]
	return config

static func has_ability(config: Dictionary, ability: String) -> bool:
	return ability in config.get("abilities", [])
