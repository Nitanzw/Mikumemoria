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

## Cuánta vida extra por escalón de dificultad del nivel (cada 10 niveles).
const TIER_HEALTH_STEP := 0.18

## Daño que hace el jefe a Sofía, en puntos de vida (ella arranca con
## 1000). 200 son cinco golpes desde vida llena, que es exactamente lo
## que aguantaba cuando la vida eran 5 corazones.
##
## Antes el daño era fijo: un jefe del nivel 95 pegaba igual que el del
## nivel 5, así que con el botiquín comprado las peleas tardías dejaban
## de doler. Ahora sube con el escalón y con la vuelta al roster.
const BASE_DAMAGE := 200
const TIER_DAMAGE_STEP := 0.15
const CYCLE_DAMAGE_MULT := 1.25

## Umbrales de vida (fracción) donde el jefe cambia de fase.
const PHASE_2_HP := 0.6
const PHASE_3_HP := 0.3

## Segundos entre ataques, por fase. Bastante más agresivo que antes
## (2.2-3.2 / 1.5-2.4 / 0.9-1.6): con esos números el jefe se pasaba la
## mayor parte de la pelea paseando sin hacer nada.
const PHASE_COOLDOWNS := [
	Vector2(1.3, 2.0),
	Vector2(0.9, 1.4),
	Vector2(0.5, 0.9),
]

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
#
# --- Movimiento ---
#
# Antes todos los jefes patrullaban de izquierda a derecha a su
# velocidad, así que se peleaban todos igual. Ahora cada uno tiene su
# forma de moverse, que es la mitad de lo que lo hace difícil:
#
# patrol    : izquierda-derecha clásico.
# zigzag    : cruza en diagonal rebotando arriba y abajo.
# swoop     : baja en picada hacia Sofía y vuelve arriba.
# strafe    : ráfagas laterales rápidas con pausas cortas.
# blink     : desaparece y reaparece en otro lado.
# orbit     : gira en círculo alrededor del centro.
# pendulum  : va y viene acelerando en el medio, como un péndulo.
# erratic   : cambia de rumbo de golpe, impredecible.
# advance   : baja de a poco hacia Sofía; te obliga a apurarte.
#
# --- Fases ---
#
# Cada jefe tiene 3 fases por vida (100-60%, 60-30%, <30%). En cada
# fase ataca más seguido y suma una habilidad. Antes sorteaba una
# habilidad al azar cada 3-5s toda la pelea, y por eso se sentía plano.

const BOSSES := {
	1: {
		"name": "Hormiga Ladrona de Diamantes",
		"title": "la que te vacía los bolsillos",
		"sprite": "res://assets/sprites/insects/hormiga_ladrona.png",
		"health": 20,
		"speed": 175.0,
		"abilities": ["steal", "summon"],
		"movement": "strafe",
		"pattern": ["summon", "dash", "dash"],
		"phase_unlocks": ["", "dash", "haste"],
		"taunt": "¡Eh! ¡Esas monedas son mías!",
	},
	2: {
		"name": "Abejorro Piñata",
		"title": "el que explota en bichos",
		"sprite": "res://assets/sprites/insects/abejorro_pinata.png",
		"health": 26,
		"speed": 165.0,
		"abilities": ["summon", "haste"],
		"movement": "zigzag",
		"pattern": ["summon", "haste", "summon"],
		"phase_unlocks": ["", "spit", "dash"],
		"taunt": "Cada golpe le saca más bichos de adentro.",
	},
	3: {
		"name": "Mantis Cronómetro",
		"title": "la que te roba el tiempo",
		"sprite": "res://assets/sprites/insects/mantis_cronometro.png",
		"health": 30,
		"speed": 160.0,
		"abilities": ["haste", "dash", "summon"],
		"movement": "blink",
		"pattern": ["dash", "haste", "summon", "dash"],
		"phase_unlocks": ["", "spit", "split"],
		"taunt": "El reloj corre más rápido cuando ella quiere.",
	},
	4: {
		"name": "Escarabajo Radiactivo",
		"title": "el que no se deja tocar",
		"sprite": "res://assets/sprites/insects/escarabajo_radiactivo.png",
		"health": 36,
		"speed": 95.0,
		"abilities": ["shield", "spit"],
		"movement": "advance",
		"pattern": ["shield", "spit", "spit", "summon"],
		"phase_unlocks": ["", "spit", "enrage"],
		"taunt": "Ese caparazón aguanta. Pegale seguido, sin aflojar.",
	},
	5: {
		"name": "Lombriz Gigante",
		"title": "la que se hunde y aparece",
		"sprite": "res://assets/sprites/insects/lombriz_gigante.png",
		"health": 34,
		"speed": 85.0,
		"abilities": ["burrow", "heal", "summon"],
		"movement": "blink",
		"pattern": ["burrow", "summon", "heal", "burrow"],
		"phase_unlocks": ["", "spit", "haste"],
		"taunt": "Si la perdés de vista, se cura.",
	},
	6: {
		"name": "Mutagénesis Voladora",
		"title": "la que se multiplica",
		"sprite": "res://assets/sprites/insects/mutante_volador.png",
		"health": 32,
		"speed": 235.0,
		"abilities": ["split", "dash"],
		"movement": "erratic",
		"pattern": ["split", "dash", "dash"],
		"phase_unlocks": ["", "haste", "summon"],
		"taunt": "Solo una de todas esas es la de verdad.",
	},
	7: {
		"name": "Centella Blindada",
		"title": "la que carga y embiste",
		"sprite": "res://assets/sprites/insects/centella_blindada.png",
		"health": 42,
		"speed": 145.0,
		"abilities": ["shield", "dash", "haste"],
		"movement": "swoop",
		"pattern": ["shield", "dash", "haste", "dash"],
		"phase_unlocks": ["", "summon", "enrage"],
		"taunt": "Blindada y con ganas de chocarte.",
	},
	8: {
		"name": "Rayo Insecto",
		"title": "el que no vas a poder seguir",
		"sprite": "res://assets/sprites/insects/rayo_insecto.png",
		"health": 30,
		"speed": 400.0,
		"abilities": ["haste", "split", "enrage"],
		"movement": "erratic",
		"pattern": ["haste", "split", "dash"],
		"phase_unlocks": ["", "dash", "enrage"],
		"taunt": "Es rapidísimo. Anticipá, no persigas.",
	},
	9: {
		"name": "Coraza Antigua",
		"title": "el que trae guardias",
		"sprite": "res://assets/sprites/insects/coraza_antigua.png",
		"health": 54,
		"speed": 75.0,
		"abilities": ["summon", "shield", "heal"],
		"movement": "pendulum",
		"pattern": ["summon", "shield", "heal", "summon"],
		"phase_unlocks": ["", "spit", "dash"],
		"taunt": "No te va a dejar acercarte solo.",
	},
	10: {
		"name": "Reina Primordial",
		"title": "la que empezó todo",
		"sprite": "res://assets/sprites/insects/reina_primordial.png",
		"health": 68,
		"speed": 125.0,
		"abilities": ["summon", "shield", "spit", "heal", "enrage"],
		"movement": "orbit",
		"pattern": ["summon", "shield", "spit", "dash", "summon", "spit"],
		"phase_unlocks": ["", "split", "enrage"],
		"taunt": "Todo lo que aprendiste, junto. Suerte.",
	},
}

