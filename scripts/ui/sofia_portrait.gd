class_name SofiaPortrait
extends Node2D

## Retrato animado de Sofía para el sistema de diálogo. Cada emoción
## tiene su propio sprite real (generado con tools/generate_sprites_openrouter.py
## --asset sofia_<emocion>); si a alguna le falta el archivo, cae en
## el sprite neutral con un tinte de color como antes, para que nunca
## quede un retrato roto. Encima de eso: un salto de énfasis al cambiar
## de línea y un parpadeo periódico (achique vertical breve) para que no
## se vea estático, más una respiración lenta (el pecho se ensancha y se
## angosta) y un balanceo casi imperceptible. Con el retrato chico dentro
## de un panel eso no se notaba; ahora que va grande en escena es la
## diferencia entre un personaje y un JPG pegado.

## Cuerpo entero, no busto. El busto había que taparlo abajo con una
## banda para que no se viera cortado; entera se la puede mostrar como una
## figura recortada sobre la viñeta, que es lo que pidió el tester.
##
## Cada pose acompaña a su emoción: la triste va de hombros caídos, la
## sorprendida con las manos arriba. Con un busto eso no se podía contar.
const EMOTION_TEXTURES := {
	"neutral": "res://assets/sprites/character/sofia_cuerpo_neutral.png",
	"happy": "res://assets/sprites/character/sofia_cuerpo_happy.png",
	"sad": "res://assets/sprites/character/sofia_cuerpo_sad.png",
	"angry": "res://assets/sprites/character/sofia_cuerpo_angry.png",
	"worried": "res://assets/sprites/character/sofia_cuerpo_worried.png",
	"surprised": "res://assets/sprites/character/sofia_cuerpo_surprised.png",
}

const EMOTION_TINTS := {
	"neutral": Color(1, 1, 1),
	"happy": Color(1, 1, 1),
	"sad": Color(0.75, 0.8, 1.0),
	"angry": Color(1.0, 0.65, 0.6),
	"worried": Color(0.85, 0.78, 1.0),
	"surprised": Color(1.0, 0.95, 0.8),
}

const BLINK_MIN_INTERVAL := 2.5
const BLINK_MAX_INTERVAL := 5.0

## Respiración: el eje Y se estira y el X se angosta a la vez, que es
## como se ve respirar de verdad. Si los dos crecieran juntos parecería
## que la imagen hace zoom.
const BREATH_SPEED := 1.15
const BREATH_Y := 0.016
const BREATH_X := 0.007
const BOB_PIXELS := 3.0
## El balanceo va mucho más lento que la respiración, si no marea.
const SWAY_SPEED := 0.41
const SWAY_PIXELS := 2.5
## Mientras habla se le suma un cabeceo corto, para que el texto no
## aparezca sobre alguien inmóvil.
const TALK_SPEED := 7.5
const TALK_PIXELS := 1.6

@onready var sprite: Sprite2D = $Sprite2D

var _idle_phase: float = 0.0
var _sway_phase: float = 0.0
var _talk_phase: float = 0.0
var _talking: bool = false
## El parpadeo y el énfasis pisan la escala; mientras corren, la
## respiración se aparta para no pelear con el tween.
var _scale_locked: bool = false
var _blink_timer: float = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
var _base_scale: Vector2

func _ready() -> void:
	_base_scale = sprite.scale
	_anclar_a_los_pies()

## Mueve el origen del sprite a la planta de los pies.
##
## El Sprite2D centra la textura, así que la respiración (que escala el
## eje Y) le movía los pies media amplitud hacia abajo: parecía que
## flotaba y se hundía. Anclada abajo, respira desde el piso, que es como
## respira alguien parado.
func _anclar_a_los_pies() -> void:
	if sprite.texture:
		sprite.offset.y = -sprite.texture.get_height() * 0.5

func _process(delta: float) -> void:
	_idle_phase += delta * BREATH_SPEED
	_sway_phase += delta * SWAY_SPEED
	var breath := sin(_idle_phase)

	var bob := breath * BOB_PIXELS
	if _talking:
		_talk_phase += delta * TALK_SPEED
		bob += sin(_talk_phase) * TALK_PIXELS
	sprite.position.y = bob
	sprite.position.x = sin(_sway_phase) * SWAY_PIXELS

	if not _scale_locked:
		sprite.scale = Vector2(
			_base_scale.x * (1.0 - breath * BREATH_X),
			_base_scale.y * (1.0 + breath * BREATH_Y))

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(BLINK_MIN_INTERVAL, BLINK_MAX_INTERVAL)
		_play_blink()

func set_emotion(emotion: String) -> void:
	var texture_path: String = EMOTION_TEXTURES.get(emotion, "")
	var tint: Color = Color.WHITE
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	else:
		# Sin sprite para esta emoción: nos quedamos con el que ya está
		# puesto y simulamos la emoción con tinte, como antes.
		tint = EMOTION_TINTS.get(emotion, Color.WHITE)

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", tint, 0.2)
	_play_emphasis(emotion)
	_anclar_a_los_pies()

## Se avisa cuando está tipeando texto, para sumarle el cabeceo.
func set_talking(talking: bool) -> void:
	_talking = talking
	if not talking:
		_talk_phase = 0.0

func _play_emphasis(emotion: String) -> void:
	_scale_locked = true
	var tween := create_tween()
	tween.tween_property(sprite, "scale", _base_scale * 1.10, 0.1)
	tween.tween_property(sprite, "scale", _base_scale, 0.15)
	tween.finished.connect(func(): _scale_locked = false)

	if emotion == "angry":
		var shake := create_tween()
		for i in range(4):
			var offset := Vector2(randf_range(-4, 4), 0)
			shake.tween_property(sprite, "position:x", offset.x, 0.04)
		shake.tween_property(sprite, "position:x", 0.0, 0.04)

func _play_blink() -> void:
	if _scale_locked:
		return
	_scale_locked = true
	var tween := create_tween()
	tween.tween_property(sprite, "scale:y", _base_scale.y * 0.85, 0.06)
	tween.tween_property(sprite, "scale:y", _base_scale.y, 0.08)
	tween.finished.connect(func(): _scale_locked = false)
