class_name DonBetoPortrait
extends Node2D

## Retrato animado de Don Beto para el sistema de diálogo. No hay sprites
## de expresión distintos todavía (haría falta arte nuevo), así que las
## "emociones" se simulan sobre el único sprite existente: tinte de
## color + un salto de énfasis al cambiar de línea, más un parpadeo
## periódico (achique vertical breve) para que no se vea estático.
## Reemplazar por sprites reales de expresión cuando haya arte, sin
## tocar la API pública (set_emotion / play_emphasis).

const EMOTION_TINTS := {
	"neutral": Color(1, 1, 1),
	"happy": Color(1, 1, 1),
	"sad": Color(0.75, 0.8, 1.0),
	"angry": Color(1.0, 0.65, 0.6),
	"worried": Color(0.85, 0.78, 1.0),
}

const BLINK_MIN_INTERVAL := 2.5
const BLINK_MAX_INTERVAL := 5.0

@onready var sprite: Sprite2D = $Sprite2D

var _idle_phase: float = 0.0
var _blink_timer: float = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
var _base_scale: Vector2

func _ready() -> void:
	_base_scale = sprite.scale

func _process(delta: float) -> void:
	_idle_phase += delta * 1.6
	sprite.position.y = sin(_idle_phase) * 2.5

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
		_play_blink()

func set_emotion(emotion: String) -> void:
	var tint: Color = EMOTION_TINTS.get(emotion, Color.WHITE)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", tint, 0.2)
	_play_emphasis(emotion)

func _play_emphasis(emotion: String) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", _base_scale * 1.12, 0.1)
	tween.tween_property(sprite, "scale", _base_scale, 0.15)

	if emotion == "angry":
		var shake := create_tween()
		for i in range(4):
			var offset := Vector2(randf_range(-4, 4), 0)
			shake.tween_property(sprite, "position:x", offset.x, 0.04)
		shake.tween_property(sprite, "position:x", 0.0, 0.04)

func _play_blink() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale:y", _base_scale.y * 0.85, 0.06)
	tween.tween_property(sprite, "scale:y", _base_scale.y, 0.08)
