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

## Monedas de premio por la racha más larga del nivel.
##
## Era `combo_max * 5` SIN TOPE, y con eso una racha de 28 daba 140 de
## las 196 monedas del nivel: el 71% del ingreso salía de acá. El
## problema se agravó cuando subí los insectos en pantalla de 9 a 14 y el
## spawn de 2.0s a 1.1s — más bichos son rachas mucho más largas, y el
## bono estaba calibrado para las cortas de antes. Un tester llegó al
## nivel 7 con plata para el arma más cara.
##
## Ahora vale menos por punto y tiene tope: encadenar sigue conviniendo,
## pero deja de ser la fuente principal de ingresos.
const COINS_PER_COMBO := 2
const MAX_COMBO_COINS := 60

static func get_combo_bonus_coins(combo_max: int) -> int:
	return mini(combo_max * COINS_PER_COMBO, MAX_COMBO_COINS)
