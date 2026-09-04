class_name WeaponSystem
extends RefCounted

## Base de datos de armas compartida por Player (equipar) y la Tienda
## (comprar/mostrar stats). Única fuente de verdad para evitar que
## ambos lados se desincronicen.
##
## Cada arma tiene 10 niveles de mejora y las armas forman una cadena:
## no se puede comprar la siguiente hasta tener la anterior al máximo.
## Antes eran 5 compras sueltas que se terminaban antes del nivel 40 y
## después no quedaba en qué gastar durante 960 niveles.
##
## GameManager guarda `{arma: nivel}` en `weapon_levels`; nivel 0 es
## "todavía bloqueada" y el Zapato arranca en 1.

const MAX_LEVEL := 10

## Daño = FIRST_DAMAGE + WEAPON_STEP por arma + LEVEL_STEP por nivel.
## Da una escalera pareja de 1 a 107 a lo largo de los 50 escalones, que
## es lo que hace falta para seguirle el ritmo a la vida de los insectos
## (+2 por escalón de dificultad, ver LevelManager.HP_PER_TIER).
const FIRST_DAMAGE := 1
const WEAPON_STEP := 22
const LEVEL_STEP := 2

## Costo del escalón global (arma * 10 + nivel). Lineal a propósito: el
## ingreso por nivel también crece lineal, así el ritmo de compra queda
## parejo en vez de acelerarse o frenarse.
const UPGRADE_BASE_COST := 300
const UPGRADE_STEP_COST := 190

const WEAPONS := {
	"zapato_viejo": {
		"order": 0,
		"display_name": "Zapato Viejo",
		"radius": 50.0,
		"sprite": "res://assets/sprites/weapons/zapato_viejo.png",
	},
	"chancla_goma": {
		"order": 1,
		"display_name": "Chancla de Goma",
		"radius": 60.0,
		"sprite": "res://assets/sprites/weapons/chancla_goma.png",
	},
	"matamoscas_metalico": {
		"order": 2,
		"display_name": "Matamoscas Metálico",
		"radius": 80.0,
		"sprite": "res://assets/sprites/weapons/matamoscas_metalico.png",
	},
	"sarten_hierro": {
		"order": 3,
		"display_name": "Sartén de Hierro",
		"radius": 70.0,
		"sprite": "res://assets/sprites/weapons/sarten_hierro.png",
	},
	"pala_electrificada": {
		"order": 4,
		"display_name": "Pala Electrificada",
		"radius": 90.0,
		"sprite": "res://assets/sprites/weapons/pala_electrificada.png",
	},
	# El arma de pago. No entra en la cadena de desbloqueo: no se compra
	# con monedas por más que subas el árbol entero, se consigue con la
	# compra dentro del juego y después se mejora con monedas como
	# cualquier otra. Se le da `damage_base` propio porque la fórmula de
	# la cadena la dejaría en 111, cinco puntos arriba de la mejor arma
	# normal, y por eso nadie la compraría.
	"zapato_de_oro": {
		"order": 5,
		"display_name": "Zapato de Oro de la Abuela",
		"radius": 110.0,
		"sprite": "res://assets/sprites/weapons/zapato_de_oro.png",
		"premium": true,
		"damage_base": 250,
		"damage_step": 12,
	},
}

## True si el arma sólo se consigue comprándola con plata de verdad.
static func is_premium(weapon_name: String) -> bool:
	return bool(get_weapon_data(weapon_name).get("premium", false))

static func get_weapon_data(weapon_name: String) -> Dictionary:
	return WEAPONS.get(weapon_name, WEAPONS["zapato_viejo"])

## En orden de cadena, que es como se muestran y se desbloquean.
static func get_all_weapon_names() -> Array:
	var names: Array = WEAPONS.keys()
	names.sort_custom(func(a, b): return int(WEAPONS[a]["order"]) < int(WEAPONS[b]["order"]))
	return names

static func get_order(weapon_name: String) -> int:
	return int(get_weapon_data(weapon_name).get("order", 0))

## El arma que hay que tener al máximo para desbloquear esta. Cadena
## vacía si es la primera.
static func get_previous(weapon_name: String) -> String:
	var order := get_order(weapon_name)
	if order <= 0:
		return ""
	for name in WEAPONS:
		if bool(WEAPONS[name].get("premium", false)):
			continue
		if int(WEAPONS[name]["order"]) == order - 1:
			return name
	return ""

static func get_level(levels: Dictionary, weapon_name: String) -> int:
	return int(levels.get(weapon_name, 0))

## Daño del arma en un nivel dado. Nivel 0 (bloqueada) devuelve el daño
## que tendría en el 1, para poder mostrarlo en la tienda antes de
## comprarla.
static func get_damage(weapon_name: String, level: int) -> int:
	var data := get_weapon_data(weapon_name)
	var nivel: int = maxi(level, 1) - 1
	if data.has("damage_base"):
		return int(data["damage_base"]) + int(data.get("damage_step", LEVEL_STEP)) * nivel
	return FIRST_DAMAGE + WEAPON_STEP * get_order(weapon_name) + LEVEL_STEP * nivel

static func get_radius(weapon_name: String) -> float:
	return float(get_weapon_data(weapon_name).get("radius", 50.0))

## Lo que cuesta llevar el arma de `level` a `level + 1`. -1 si ya está
## al máximo.
static func get_upgrade_cost(weapon_name: String, level: int) -> int:
	if level >= MAX_LEVEL:
		return -1
	var step := get_order(weapon_name) * MAX_LEVEL + level
	return UPGRADE_BASE_COST + UPGRADE_STEP_COST * step

## Se puede tocar (comprar o mejorar) sólo si la anterior está al máximo.
static func is_unlocked(levels: Dictionary, weapon_name: String) -> bool:
	# La cadena traba CONSEGUIR el arma, no seguir mejorándola. Si ya la
	# tenés (por ejemplo, viene de un guardado viejo migrado), podés
	# subirla igual: si no, quedaba mostrando "Nivel 1/10" y "Bloqueado"
	# a la vez, que no significa nada.
	if get_level(levels, weapon_name) > 0:
		return true
	# La de pago no se destraba jugando: o la compraste o no está.
	if is_premium(weapon_name):
		return false
	var previous := get_previous(weapon_name)
	if previous == "":
		return true
	return get_level(levels, previous) >= MAX_LEVEL

## Texto para la tienda cuando está bloqueada.
static func get_lock_reason(weapon_name: String) -> String:
	if is_premium(weapon_name):
		return "Se consigue en la tienda premium"
	var previous := get_previous(weapon_name)
	if previous == "":
		return ""
	return "Subí %s al nivel %d" % [get_weapon_data(previous)["display_name"], MAX_LEVEL]
