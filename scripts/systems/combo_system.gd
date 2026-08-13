class_name ComboSystem
extends RefCounted

## Calcula el multiplicador de puntos/monedas según el combo actual.
## No guarda estado: GameManager es dueño de `combo_hits` / `combo_max`.

const MULTIPLIER_STEP := 0.1  # +10% cada 5 golpes seguidos
const HITS_PER_STEP := 5
const MAX_MULTIPLIER := 3.0

static func get_multiplier(combo_hits: int) -> float:
	var steps := int(combo_hits / HITS_PER_STEP)
	return min(1.0 + steps * MULTIPLIER_STEP, MAX_MULTIPLIER)

static func get_combo_bonus_coins(combo_max: int) -> int:
	return combo_max * 5
