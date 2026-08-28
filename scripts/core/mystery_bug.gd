class_name MysteryBug
extends Insect

## Insecto incógnito. Su progreso de revelación se guarda en
## GameManager.mystery_progress (por índice), NO en esta instancia,
## porque el mismo incógnito reaparece durante 9 niveles seguidos
## (ver LevelManager.has_mystery_bug) y debe recordar cuánto llevaba.

const REVEAL_MAX := 100.0
const EDGE_MARGIN := 48.0

const MYSTERY_DATABASE := {
	1: {"name": "Hormiga Ladrona de Diamantes", "type": "hormiga_ladrona", "speed": 100.0, "points": 100, "coin_reward": 150, "sprite": "res://assets/sprites/insects/hormiga_ladrona.png"},
	2: {"name": "Abejorro Piñata", "type": "abejorro_pinata", "speed": 150.0, "points": 150, "coin_reward": 220, "sprite": "res://assets/sprites/insects/abejorro_pinata.png"},
	3: {"name": "Mantis Cronómetro", "type": "mantis_cronometro", "speed": 120.0, "points": 120, "coin_reward": 180, "sprite": "res://assets/sprites/insects/mantis_cronometro.png"},
	4: {"name": "Escarabajo Radiactivo", "type": "escarabajo_radiactivo", "speed": 140.0, "points": 140, "coin_reward": 200, "sprite": "res://assets/sprites/insects/escarabajo_radiactivo.png"},
	5: {"name": "Lombriz Gigante", "type": "lombriz_gigante", "speed": 60.0, "points": 130, "coin_reward": 190, "sprite": "res://assets/sprites/insects/lombriz_gigante.png"},
	6: {"name": "Mutagénesis Voladora", "type": "mutante_volador", "speed": 180.0, "points": 160, "coin_reward": 240, "sprite": "res://assets/sprites/insects/mutante_volador.png"},
	7: {"name": "Centella Blindada", "type": "centella_blindada", "speed": 110.0, "points": 170, "coin_reward": 250, "sprite": "res://assets/sprites/insects/centella_blindada.png"},
	8: {"name": "Rayo Insecto", "type": "rayo_insecto", "speed": 250.0, "points": 200, "coin_reward": 300, "sprite": "res://assets/sprites/insects/rayo_insecto.png"},
	9: {"name": "Coraza Antigua", "type": "coraza_antigua", "speed": 90.0, "points": 180, "coin_reward": 270, "sprite": "res://assets/sprites/insects/coraza_antigua.png"},
	10: {"name": "Reina Primordial", "type": "reina_primordial", "speed": 130.0, "points": 300, "coin_reward": 500, "sprite": "res://assets/sprites/insects/reina_primordial.png"},
}

@onready var reveal_bar: ProgressBar = $RevealBar
@onready var mystery_sprite: Sprite2D = $MysterySprite
@onready var progress_label: Label = $ProgressLabel

var mystery_index: int = 0
var insect_data: Dictionary = {}
var is_revealed: bool = false

func _ready() -> void:
	add_to_group("insects")
	insect_type = "mystery"
	is_dead = false
	can_be_hit = true
	base_speed = 90.0
	speed = base_speed
	current_health = 1
	health = 1

	mystery_index = GameManager.get_current_level_config().get("mystery_index", 0)
	insect_data = MYSTERY_DATABASE.get(mystery_index, {})

	if insect_data.is_empty():
		push_warning("[MysteryBug] Sin datos para índice %d" % mystery_index)
		queue_free()
		return

	points = 20
	coin_reward = 0  # las monedas grandes se entregan solo al revelar

	# Mismo camino que Insect: si están los <tipo>_walk_N.png, el incógnito
	# camina animado igual que los comunes; si no, queda el sprite fijo.
	# Antes acá se forzaba el sprite fijo, así que los 10 incógnitos nunca
	# animaban por más que existiera su ciclo.
	if sprite:
		_apply_sprite_data(sprite, insect_data, String(insect_data.get("type", "")))
	if mystery_sprite:
		mystery_sprite.texture = load("res://assets/sprites/insects/mystery_bug_silueta.png")

	randomize_direction()
	_show_mystery_sprite()
	_update_reveal_visuals()

func _process(delta: float) -> void:
	super._process(delta)
	if mystery_sprite and sprite:
		mystery_sprite.rotation = sprite.rotation
		mystery_sprite.position.y = sprite.position.y

func _physics_process(delta: float) -> void:
	if is_dead or is_revealed:
		return

	if is_taunting:
		taunt_timer -= delta
		if taunt_timer <= 0.0:
			is_taunting = false
			speed = base_speed
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			randomize_direction()
			wander_timer = randf_range(1.0, 2.0)

	velocity = direction * speed
	move_and_slide()
	_bounce_off_edges()

func _bounce_off_edges() -> void:
	var viewport_size := get_viewport_rect().size

	if global_position.x < EDGE_MARGIN or global_position.x > viewport_size.x - EDGE_MARGIN:
		direction.x *= -1.0
	if global_position.y < EDGE_MARGIN or global_position.y > viewport_size.y - EDGE_MARGIN:
		direction.y *= -1.0

	global_position.x = clamp(global_position.x, EDGE_MARGIN, viewport_size.x - EDGE_MARGIN)
	global_position.y = clamp(global_position.y, EDGE_MARGIN, viewport_size.y - EDGE_MARGIN)

func _show_mystery_sprite() -> void:
	if mystery_sprite:
		mystery_sprite.modulate.a = 1.0
	if sprite:
		sprite.modulate.a = 0.0
	if progress_label:
		progress_label.text = "???"

func take_damage(damage: int = 1) -> void:
	if is_dead or is_revealed:
		return

	var progress := GameManager.add_mystery_progress(mystery_index, float(damage))
	_update_reveal_visuals()
	_play_reveal_flash()

	GameManager.on_insect_hit(self)

	if progress >= REVEAL_MAX:
		reveal_insect()
	else:
		play_hit_animation()

func _update_reveal_visuals() -> void:
	var progress := GameManager.get_mystery_progress(mystery_index)
	var percentage: float = clamp((progress / REVEAL_MAX) * 100.0, 0.0, 100.0)

	if reveal_bar:
		reveal_bar.value = percentage
	if progress_label:
		progress_label.text = "%d%%" % int(percentage)

	var fade: float = percentage / 100.0
	if mystery_sprite:
		mystery_sprite.modulate.a = 1.0 - fade
	if sprite:
		sprite.modulate.a = fade

func reveal_insect() -> void:
	if is_revealed:
		return

	is_revealed = true
	print("[MysteryBug] ¡Revelado! %s" % insect_data.get("name", "???"))

	_play_revelation_animation()
	AudioManager.play_sfx("mystery_revealed")

	GameManager.unlock_insect(mystery_index, insect_data)
	GameManager.add_coins(int(insect_data.get("coin_reward", 0)))

	await get_tree().create_timer(1.2).timeout
	queue_free()

func _play_reveal_flash() -> void:
	if not sprite and not mystery_sprite:
		return
	# Aplica el flash al sprite más visible en este momento (según cuánto
	# se haya revelado), si no el jugador podría no ver feedback del golpe.
	var target: CanvasItem = sprite if sprite and sprite.modulate.a >= 0.5 else mystery_sprite
	if not target:
		target = sprite if sprite else mystery_sprite
	var original_modulate := target.modulate
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(2.0, 2.0, 1.2, original_modulate.a), 0.05)
	tween.tween_property(target, "modulate", original_modulate, 0.08)

func _play_revelation_animation() -> void:
	if not sprite:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
