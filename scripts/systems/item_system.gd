class_name ItemSystem
extends RefCounted

## Objetos pasivos: mejoras permanentes que se compran una vez y siguen
## haciendo efecto solas, sin equipar ni activar nada.
##
## Se diferencian del árbol de habilidades en para qué sirven: el árbol
## mejora cómo aplastás bichos comunes (daño, monedas, radio), y estos
## objetos están pensados para **aguantar las peleas de jefe** — vida
## extra, menos daño recibido, refuerzos más lentos.
##
## Cada objeto tiene niveles: comprarlo otra vez sube el nivel y el costo.
## GameManager guarda `{id: nivel}` en `items`.

const ITEMS := {
	"guantes_trabajo": {
		"display_name": "Guantes de Trabajo",
		"description": "+1 de daño por golpe en cada nivel",
		"icon": "res://assets/sprites/ui/item_guantes.png",
		"max_level": 3,
		"base_cost": 600,
		"cost_growth": 2.0,
	},
	"botiquin_abuela": {
		"display_name": "Botiquín de la Abuela",
		"description": "+400 de vida en las peleas de jefe",
		"icon": "res://assets/sprites/ui/item_botiquin.png",
		"max_level": 3,
		"base_cost": 500,
		"cost_growth": 2.0,
	},
	"delantal_reforzado": {
		"display_name": "Delantal Reforzado",
		"description": "Aguantás un golpe de cada 3 sin perder corazón",
		"icon": "res://assets/sprites/ui/item_delantal.png",
		"max_level": 2,
		"base_cost": 1050,
		"cost_growth": 2.2,
	},
	"repelente_casero": {
		"display_name": "Repelente Casero",
		"description": "Los refuerzos del jefe vienen más lentos",
		"icon": "res://assets/sprites/ui/item_repelente.png",
		"max_level": 3,
		"base_cost": 750,
		"cost_growth": 1.9,
	},
	"trebol_suerte": {
		"display_name": "Trébol de la Suerte",
		"description": "+10% de golpe crítico (daño doble)",
		"icon": "res://assets/sprites/ui/item_trebol.png",
		"max_level": 3,
		"base_cost": 900,
		"cost_growth": 2.0,
	},
	"frasco_monedas": {
		"display_name": "Frasco de Monedas",
		"display_name_short": "Frasco",
		"description": "+15% de monedas al terminar el nivel",
		"icon": "res://assets/sprites/ui/item_frasco.png",
		"max_level": 3,
		"base_cost": 700,
		"cost_growth": 1.9,
	},
	"reloj_arena": {
		"display_name": "Reloj de Arena",
		"description": "+5 segundos de nivel",
		"icon": "res://assets/sprites/ui/item_reloj.png",
		"max_level": 3,
		"base_cost": 800,
		"cost_growth": 2.0,
	},
	"lupa_abuelo": {
		"display_name": "Lupa del Abuelo",
		"description": "Más radio de golpe: errarle cuesta más",
		"icon": "res://assets/sprites/ui/item_lupa.png",
		"max_level": 3,
		"base_cost": 600,
		"cost_growth": 1.9,
	},
	# --- Poderes ACTIVOS: aparecen como botón en la pantalla de juego.
	#
	# Se pagan DOS veces: una para desbloquearlos y otra cada vez que los
	# usás (`use_cost`). Sin el costo por uso serían gratis para siempre
	# después de la primera compra y romperían el juego; así hay que
	# elegir cuándo vale la pena gastar la moneda.
	#
	# Subir de nivel un poder NO encarece el uso, lo hace más fuerte: lo
	# caro es el desbloqueo. ---
	"reloj_bolsillo": {
		"display_name": "Reloj de Bolsillo",
		"description": "Frena el tiempo unos segundos",
		"icon": "res://assets/sprites/ui/item_reloj_bolsillo.png",
		"max_level": 3,
		"base_cost": 1350,
		"cost_growth": 2.0,
		"use_cost": 60,
		"active": true,
		"label": "LENTO",
	},
	"campo_expansivo": {
		"display_name": "Campo Expansivo",
		"description": "El próximo golpe abarca muchísimo más",
		"icon": "res://assets/sprites/ui/item_campo.png",
		"max_level": 3,
		"base_cost": 2100,
		"cost_growth": 2.0,
		"use_cost": 90,
		"active": true,
		"label": "CAMPO",
	},
	"tormenta_rayos": {
		"display_name": "Tormenta de Rayos",
		"description": "Un rayo golpea a TODOS los insectos en pantalla",
		"icon": "res://assets/sprites/ui/item_rayo.png",
		"max_level": 3,
		"base_cost": 3300,
		"cost_growth": 2.1,
		"use_cost": 150,
		"active": true,
		"label": "RAYO",
	},
	"lanzallamas": {
		"display_name": "Lanzallamas de la Abuela",
		"description": "Quema todo lo que haya alrededor, y sigue quemando",
		"icon": "res://assets/sprites/ui/item_lanzallamas.png",
		"max_level": 3,
		"base_cost": 4800,
		"cost_growth": 2.2,
		"use_cost": 220,
		"active": true,
		"label": "FUEGO",
	},
	"botas_goma": {
		"display_name": "Botas de Goma",
		"description": "Te perdona fallos sin cortarte el combo",
		"icon": "res://assets/sprites/ui/item_botas.png",
		"max_level": 2,
		"base_cost": 1200,
		"cost_growth": 2.2,
	},
}

