class_name WeaponStrike
extends Node2D

## El arma equipada apareciendo en el lugar del tap: baja de golpe,
## aplasta (se achata un instante) y se va hacia arriba desvaneciéndose.
## Usa el sprite que ya define WeaponSystem.WEAPONS, así el arma que se
## ve es siempre la que está equipada de verdad.

const DROP_HEIGHT := 90.0
const BASE_SIZE := 96.0

@onready var sprite: Sprite2D = $Sprite2D

func play(weapon_name: String, radius: float) -> void:
	# `sprite` viene de @onready, que recién se asigna cuando el nodo
	# entra al árbol. Si play() se llama antes de eso (o desde un
	# contexto donde _ready quedó diferido), lo resolvemos a mano en vez
	# de reventar con un acceso sobre null.
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		queue_free()
		return

	var data: Dictionary = WeaponSystem.get_weapon_data(weapon_name)
	var path: String = data.get("sprite", "")
	if path == "" or not ResourceLoader.exists(path):
		queue_free()
		return

	var texture: Texture2D = load(path)
	sprite.texture = texture

	# El arma se dibuja proporcional al radio de golpe: un matamoscas de
	# radio 80 se ve más grande que el zapato de radio 50.
	var tex_size := texture.get_size()
	var target: float = BASE_SIZE * (radius / 50.0)
	var base_scale: float = target / maxf(tex_size.x, tex_size.y)

	# Entra inclinada y desde arriba, como si cayera sobre el bicho.
	sprite.position = Vector2(0.0, -DROP_HEIGHT)
	sprite.rotation = -0.5
	sprite.scale = Vector2(base_scale, base_scale)
	sprite.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()

	# 1. Caída rápida hasta el punto del tap.
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "rotation", 0.0, 0.08)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

	# 2. Impacto: se achata contra el suelo un instante.
	tween.chain().tween_property(sprite, "scale", Vector2(base_scale * 1.18, base_scale * 0.78), 0.06)
	tween.chain().tween_property(sprite, "scale", Vector2(base_scale, base_scale), 0.07)

	# 3. Se levanta y desaparece.
	tween.chain().set_parallel(true)
	tween.tween_property(sprite, "position", Vector2(0.0, -DROP_HEIGHT * 0.7), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", -0.35, 0.16)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.16)

	tween.chain().tween_callback(queue_free)
