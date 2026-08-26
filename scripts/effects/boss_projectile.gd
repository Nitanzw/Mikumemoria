class_name BossProjectile
extends Area2D

## Escupitajo del jefe. Viaja hacia donde estaba Sofía al dispararse (no
## la persigue: así se puede esquivar) y se puede destruir tocándolo.

signal reached_player

const SPEED := 320.0
const LIFETIME := 6.0

var _direction := Vector2.DOWN
var _life: float = LIFETIME
var _radius: float = 18.0
var _phase: float = 0.0

func _ready() -> void:
	add_to_group("boss_projectiles")

func launch(from: Vector2, towards: Vector2) -> void:
	global_position = from
	_direction = (towards - from).normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.DOWN

func _process(delta: float) -> void:
	global_position += _direction * SPEED * delta
	_phase += delta * 12.0
	_life -= delta
	queue_redraw()

	if _life <= 0.0:
		queue_free()
		return

	var view := get_viewport_rect().size
	if global_position.y > view.y + 60.0 or global_position.x < -60.0 or global_position.x > view.x + 60.0:
		queue_free()

## La escena de pelea consulta esto para saber si llegó a Sofía.
func distance_to_point(point: Vector2) -> float:
	return global_position.distance_to(point)

func pop() -> void:
	queue_free()

func _draw() -> void:
	var wobble: float = 1.0 + sin(_phase) * 0.12
	draw_circle(Vector2.ZERO, _radius * wobble, Color(0.55, 0.85, 0.25, 0.9))
	draw_circle(Vector2.ZERO, _radius * 0.6 * wobble, Color(0.75, 0.95, 0.45, 0.95))
