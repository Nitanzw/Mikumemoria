class_name Boss
extends CharacterBody2D

## Jefe de nivel. A diferencia de un insecto común no muere de un golpe:
## tiene barra de vida y un ciclo de habilidades que lo hacen distinto de
## "un bicho con mucha vida".
##
## Cómo hace daño a Sofía: con `dash` (se tira encima) y con `spit`
## (proyectiles). Los minions invocados también pegan si llegan abajo,
## pero eso lo maneja la escena de pelea, no el jefe.

signal health_changed(current: int, maximum: int)
signal shield_changed(active: bool)
signal died
signal wants_summon(count: int)
signal wants_projectile(from: Vector2)
signal hit_player(damage: int)
signal stole_coins(amount: int)
signal ability_announced(text: String)

const EDGE_MARGIN := 90.0
const TOP_MARGIN := 220.0     # no baja de acá salvo cuando carga
const BOB_SPEED := 1.8
const BOB_PIXELS := 12.0

const SHIELD_HITS := 4        # golpes para romper el escudo de `shield`
const SHIELD_RECOVER_TIME := 2.5
const BURROW_TIME := 2.2
const DASH_WINDUP := 0.7
const DASH_SPEED := 900.0
const HEAL_IDLE_TIME := 5.0   # sin recibir golpes durante esto -> se cura
const HEAL_AMOUNT := 2
const ENRAGE_THRESHOLD := 0.3
const STEAL_AMOUNT := 25

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var config: Dictionary = {}
var max_health: int = 20
var current_health: int = 20
var base_speed: float = 120.0
var speed: float = 120.0

var is_dead: bool = false
var is_decoy: bool = false        # las copias de `split` mueren de un golpe

# Estados que bloquean el daño
var shield_active: bool = false
var shield_hits_left: int = 0
var is_burrowed: bool = false
var minions_alive: int = 0        # mientras haya, el jefe está escudado

var is_enraged: bool = false
var _direction := Vector2.RIGHT
var _bob_phase: float = 0.0
var _ability_timer: float = 0.0
var _time_since_hit: float = 0.0
var _dashing: bool = false
var _dash_target := Vector2.ZERO
var _player_position := Vector2.ZERO

func setup(boss_config: Dictionary) -> void:
	config = boss_config
	max_health = int(config.get("health", 20))
	current_health = max_health
	base_speed = float(config.get("speed", 120.0))
	speed = base_speed

	var path: String = config.get("sprite", "")
	if sprite and path != "" and ResourceLoader.exists(path):
		sprite.texture = load(path)

	# El jefe se ve claramente más grande que un insecto normal.
	if sprite:
		sprite.scale = Vector2(1.7, 1.7)

	_ability_timer = randf_range(2.0, 3.5)
	health_changed.emit(current_health, max_health)

func set_player_position(pos: Vector2) -> void:
	_player_position = pos

func _ready() -> void:
	add_to_group("bosses")
	_direction = Vector2(randf_range(-1.0, 1.0), 0.0).normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT

func _process(delta: float) -> void:
	if is_dead or not sprite:
		return
	_bob_phase += delta * BOB_SPEED
	sprite.position.y = sin(_bob_phase) * BOB_PIXELS
	# Mientras no puede recibir daño se muestra semitransparente y
	# parpadeando, para que se entienda que pegarle ahí no sirve.
	var invulnerable := _is_invulnerable()
	var target_alpha: float = 0.45 if invulnerable else 1.0
	sprite.modulate.a = lerpf(sprite.modulate.a, target_alpha, delta * 6.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_time_since_hit += delta

	if is_burrowed:
		return

	if _dashing:
		_process_dash(delta)
	else:
		_process_patrol(delta)

	_process_abilities(delta)

func _process_patrol(delta: float) -> void:
	var view := get_viewport_rect().size
	global_position.x += _direction.x * speed * delta
	if global_position.x < EDGE_MARGIN:
		global_position.x = EDGE_MARGIN
		_direction.x = 1.0
	elif global_position.x > view.x - EDGE_MARGIN:
		global_position.x = view.x - EDGE_MARGIN
		_direction.x = -1.0
	global_position.y = lerpf(global_position.y, TOP_MARGIN, delta * 2.0)

func _process_dash(delta: float) -> void:
	var to_target := _dash_target - global_position
	if to_target.length() < 30.0:
		_end_dash()
		return
	global_position += to_target.normalized() * DASH_SPEED * delta
	# Si alcanza a Sofía, le saca una vida.
	if global_position.distance_to(_player_position) < 90.0:
		hit_player.emit(1)
		if BossData.has_ability(config, "steal"):
			stole_coins.emit(STEAL_AMOUNT)
		_end_dash()

func _end_dash() -> void:
	_dashing = false
	speed = base_speed * (1.5 if is_enraged else 1.0)

# --- Habilidades ---

func _process_abilities(delta: float) -> void:
	_ability_timer -= delta
	if _ability_timer > 0.0:
		return
	_ability_timer = randf_range(3.0, 5.5) * (0.6 if is_enraged else 1.0)
	_use_random_ability()

	# `heal` no entra en el sorteo: se dispara sola si la dejás tranquila.
	if BossData.has_ability(config, "heal") and _time_since_hit > HEAL_IDLE_TIME:
		_heal()

func _use_random_ability() -> void:
	var options: Array = []
	for ability in config.get("abilities", []):
		match ability:
			"summon":
				if minions_alive == 0:
					options.append(ability)
			"shield":
				if not shield_active:
					options.append(ability)
			"burrow", "dash", "spit", "haste", "split":
				options.append(ability)
	if options.is_empty():
		return

	match options[randi() % options.size()]:
		"summon": _summon()
		"shield": _raise_shield()
		"burrow": _burrow()
		"dash": _start_dash()
		"spit": _spit()
		"haste": _haste()
		"split": _split()

func _summon() -> void:
	var count := 3 if not is_enraged else 5
	minions_alive = count
	shield_changed.emit(true)
	ability_announced.emit("¡Invoca refuerzos! No podés tocarlo hasta limpiarlos")
	wants_summon.emit(count)

## La escena de pelea avisa cuando muere un minion.
func on_minion_died() -> void:
	minions_alive = maxi(minions_alive - 1, 0)
	if minions_alive == 0:
		shield_changed.emit(false)
		ability_announced.emit("¡Quedó sin guardia! Pegale ahora")

func _raise_shield() -> void:
	shield_active = true
	shield_hits_left = SHIELD_HITS
	shield_changed.emit(true)
	ability_announced.emit("¡Escudo! Golpes seguidos para romperlo")

func _burrow() -> void:
	is_burrowed = true
	ability_announced.emit("¡Se enterró!")
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.3)
	await get_tree().create_timer(BURROW_TIME).timeout
	if is_dead:
		return
	# Reaparece en otro lado
	var view := get_viewport_rect().size
	global_position.x = randf_range(EDGE_MARGIN, view.x - EDGE_MARGIN)
	is_burrowed = false
	var out := create_tween()
	out.tween_property(sprite, "scale", Vector2(1.7, 1.7), 0.3)

