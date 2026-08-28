class_name ItemSystem
extends RefCounted

## Objetos pasivos: mejoras permanentes que se compran una vez y siguen
## haciendo efecto solas, sin equipar ni activar nada.
##
## Se diferencian del árbol de habilidades en para qué sirven: el árbol
## mejora cómo aplastás bichos comunes (daño, monedas, radio), y estos
## objetos están pensados para **aguantar las peleas de jefe** — corazones
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
		"base_cost": 400,
		"cost_growth": 2.0,
	},
	"botiquin_abuela": {
		"display_name": "Botiquín de la Abuela",
		"description": "+2 corazones en las peleas de jefe",
		"icon": "res://assets/sprites/ui/item_botiquin.png",
		"max_level": 3,
		"base_cost": 350,
		"cost_growth": 2.0,
	},
	"delantal_reforzado": {
		"display_name": "Delantal Reforzado",
		"description": "Aguantás un golpe de cada 3 sin perder corazón",
		"icon": "res://assets/sprites/ui/item_delantal.png",
		"max_level": 2,
		"base_cost": 700,
		"cost_growth": 2.2,
	},
	"repelente_casero": {
		"display_name": "Repelente Casero",
		"description": "Los refuerzos del jefe vienen más lentos",
		"icon": "res://assets/sprites/ui/item_repelente.png",
		"max_level": 3,
		"base_cost": 500,
		"cost_growth": 1.9,
	},
}

const DAMAGE_PER_LEVEL := 1
const HEARTS_PER_LEVEL := 2
## Nivel 1 bloquea 1 de cada 4 golpes; nivel 2, 1 de cada 3.
const BLOCK_EVERY := [0, 4, 3]
const MINION_SLOW_PER_LEVEL := 0.12

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

static func get_bonus_hearts(items: Dictionary) -> int:
	return get_level(items, "botiquin_abuela") * HEARTS_PER_LEVEL

## Cada cuántos golpes recibidos se bloquea uno. 0 = no bloquea ninguno.
static func get_block_every(items: Dictionary) -> int:
	var level := get_level(items, "delantal_reforzado")
	return BLOCK_EVERY[mini(level, BLOCK_EVERY.size() - 1)]

## Multiplicador de velocidad de los minions (1.0 = sin efecto).
static func get_minion_slow(items: Dictionary) -> float:
	var level := get_level(items, "repelente_casero")
	return maxf(1.0 - level * MINION_SLOW_PER_LEVEL, 0.5)