const DAMAGE_PER_LEVEL := 1
## Vida extra por nivel del botiquín. Sofía arranca con 1000, así que
## cada nivel es un 40% más de aguante.
const HP_PER_LEVEL := 400
## Nivel 1 bloquea 1 de cada 4 golpes; nivel 2, 1 de cada 3.
const BLOCK_EVERY := [0, 4, 3]
const MINION_SLOW_PER_LEVEL := 0.12
const CRIT_CHANCE_PER_LEVEL := 0.10
const CRIT_MULTIPLIER := 2
const COIN_BONUS_PER_LEVEL := 0.15
const SECONDS_PER_LEVEL := 5.0
const RADIUS_PER_LEVEL := 12.0
const FORGIVES_PER_LEVEL := 1

## Cámara lenta (Reloj de Bolsillo). Es el único objeto ACTIVABLE: los
## demás hacen efecto solos, este necesita que toques el botón.
const SLOWMO_SCALE := 0.45          # a cuánto baja la velocidad del juego
const SLOWMO_SECONDS := 3.0         # dura lo mismo en todos los niveles...
const SLOWMO_USES_PER_LEVEL := 1    # ...lo que sube con el nivel son los usos

## Campo Expansivo: cuánto multiplica el radio del próximo golpe.
const FIELD_RADIUS_MULT := 3.5
## Tormenta: daño a cada insecto de la pantalla, por nivel del objeto.
const STORM_DAMAGE_PER_LEVEL := 2
## Lanzallamas: radio, daño por tick y cuánto dura.
const FLAME_RADIUS := 260.0
const FLAME_DAMAGE := 1
const FLAME_TICK := 0.45
const FLAME_SECONDS := 3.5

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func get_all_item_ids() -> Array:
	return ITEMS.keys()

static func get_level(items: Dictionary, item_id: String) -> int:
	return int(items.get(item_id, 0))

static func get_max_level(item_id: String) -> int:
	return int(get_item(item_id).get("max_level", 1))

## Costo del PRÓXIMO nivel, o -1 si ya está al máximo.
static func get_cost(items: Dictionary, item_id: String) -> int:
	var data := get_item(item_id)
	if data.is_empty():
		return -1
	var level := get_level(items, item_id)
	if level >= int(data.get("max_level", 1)):
		return -1
	return int(round(float(data["base_cost"]) * pow(float(data["cost_growth"]), level)))

# --- Efectos. Todos leen el diccionario de niveles guardado. ---

static func get_bonus_damage(items: Dictionary) -> int:
	return get_level(items, "guantes_trabajo") * DAMAGE_PER_LEVEL

static func get_bonus_hp(items: Dictionary) -> int:
	return get_level(items, "botiquin_abuela") * HP_PER_LEVEL

## Cada cuántos golpes recibidos se bloquea uno. 0 = no bloquea ninguno.
static func get_block_every(items: Dictionary) -> int:
	var level := get_level(items, "delantal_reforzado")
	return BLOCK_EVERY[mini(level, BLOCK_EVERY.size() - 1)]

## Multiplicador de velocidad de los minions (1.0 = sin efecto).
static func get_minion_slow(items: Dictionary) -> float:
	var level := get_level(items, "repelente_casero")
	return maxf(1.0 - level * MINION_SLOW_PER_LEVEL, 0.5)

## Probabilidad de golpe crítico, de 0.0 a 1.0.
static func get_crit_chance(items: Dictionary) -> float:
	return get_level(items, "trebol_suerte") * CRIT_CHANCE_PER_LEVEL

## Tira el dado del crítico. Se resuelve acá y no en el llamador para que
## todos los que peguen usen la misma regla.
static func roll_crit(items: Dictionary) -> bool:
	var chance := get_crit_chance(items)
	return chance > 0.0 and randf() < chance

static func get_coin_bonus(items: Dictionary) -> float:
	return 1.0 + get_level(items, "frasco_monedas") * COIN_BONUS_PER_LEVEL

static func get_bonus_seconds(items: Dictionary) -> float:
	return get_level(items, "reloj_arena") * SECONDS_PER_LEVEL

static func get_bonus_radius(items: Dictionary) -> float:
	return get_level(items, "lupa_abuelo") * RADIUS_PER_LEVEL

## Cuántos fallos por nivel no te cortan el combo.
static func get_combo_forgives(items: Dictionary) -> int:
	return get_level(items, "botas_goma") * FORGIVES_PER_LEVEL

## Ids de los poderes activos que el jugador tiene comprados, en el orden
## en que están definidos. El HUD arma un botón por cada uno.
static func get_owned_powers(items: Dictionary) -> Array:
	var owned: Array = []
	for item_id in ITEMS.keys():
		if ITEMS[item_id].get("active", false) and get_level(items, item_id) > 0:
			owned.append(item_id)
	return owned

## Lo que cuesta ACTIVAR un poder, en monedas. No depende del nivel: lo
## que sube con el nivel es la potencia, no el precio de tirarlo.
static func get_power_use_cost(power_id: String) -> int:
	return int(get_item(power_id).get("use_cost", 0))

static func get_power_label(power_id: String) -> String:
	return str(get_item(power_id).get("label", "PODER"))
