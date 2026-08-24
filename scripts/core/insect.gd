class_name Insect
extends CharacterBody2D

## Lógica de un insecto común. Los datos de cada tipo viven en INSECT_DATA
## para que el spawner también pueda consultarlos sin instanciar la escena.

const INSECT_DATA := {
	"hormiga_obrera": {"speed": 100.0, "health": 1, "points": 50, "coin_reward": 10, "sprite": "res://assets/sprites/insects/hormiga_obrera.png", "walk_frames": [
		"res://assets/sprites/insects/hormiga_obrera_walk_0.png",
		"res://assets/sprites/insects/hormiga_obrera_walk_1.png",
		"res://assets/sprites/insects/hormiga_obrera_walk_2.png",
		"res://assets/sprites/insects/hormiga_obrera_walk_3.png",
	]},
	"cucaracha_electrica": {"speed": 200.0, "health": 1, "points": 75, "coin_reward": 15, "sprite": "res://assets/sprites/insects/cucaracha_electrica.png", "walk_frames": [
		"res://assets/sprites/insects/cucaracha_electrica_walk_0.png",
		"res://assets/sprites/insects/cucaracha_electrica_walk_1.png",
		"res://assets/sprites/insects/cucaracha_electrica_walk_2.png",
		"res://assets/sprites/insects/cucaracha_electrica_walk_3.png",
	]},
	"escarabajo_blindado": {"speed": 50.0, "health": 3, "points": 150, "coin_reward": 30, "sprite": "res://assets/sprites/insects/escarabajo_blindado.png", "walk_frames": [
		"res://assets/sprites/insects/escarabajo_blindado_walk_0.png",
		"res://assets/sprites/insects/escarabajo_blindado_walk_1.png",
		"res://assets/sprites/insects/escarabajo_blindado_walk_2.png",
		"res://assets/sprites/insects/escarabajo_blindado_walk_3.png",
	]},
	"mosca_pesada": {"speed": 150.0, "health": 1, "points": 100, "coin_reward": 20, "sprite": "res://assets/sprites/insects/mosca_pesada.png", "walk_frames": [
		"res://assets/sprites/insects/mosca_pesada_walk_0.png",
		"res://assets/sprites/insects/mosca_pesada_walk_1.png",
		"res://assets/sprites/insects/mosca_pesada_walk_2.png",
		"res://assets/sprites/insects/mosca_pesada_walk_3.png",
	]},
	"grillo_saltarin": {"speed": 120.0, "health": 1, "points": 80, "coin_reward": 16, "sprite": "res://assets/sprites/insects/grillo_saltarin.png", "walk_frames": [
		"res://assets/sprites/insects/grillo_saltarin_walk_0.png",
		"res://assets/sprites/insects/grillo_saltarin_walk_1.png",
		"res://assets/sprites/insects/grillo_saltarin_walk_2.png",
		"res://assets/sprites/insects/grillo_saltarin_walk_3.png",
	]},
}

const WANDER_MIN := 0.6
const WANDER_MAX := 1.4
const LIFETIME := 7.0
const SCREEN_MARGIN := 100.0

const SplatEffectScene := preload("res://scenes/effects/splat_effect.tscn")

## Color de la salpicadura por tipo de insecto (se usa al aplastarlo).
## Si un tipo no está acá, cae en el verde genérico de SplatEffect.
const SPLAT_COLORS := {
	"hormiga_obrera": Color(0.42, 0.26, 0.13),
	"cucaracha_electrica": Color(0.88, 0.78, 0.20),
	"escarabajo_blindado": Color(0.34, 0.44, 0.55),
	"mosca_pesada": Color(0.30, 0.30, 0.33),
	"grillo_saltarin": Color(0.35, 0.65, 0.25),
}

@export var insect_type: String = "hormiga_obrera"
@export var speed_mult: float = 1.0

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var speed: float = 100.0
var base_speed: float = 100.0
var health: int = 1
var points: int = 50
var coin_reward: int = 10

var direction: Vector2 = Vector2.RIGHT
var current_health: int = 1
var is_dead: bool = false
var can_be_hit: bool = true

var is_taunting: bool = false
var taunt_timer: float = 0.0
var wander_timer: float = 1.0
var lifetime_timer: float = LIFETIME

# Balanceo + rebote que se suma ENCIMA del ciclo de caminata real, para
# que el bicho no se vea rígido al desplazarse. Fase aleatoria para que
# no todos se muevan en sincro. La velocidad de la oscilación va atada a
# la velocidad real, así un insecto en "burla" (más rápido) se ve más
# agitado.
var _wiggle_phase: float = randf() * TAU
const WIGGLE_ROTATION := 0.14
const WIGGLE_BOB_PX := 3.0

