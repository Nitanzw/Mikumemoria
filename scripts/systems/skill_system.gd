class_name SkillSystem
extends RefCounted

## Árbol de habilidades con 3 ramas. GameManager guarda el progreso
## (tier comprado por rama) en su diccionario `skill_tree` y usa esta
## clase solo para consultar costos y efectos.

const MAX_TIER := 5

const BRANCHES := {
	"fuerza": {
		"display_name": "Fuerza",
		"description": "Más daño por golpe",
		"base_cost": 100,
		"cost_growth": 1.6,
	},
	"fortuna": {
		"display_name": "Fortuna",
		"description": "Más monedas por insecto",
		"base_cost": 120,
		"cost_growth": 1.6,
	},
	"precision": {
		"display_name": "Precisión",
		"description": "Mayor radio de golpe",
		"base_cost": 90,
		"cost_growth": 1.6,
	},
}

func get_tier(skill_tree: Dictionary, branch: String) -> int:
	return int(skill_tree.get(branch, 0))

func get_cost_for_next_tier(skill_tree: Dictionary, branch: String) -> int:
	var branch_data: Dictionary = BRANCHES.get(branch, {})
	if branch_data.is_empty():
		return -1

	var current_tier := get_tier(skill_tree, branch)
	if current_tier >= MAX_TIER:
		return -1

	var base: int = branch_data["base_cost"]
	var growth: float = branch_data["cost_growth"]
	return int(round(base * pow(growth, current_tier)))

func can_purchase(skill_tree: Dictionary, branch: String, coins: int) -> bool:
	var cost := get_cost_for_next_tier(skill_tree, branch)
	return cost > 0 and coins >= cost

func purchase(skill_tree: Dictionary, branch: String) -> Dictionary:
	var current_tier := get_tier(skill_tree, branch)
	skill_tree[branch] = current_tier + 1
	return skill_tree

## Daño PLANO, no multiplicador. Cuando las armas hacían 1 o 2 de daño un
## x2 era un empujón chico; ahora que la escalera va de 1 a 107 el mismo
## x2 regalaba +107 de daño por 4.800 monedas y dejaba sin sentido las
## 50 mejoras de arma. Sumado queda como lo que es: un empujón temprano.
const DAMAGE_PER_TIER := 3

func get_bonus_damage(skill_tree: Dictionary) -> int:
	return get_tier(skill_tree, "fuerza") * DAMAGE_PER_TIER

func get_coin_multiplier(skill_tree: Dictionary) -> float:
	return 1.0 + get_tier(skill_tree, "fortuna") * 0.15

func get_radius_bonus(skill_tree: Dictionary) -> float:
	return get_tier(skill_tree, "precision") * 8.0