func _start_dash() -> void:
	ability_announced.emit("¡Se prepara para embestir!")
	# Aviso previo: se agranda un toque antes de salir disparado, para que
	# el golpe sea esquivable y no se sienta injusto.
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), DASH_WINDUP * 0.5)
	tween.tween_property(sprite, "scale", Vector2(1.7, 1.7), DASH_WINDUP * 0.5)
	await get_tree().create_timer(DASH_WINDUP).timeout
	if is_dead or is_burrowed:
		return
	_dash_target = _player_position
	_dashing = true

func _spit() -> void:
	ability_announced.emit("¡Escupe!")
	wants_projectile.emit(global_position)

func _haste() -> void:
	ability_announced.emit("¡Se acelera!")
	speed = base_speed * 2.0
	await get_tree().create_timer(3.0).timeout
	if not is_dead and not _dashing:
		speed = base_speed * (1.5 if is_enraged else 1.0)

func _split() -> void:
	ability_announced.emit("¡Se dividió! Solo una es la real")
	wants_summon.emit(0)  # 0 = la escena entiende que son copias, no minions

func _heal() -> void:
	if current_health >= max_health:
		return
	current_health = mini(current_health + HEAL_AMOUNT, max_health)
	health_changed.emit(current_health, max_health)
	ability_announced.emit("¡Se está curando! No le des respiro")
	_time_since_hit = 0.0

# --- Daño ---

## No recibe daño mientras esté enterrado o protegido (por minions o por
## escudo). Es lo que hace que las habilidades importen.
func _is_invulnerable() -> bool:
	return is_burrowed or minions_alive > 0 or shield_active

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	if is_decoy:
		# Las copias de `split` se disipan de un solo golpe.
		queue_free()
		return

	_time_since_hit = 0.0

	if is_burrowed:
		return

	if minions_alive > 0:
		_flash(Color(0.6, 0.6, 1.0))
		ability_announced.emit("¡Limpiá los refuerzos primero!")
		return

	if shield_active:
		shield_hits_left -= 1
		_flash(Color(0.5, 0.8, 1.0))
		if shield_hits_left <= 0:
			shield_active = false
			shield_changed.emit(false)
			ability_announced.emit("¡Escudo roto!")
		return

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_flash(Color(2.0, 1.4, 1.4))

	if not is_enraged and BossData.has_ability(config, "enrage") \
			and float(current_health) / float(max_health) <= ENRAGE_THRESHOLD:
		_enrage()

	if current_health <= 0:
		die()

func _enrage() -> void:
	is_enraged = true
	speed = base_speed * 1.5
	ability_announced.emit("¡Se enfureció!")
	if sprite:
		sprite.modulate = Color(1.4, 0.8, 0.8)

func _flash(color: Color) -> void:
	if not sprite:
		return
	var original := sprite.modulate
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", color, 0.05)
	tween.tween_property(sprite, "modulate", original, 0.12)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	died.emit()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(2.4, 2.4), 0.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "rotation", 1.2, 0.5)
	await get_tree().create_timer(0.6).timeout
	queue_free()

## Recuadro donde se puede tocar al jefe (lo usa la escena para saber si
## un tap le pegó, sin depender de física).
func get_hit_radius() -> float:
	return 95.0
