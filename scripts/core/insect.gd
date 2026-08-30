class_name Insect
extends CharacterBody2D

## Lógica de un insecto común. Los datos de cada tipo viven en INSECT_DATA
## para que el spawner también pueda consultarlos sin instanciar la escena.

const INSECT_DATA := {
	# --- Los 5 básicos ---
	"hormiga_obrera": {"speed": 100.0, "health": 1, "points": 50, "coin_reward": 10, "sprite": "res://assets/sprites/insects/hormiga_obrera.png"},
	"cucaracha_electrica": {"speed": 200.0, "health": 1, "points": 75, "coin_reward": 15, "sprite": "res://assets/sprites/insects/cucaracha_electrica.png"},
	"escarabajo_blindado": {"speed": 50.0, "health": 3, "points": 150, "coin_reward": 30, "sprite": "res://assets/sprites/insects/escarabajo_blindado.png"},
	"mosca_pesada": {"speed": 150.0, "health": 1, "points": 100, "coin_reward": 20, "sprite": "res://assets/sprites/insects/mosca_pesada.png"},
	"grillo_saltarin": {"speed": 120.0, "health": 1, "points": 80, "coin_reward": 16, "sprite": "res://assets/sprites/insects/grillo_saltarin.png"},

	# --- Variantes avanzadas. Reusan el arte de los incógnitos, que hasta
	# ahora solo se veía al revelarlos. Cubren el rango completo: desde
	# tanques lentísimos de 8 de vida hasta bichos de un solo golpe que
	# cruzan la pantalla volando.
	"mutante_volador": {"speed": 210.0, "health": 2, "points": 160, "coin_reward": 34, "sprite": "res://assets/sprites/insects/mutante_volador.png"},
	"hormiga_ladrona": {"speed": 180.0, "health": 2, "points": 140, "coin_reward": 40, "sprite": "res://assets/sprites/insects/hormiga_ladrona.png"},
	"lombriz_gigante": {"speed": 55.0, "health": 4, "points": 190, "coin_reward": 42, "sprite": "res://assets/sprites/insects/lombriz_gigante.png"},
	"abejorro_pinata": {"speed": 140.0, "health": 3, "points": 175, "coin_reward": 46, "sprite": "res://assets/sprites/insects/abejorro_pinata.png"},
	"mantis_cronometro": {"speed": 130.0, "health": 3, "points": 180, "coin_reward": 38, "sprite": "res://assets/sprites/insects/mantis_cronometro.png"},
	"escarabajo_radiactivo": {"speed": 70.0, "health": 5, "points": 240, "coin_reward": 52, "sprite": "res://assets/sprites/insects/escarabajo_radiactivo.png"},
	"centella_blindada": {"speed": 110.0, "health": 5, "points": 260, "coin_reward": 56, "sprite": "res://assets/sprites/insects/centella_blindada.png"},
	"rayo_insecto": {"speed": 320.0, "health": 1, "points": 220, "coin_reward": 48, "sprite": "res://assets/sprites/insects/rayo_insecto.png"},
	"coraza_antigua": {"speed": 45.0, "health": 8, "points": 320, "coin_reward": 70, "sprite": "res://assets/sprites/insects/coraza_antigua.png"},
}

## Los cuadros del ciclo de caminata se buscan por convención de nombre:
## `<tipo>_walk_0.png` .. `<tipo>_walk_3.png`, al lado del sprite fijo. No
## hay que declararlos en INSECT_DATA: alcanza con que los archivos estén,
## y el bicho pasa a caminar solo. Así, generar el arte que falta (los 10
## incógnitos) es un comando y cero cambios de código.
const WALK_FRAME_COUNT := 4

const WANDER_MIN := 0.6
const WANDER_MAX := 1.4
const LIFETIME := 7.0
const SCREEN_MARGIN := 100.0
## Cuánto tira hacia el centro al elegir rumbo. Con exponente > 1 el
## efecto casi no se nota en el medio y se vuelve fuerte cerca del borde.
const EDGE_PULL_CURVE := 2.0
## Margen hacia adentro para considerar que ya "entró" a la pantalla.
const ON_SCREEN_INSET := 24.0
## Franja de arriba que ocupa el panel del HUD. Los bichos no se quedan
## ahí: detrás del panel translúcido casi no se los ve y tapearlos es a
## ciegas. No es una pared — pueden cruzarla — pero el rumbo los saca.
const PLAY_TOP_INSET := 215.0
## Franja de abajo donde está Sofía.
const PLAY_BOTTOM_INSET := 120.0

const SplatEffectScene := preload("res://scenes/effects/splat_effect.tscn")

## Color de la salpicadura por tipo de insecto (se usa al aplastarlo).
## Si un tipo no está acá, cae en el verde genérico de SplatEffect.
const SPLAT_COLORS := {
	"hormiga_obrera": Color(0.42, 0.26, 0.13),
	"cucaracha_electrica": Color(0.88, 0.78, 0.20),
	"escarabajo_blindado": Color(0.34, 0.44, 0.55),
	"mosca_pesada": Color(0.30, 0.30, 0.33),
	"grillo_saltarin": Color(0.35, 0.65, 0.25),
	"mutante_volador": Color(0.55, 0.35, 0.68),
	"hormiga_ladrona": Color(0.78, 0.62, 0.20),
	"lombriz_gigante": Color(0.88, 0.55, 0.60),
	"abejorro_pinata": Color(0.92, 0.55, 0.18),
	"mantis_cronometro": Color(0.28, 0.62, 0.58),
	"escarabajo_radiactivo": Color(0.45, 0.85, 0.25),
	"centella_blindada": Color(0.30, 0.50, 0.80),
	"rayo_insecto": Color(0.95, 0.88, 0.30),
	"coraza_antigua": Color(0.45, 0.52, 0.35),
}

