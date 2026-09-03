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

## Cada cuánto cambia el peso de pie. Es lo que más la hace ver viva: una
## persona parada no se queda clavada, se acomoda.
const SHIFT_MIN_INTERVAL := 2.8
const SHIFT_MAX_INTERVAL := 5.5
const SHIFT_PIXELS := 5.0
const SHIFT_ROT := 0.016
## Qué tan rápido llega al nuevo apoyo. Lento a propósito: es acomodarse,
## no dar un paso.
const SHIFT_SPEED := 1.1

## Respiración: el eje Y se estira y el X se angosta a la vez, que es
## como se ve respirar de verdad. Si los dos crecieran juntos parecería
## que la imagen hace zoom.
## Estos números estaban calibrados para un BUSTO. Con la figura entera
## el mismo porcentaje se ve mucho menos, porque el movimiento se reparte
## en el doble de alto y encima la figura va escalada a 0.66. Medido con
## diferencia de cuadros: se movían unos 3.000 de 90.000 píxeles, casi
## todo en el borde del contorno — o sea, un PNG quieto.
const BREATH_SPEED := 1.15
const BREATH_Y := 0.021
const BREATH_X := 0.010
const BOB_PIXELS := 5.0
## El balanceo va mucho más lento que la respiración, si no marea.
const SWAY_SPEED := 0.41
const SWAY_PIXELS := 4.0
## Una segunda onda de balanceo, con otra frecuencia. Dos senos que no son
## múltiplos no vuelven a coincidir nunca, así que el vaivén no se repite
## y no se lee como un bucle.
const SWAY_SPEED_2 := 0.151
const SWAY_PIXELS_2 := 2.8
## Y un giro chiquito, que gira desde los PIES porque ahí está el origen
## del sprite. Esto es lo que la despega de "imagen pegada": una figura
## rígida que se inclina apenas se lee como alguien parado haciendo
## equilibrio.
const SWAY_ROT := 0.012
## Mientras habla se le suma un cabeceo corto, para que el texto no
## aparezca sobre alguien inmóvil.
const TALK_SPEED := 7.5
const TALK_PIXELS := 2.6
const TALK_ROT := 0.007

@onready var sprite: Sprite2D = $Sprite2D

var _idle_phase: float = 0.0
var _sway_phase: float = 0.0
var _talk_phase: float = 0.0
var _talking: bool = false
## El parpadeo y el énfasis pisan la escala; mientras corren, la
## respiración se aparta para no pelear con el tween.
var _scale_locked: bool = false
var _shift_timer: float = randf_range(SHIFT_MIN_INTERVAL, SHIFT_MAX_INTERVAL)
## Hacia qué lado está apoyando (-1 o 1) y dónde va llegando.
var _shift_target: float = 1.0
var _shift: float = 0.0
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
	var giro := sin(_sway_phase * 0.61) * SWAY_ROT
	if _talking:
		_talk_phase += delta * TALK_SPEED
		bob += sin(_talk_phase) * TALK_PIXELS
		giro += sin(_talk_phase * 0.5) * TALK_ROT

	# El cambio de apoyo: se elige un lado cada tantos segundos y se llega
	# despacio. Sumado al balanceo doble, el movimiento nunca se repite
	# igual, que es la diferencia entre "animado" y "en bucle".
	_shift_timer -= delta
	if _shift_timer <= 0.0:
		_shift_timer = randf_range(SHIFT_MIN_INTERVAL, SHIFT_MAX_INTERVAL)
		_shift_target = -_shift_target
	_shift = move_toward(_shift, _shift_target, delta * SHIFT_SPEED)

	sprite.position.y = bob
	sprite.position.x = (sin(_sway_phase) * SWAY_PIXELS
		+ sin(_sway_phase * SWAY_SPEED_2 / SWAY_SPEED) * SWAY_PIXELS_2
		+ _shift * SHIFT_PIXELS)
	if not _scale_locked:
		sprite.rotation = giro + _shift * SHIFT_ROT
		sprite.scale = Vector2(
			_base_scale.x * (1.0 - breath * BREATH_X),
			_base_scale.y * (1.0 + breath * BREATH_Y))

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

## El parpadeo se fue. Achataba el sprite un 15% en Y durante 0.14s: con
## un busto eso se leía como cerrar los ojos, pero con la figura entera es
## la persona completa achicándose de golpe. No hay forma de parpadear sin
## arte de ojos aparte, y el cambio de apoyo cumple la misma función —
## romper la quietud cada tantos segundos.
