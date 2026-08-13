class_name HitEffect
extends Node2D

## Anillo que se expande y se desvanece al tocar la pantalla.
## Sustituye al `Circle2D` del documento original, que no existe en Godot.

var _radius: float = 50.0
var _max_radius: float = 100.0
var _alpha: float = 1.0
var _line_width: float = 4.0

func play(radius: float) -> void:
	_radius = radius * 0.6
	_max_radius = radius * 1.4
	_alpha = 1.0
	queue_redraw()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_radius, _radius, _max_radius, 0.25)
	tween.tween_method(_set_alpha, 1.0, 0.0, 0.25)
	tween.chain().tween_callback(queue_free)

func _set_radius(value: float) -> void:
	_radius = value
	queue_redraw()

func _set_alpha(value: float) -> void:
	_alpha = value
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, _alpha), _line_width, true)