@export var insect_type: String = "hormiga_obrera"
@export var speed_mult: float = 1.0

# Cada insecto que aparece toma un factor propio dentro de este rango, así
# dos bichos del mismo tipo no se mueven calcados. Es sutil a propósito:
# más rango que esto y el jugador deja de poder anticipar al enemigo.
## Vida extra que le suma el escalón de dificultad del nivel. La setea
## el spawner antes de agregar el insecto al árbol.
var health_bonus: int = 0

const SPEED_VARIANCE_MIN := 0.82
const SPEED_VARIANCE_MAX := 1.18

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
	base_speed = float(data["speed"]) * speed_mult * randf_range(SPEED_VARIANCE_MIN, SPEED_VARIANCE_MAX)
	speed = base_speed
	health = int(data["health"]) + health_bonus
	current_health = health
	points = int(data["points"])
	coin_reward = int(data["coin_reward"])
	_apply_sprite_data(sprite, data, insect_type)

## Arma un SpriteFrames para el insecto. Si están los
## `<tipo>_walk_N.png` arma el ciclo de caminata; si no, cae en un único
## cuadro estático desde "sprite" (mismo resultado visual que un Sprite2D
## de toda la vida, pero con el mismo tipo de nodo para todos).
##
## Ojo con el caso borde: si se arma el SpriteFrames y después no se
## carga ningún cuadro, el insecto queda **invisible** en vez de caer al
## sprite fijo. Por eso primero se juntan las texturas y recién se decide.
func _apply_sprite_data(target: AnimatedSprite2D, data: Dictionary, type_name: String) -> void:
	if not target:
		return

	var textures: Array[Texture2D] = []
	for i in range(WALK_FRAME_COUNT):
		var path := "res://assets/sprites/insects/%s_walk_%d.png" % [type_name, i]
		if ResourceLoader.exists(path):
			textures.append(load(path))

	# Con un solo cuadro no hay animación que valga: es el sprite fijo.
	if textures.size() > 1:
		var frames := SpriteFrames.new()
		frames.add_animation("walk")
		frames.set_animation_loop("walk", true)
		frames.set_animation_speed("walk", 8.0)
		for texture in textures:
			frames.add_frame("walk", texture)
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
			# Hasta no estar DENTRO de la pantalla no cambia de rumbo:
			# nacen afuera, y girar antes de entrar los hacía volverse.
			if _is_on_screen():
				_wander_direction()
				wander_timer = randf_range(WANDER_MIN, WANDER_MAX)
			else:
				wander_timer = 0.2
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

## Zona jugable: la pantalla menos la franja del HUD arriba y la de
## Sofía abajo. Es sobre esto que se calcula el tirón hacia el centro.
func _play_rect() -> Rect2:
	var view := get_viewport_rect().size
	var top := PLAY_TOP_INSET
	var bottom := view.y - PLAY_BOTTOM_INSET
	return Rect2(ON_SCREEN_INSET, top, maxf(view.x - ON_SCREEN_INSET * 2.0, 1.0), maxf(bottom - top, 1.0))

func _is_on_screen() -> bool:
	return _play_rect().has_point(global_position)

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
	_set_direction(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized())

## Elige un rumbo nuevo, pero TIRANDO HACIA ADENTRO de la pantalla.
##
## Antes era puro azar sin mirar dónde estaba el insecto. Como todos
## nacen fuera de la pantalla y el primer cambio de rumbo llega a los
## 0.6-1.4 segundos, muchos se daban vuelta antes de llegar a entrar y se
## iban por donde vinieron. El resultado era el que reportó el tester:
## los bichos se quedan pegados a los bordes, casi no se ven y son un
## garrón de matar.
##
## Cuanto más cerca del borde está, más pesa el vector hacia el centro:
## en el medio de la pantalla se mueve libre, contra el borde se da vuelta.
func _wander_direction() -> void:
	var play := _play_rect()
	var center := play.position + play.size / 2.0
	var to_center := (center - global_position)
	# 0 en el centro, 1 pegado al borde (o afuera).
	var half := play.size / 2.0
	var edge_pull: float = clampf(to_center.length() / maxf(half.length(), 1.0), 0.0, 1.0)
	edge_pull = pow(edge_pull, EDGE_PULL_CURVE)

	var random_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if random_dir == Vector2.ZERO:
		random_dir = Vector2.RIGHT
	_set_direction(random_dir.normalized().lerp(to_center.normalized(), edge_pull).normalized())

func _set_direction(new_direction: Vector2) -> void:
	direction = new_direction if new_direction != Vector2.ZERO else Vector2.RIGHT
	if sprite:
		sprite.flip_h = direction.x < 0
