class_name SplatEffect
extends Node2D

## Salpicadura al aplastar un insecto: una mancha central que se estira
## de golpe y varias gotas que salen disparadas en direcciones al azar y
## se van frenando. Todo dibujado con _draw() (nada de sprites nuevos),
## así que el color se puede adaptar al insecto que murió.

const DROPLET_COUNT_MIN := 6
const DROPLET_COUNT_MAX := 10
const DURATION := 0.45

var _color: Color = Color(0.45, 0.62, 0.22)
var _progress: float = 0.0
var _blob_radius: float = 16.0
var _droplets: Array = []  # cada una: {dir: Vector2, dist: float, radius: float}

func play(splat_color: Color = Color(0.45, 0.62, 0.22), scale_hint: float = 1.0) -> void:
	_color = splat_color
	_blob_radius = 16.0 * scale_hint
	_progress = 0.0
	_droplets.clear()

	var count := randi_range(DROPLET_COUNT_MIN, DROPLET_COUNT_MAX)
	for i in range(count):
		var angle := randf() * TAU
		_droplets.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"dist": randf_range(26.0, 58.0) * scale_hint,
			"radius": randf_range(2.5, 6.0) * scale_hint,
		})

	queue_redraw()

	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()

func _draw() -> void:
	# La mancha crece rápido al principio y después se desvanece; las
	# gotas viajan hacia afuera con la misma curva, encogiéndose.
	var fade: float = 1.0 - _progress
	var alpha: float = clampf(fade * 1.4, 0.0, 1.0)

	var blob_scale: float = 1.0 + _progress * 0.9
	var blob_color := Color(_color.r, _color.g, _color.b, alpha * 0.85)
	# Elipse achatada: sugiere "aplastado contra el piso".
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(blob_scale, blob_scale * 0.62))
	draw_circle(Vector2.ZERO, _blob_radius, blob_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for droplet in _droplets:
		var offset: Vector2 = droplet["dir"] * droplet["dist"] * _progress
		var r: float = droplet["radius"] * fade
		if r > 0.2:
			draw_circle(offset, r, Color(_color.r, _color.g, _color.b, alpha))