func _ready() -> void:
	add_to_group("insects")
	initialize_by_type()
	randomize_direction()

func _process(delta: float) -> void:
	if is_dead or not sprite:
		return
	var wiggle_speed: float = 6.0 * clamp(speed / max(base_speed, 1.0), 0.5, 2.5)
	_wiggle_phase += delta * wiggle_speed
	sprite.rotation = sin(_wiggle_phase) * WIGGLE_ROTATION
	sprite.position.y = -absf(sin(_wiggle_phase)) * WIGGLE_BOB_PX

func initialize_by_type() -> void:
	var data: Dictionary = INSECT_DATA.get(insect_type, INSECT_DATA["hormiga_obrera"])
	base_speed = float(data["speed"]) * speed_mult
	speed = base_speed
	health = int(data["health"])
	current_health = health
	points = int(data["points"])
	coin_reward = int(data["coin_reward"])
	_apply_sprite_data(sprite, data)

## Arma un SpriteFrames a partir de la config del tipo de insecto: si trae
## "walk_frames" (lista de rutas), arma un ciclo de caminata animado; si
## no, cae en un único frame estático desde "sprite" (mismo resultado
## visual que un Sprite2D de toda la vida, pero con el mismo tipo de nodo
## para todos los insectos).
func _apply_sprite_data(target: AnimatedSprite2D, data: Dictionary) -> void:
	if not target:
		return

	var walk_frames: Array = data.get("walk_frames", [])
	if not walk_frames.is_empty():
		var frames := SpriteFrames.new()
		frames.add_animation("walk")
		frames.set_animation_loop("walk", true)
		frames.set_animation_speed("walk", 8.0)
		for path in walk_frames:
			if ResourceLoader.exists(path):
				frames.add_frame("walk", load(path))
		target.sprite_frames = frames
		target.play("walk")
		return

	var sprite_path: String = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_apply_static_texture(target, load(sprite_path))

func _apply_static_texture(target: AnimatedSprite2D, texture: Texture2D) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.add_frame("default", texture)
	target.sprite_frames = frames
	target.play("default")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_taunting:
		if taunt_timer > 0.0:
			taunt_timer -= delta
			if taunt_timer <= 0.0:
				is_taunting = false
				speed = base_speed
	else:
		lifetime_timer -= delta
		wander_timer -= delta
		if wander_timer <= 0.0:
			randomize_direction()
			wander_timer = randf_range(WANDER_MIN, WANDER_MAX)
		if lifetime_timer <= 0.0:
			speed = base_speed * 1.8  # huye rápido cuando se le acaba el tiempo

	velocity = direction * speed
	move_and_slide()

	var viewport_size := get_viewport_rect().size
	if global_position.x > viewport_size.x + SCREEN_MARGIN or \
			global_position.x < -SCREEN_MARGIN or \
			global_position.y > viewport_size.y + SCREEN_MARGIN or \
			global_position.y < -SCREEN_MARGIN:
		queue_free()

func take_damage(damage: int = 1) -> void:
	if not can_be_hit or is_dead:
		return

	current_health -= damage

	if current_health <= 0:
		die()
	else:
		play_hit_animation()
		GameManager.on_insect_hit(self)

func die() -> void:
	is_dead = true
	can_be_hit = false

	spawn_splat()
	AudioManager.play_sfx("splat")
	play_death_animation()
	GameManager.add_coins(coin_reward)
	GameManager.on_insect_hit(self)

## Salpicadura en el lugar donde murió. Se agrega a la escena actual (no
## como hijo) porque el insecto se libera enseguida y se llevaría el
## efecto con él.
func spawn_splat() -> void:
	var splat := SplatEffectScene.instantiate() as SplatEffect
	var parent := get_tree().current_scene
	if not parent:
		return
	parent.add_child(splat)
	splat.global_position = global_position
	splat.play(SPLAT_COLORS.get(insect_type, Color(0.45, 0.62, 0.22)), 1.6)

func play_hit_animation() -> void:
	if animation_player and animation_player.has_animation("hit"):
		animation_player.play("hit")
		return

	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

func play_death_animation() -> void:
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
	elif sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", sprite.scale * 1.3, 0.15)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)

	await get_tree().create_timer(0.3).timeout
	queue_free()

func taunt() -> void:
	if is_taunting or is_dead:
		return

	is_taunting = true
	taunt_timer = 1.0
	speed = base_speed * 2.0

	if animation_player and animation_player.has_animation("taunt"):
		animation_player.play("taunt")

	GameManager.on_insect_missed()

func randomize_direction() -> void:
	direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	if sprite:
		sprite.flip_h = direction.x < 0
