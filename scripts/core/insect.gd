class_name Insect
extends CharacterBody2D

## Lógica de un insecto común. Los datos de cada tipo viven en INSECT_DATA
## para que el spawner también pueda consultarlos sin instanciar la escena.

const INSECT_DATA := {
	"hormiga_obrera": {"speed": 100.0, "health": 1, "points": 50, "coin_reward": 10, "sprite": "res://assets/sprites/insects/hormiga_obrera.png"},
	"cucaracha_electrica": {"speed": 200.0, "health": 1, "points": 75, "coin_reward": 15, "sprite": "res://assets/sprites/insects/cucaracha_electrica.png"},
	"escarabajo_blindado": {"speed": 50.0, "health": 3, "points": 150, "coin_reward": 30, "sprite": "res://assets/sprites/insects/escarabajo_blindado.png"},
	"mosca_pesada": {"speed": 150.0, "health": 1, "points": 100, "coin_reward": 20, "sprite": "res://assets/sprites/insects/mosca_pesada.png"},
	"grillo_saltarin": {"speed": 120.0, "health": 1, "points": 80, "coin_reward": 16, "sprite": "res://assets/sprites/insects/grillo_saltarin.png"},
}

const WANDER_MIN := 0.6
const WANDER_MAX := 1.4
const LIFETIME := 7.0
const SCREEN_MARGIN := 100.0

@export var insect_type: String = "hormiga_obrera"
@export var speed_mult: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
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

func _ready() -> void:
	add_to_group("insects")
	initialize_by_type()
	randomize_direction()

func initialize_by_type() -> void:
	var data: Dictionary = INSECT_DATA.get(insect_type, INSECT_DATA["hormiga_obrera"])
	base_speed = float(data["speed"]) * speed_mult
	speed = base_speed
	health = int(data["health"])
	current_health = health
	points = int(data["points"])
	coin_reward = int(data["coin_reward"])
	if sprite and data.has("sprite") and ResourceLoader.exists(data["sprite"]):
		sprite.texture = load(data["sprite"])

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

	play_death_animation()
	GameManager.add_coins(coin_reward)
	GameManager.on_insect_hit(self)

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