## Qué insectos invoca cada jefe como minions. Se eligen a propósito
## entre los tipos que ya sabe manejar el spawner normal.
const SUMMON_POOL := ["hormiga_obrera", "cucaracha_electrica", "mosca_pesada", "grillo_saltarin"]

## Devuelve la config de un jefe ya escalada según la vuelta al roster.
## cycle 0 son los primeros 10 jefes (niveles 5 a 50); cycle 1 son los
## siguientes 10 (55 a 100), con más vida y velocidad, y así.
## `tier` es el escalón de dificultad del nivel (LevelManager). Sin él,
## la vida del jefe queda fija mientras el daño del jugador crece hasta
## 7x entre el arma, el árbol y los guantes: la Reina Primordial se caía
## en 10 golpes con un equipo completo. Con el escalón, el jefe acompaña
## la progresión y la pelea sigue durando lo mismo.
static func get_boss_config(boss_id: int, cycle: int = 0, tier: int = 0) -> Dictionary:
	var base: Dictionary = BOSSES.get(boss_id, BOSSES[1])
	var config := base.duplicate(true)

	# `abilities` se arma con todo lo que el jefe realmente puede llegar a
	# hacer: lo declarado más lo que usa su patrón y lo que desbloquea por
	# fase. Si no, has_ability() miente — el robo, la curación y el enrage
	# se consultan por ahí y no se dispararían nunca para un jefe que los
	# tiene en el patrón pero no en la lista.
	var all_abilities: Array = config.get("abilities", []).duplicate()
	for ability in config.get("pattern", []):
		if ability != "" and not (ability in all_abilities):
			all_abilities.append(ability)
	for ability in config.get("phase_unlocks", []):
		if ability != "" and not (ability in all_abilities):
			all_abilities.append(ability)
	config["abilities"] = all_abilities

	var health := float(base["health"])
	var speed := float(base["speed"])
	if cycle > 0:
		health *= pow(CYCLE_HEALTH_MULT, cycle)
		speed *= pow(CYCLE_SPEED_MULT, cycle)
		config["name"] = "%s +%d" % [base["name"], cycle]

	health *= 1.0 + float(maxi(tier, 0)) * TIER_HEALTH_STEP
	config["health"] = int(round(health))
	config["speed"] = speed

	var damage := float(BASE_DAMAGE)
	damage *= 1.0 + float(maxi(tier, 0)) * TIER_DAMAGE_STEP
	damage *= pow(CYCLE_DAMAGE_MULT, maxi(cycle, 0))
	config["damage"] = int(round(damage))
	return config

static func has_ability(config: Dictionary, ability: String) -> bool:
	return ability in config.get("abilities", [])
