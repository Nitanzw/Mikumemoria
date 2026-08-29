class_name Player
extends Node2D

## Control de Sofía: recibe el tap/click, golpea insectos en el área
## y activa "burla" (taunt) en los insectos cercanos cuando falla.

const INSECT_LAYER_MASK := 1 << 1  # capa 2, ver insect.tscn / mystery_bug.tscn
const BOSS_LAYER_MASK := 1 << 2    # capa 4, ver boss.tscn
const HITTABLE_MASK := INSECT_LAYER_MASK | BOSS_LAYER_MASK
const TAUNT_RADIUS := 300.0

## Avisa que el tap salió crítico, para que la escena lo muestre.
signal crit_landed(at: Vector2)

const HitEffectScene := preload("res://scenes/effects/hit_effect.tscn")
const WeaponStrikeScene := preload("res://scenes/effects/weapon_strike.tscn")

## Multiplicador de radio para el próximo golpe (Campo Expansivo).
## 1.0 = sin efecto. Lo setea game_level al activar el poder.
var next_hit_radius_mult: float = 1.0

var total_hits: int = 0
var total_misses: int = 0
var accuracy: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	var touch_event := event as InputEventScreenTouch
	if touch_event and touch_event.pressed:
		handle_tap(touch_event.position)

func handle_tap(tap_position: Vector2) -> void:
	var radius := GameManager.get_weapon_radius()
	var damage := GameManager.get_weapon_damage()

	# Campo Expansivo: agranda UN golpe y se gasta, acierte o no. Si solo
	# se gastara al acertar, se podría dejar cargado indefinidamente
	# tocando al vacío.
	if next_hit_radius_mult > 1.0:
		radius *= next_hit_radius_mult
		next_hit_radius_mult = 1.0

	# Trébol de la Suerte: el crítico se tira UNA vez por tap, no por
	# insecto. Si se tirara por insecto, un tap que agarra a cinco daría
	# cinco tiradas y el trébol valdría mucho más de lo que dice.
	var is_crit := ItemSystem.roll_crit(GameManager.items)
	if is_crit:
		damage *= ItemSystem.CRIT_MULTIPLIER

	spawn_hit_effect(tap_position, radius)
	spawn_weapon_strike(tap_position, radius)
	if is_crit:
		crit_landed.emit(tap_position)

	# Los proyectiles del jefe se revientan tocándolos: es la forma de
	# defenderse, y hace que la pelea no sea solo aguantar.
	var popped := _pop_projectiles_at(tap_position, radius)

	var results := _query_circle(tap_position, radius, HITTABLE_MASK)

	if results.is_empty():
		if popped:
			total_hits += 1
		else:
			total_misses += 1
			_trigger_nearby_taunts(tap_position)
	else:
		var already_hit: Dictionary = {}
		for result in results:
			var target = result.collider
			# El jefe y los insectos comunes son clases distintas, pero
			# los dos exponen take_damage(int).
			if target and (target is Insect or target is Boss) and not already_hit.has(target.get_instance_id()):
				already_hit[target.get_instance_id()] = true
				target.take_damage(damage)
		if not already_hit.is_empty():
			total_hits += 1
		else:
			total_misses += 1
			_trigger_nearby_taunts(tap_position)

	_update_accuracy()

func spawn_hit_effect(tap_position: Vector2, radius: float) -> void:
	var effect := HitEffectScene.instantiate() as HitEffect
	get_tree().current_scene.add_child(effect)
	effect.global_position = tap_position
	effect.play(radius)

## Muestra el arma equipada golpeando en el punto del tap. Se dispara en
## todos los taps (acierte o no), así el golpe se siente físico incluso
## cuando se falla.
func spawn_weapon_strike(tap_position: Vector2, radius: float) -> void:
	var strike := WeaponStrikeScene.instantiate() as WeaponStrike
	get_tree().current_scene.add_child(strike)
	strike.global_position = tap_position
	strike.play(GameManager.equipped_weapon, radius)

## Revienta los escupitajos del jefe que caigan dentro del radio del
## golpe. Devuelve true si reventó alguno.
func _pop_projectiles_at(tap_position: Vector2, radius: float) -> bool:
	var any := false
	for projectile in get_tree().get_nodes_in_group("boss_projectiles"):
		if is_instance_valid(projectile) and projectile.global_position.distance_to(tap_position) <= radius + 18.0:
			projectile.pop()
			any = true
	return any

func _query_circle(pos: Vector2, radius: float, mask: int) -> Array:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return space_state.intersect_shape(query)

func _trigger_nearby_taunts(tap_position: Vector2) -> void:
	var results := _query_circle(tap_position, TAUNT_RADIUS, INSECT_LAYER_MASK)
	for result in results:
		var insect := result.collider as Insect
		if insect and not insect.is_dead:
			insect.taunt()

func _update_accuracy() -> void:
	var total := total_hits + total_misses
	accuracy = (float(total_hits) / total) * 100.0 if total > 0 else 0.0

func reset_stats() -> void:
	total_hits = 0
	total_misses = 0
	accuracy = 0.0
