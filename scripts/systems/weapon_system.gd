class_name WeaponSystem
extends RefCounted

## Base de datos de armas compartida por Player (equipar) y la Tienda
## (comprar/mostrar stats). Única fuente de verdad para evitar que
## ambos lados se desincronicen.

const WEAPONS := {
	"zapato_viejo": {
		"display_name": "Zapato Viejo",
		"damage": 1,
		"radius": 50.0,
		"price": 0,
		"sprite": "res://assets/sprites/weapons/zapato_viejo.png",
	},
	"chancla_goma": {
		"display_name": "Chancla de Goma",
		"damage": 2,
		"radius": 60.0,
		"price": 350,
		"sprite": "res://assets/sprites/weapons/chancla_goma.png",
	},
	"matamoscas_metalico": {
		"display_name": "Matamoscas Metálico",
		"damage": 3,
		"radius": 80.0,
		"price": 900,
		"sprite": "res://assets/sprites/weapons/matamoscas_metalico.png",
	},
	"sarten_hierro": {
		"display_name": "Sartén de Hierro",
		"damage": 5,
		"radius": 70.0,
		"price": 1800,
		"sprite": "res://assets/sprites/weapons/sarten_hierro.png",
	},
	"pala_electrificada": {
		"display_name": "Pala Electrificada",
		"damage": 8,
		"radius": 90.0,
		"price": 3200,
		"sprite": "res://assets/sprites/weapons/pala_electrificada.png",
	},
}

static func get_weapon_data(weapon_name: String) -> Dictionary:
	return WEAPONS.get(weapon_name, WEAPONS["zapato_viejo"])

static func get_all_weapon_names() -> Array:
	return WEAPONS.keys()

static func get_price(weapon_name: String) -> int:
	return int(get_weapon_data(weapon_name).get("price", 0))
