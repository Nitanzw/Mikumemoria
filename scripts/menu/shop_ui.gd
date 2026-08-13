extends Control

## Tienda de armas: genera una fila por arma en WeaponSystem.WEAPONS
## y permite comprar/equipar contra el mismo estado que usa Player.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var coins_label: Label = $Margin/VBox/CoinsLabel
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	GameManager.coins_changed.connect(func(_v): _refresh())
	_refresh()

func _refresh() -> void:
	coins_label.text = "🪙 %d" % GameManager.player_coins

	for child in list.get_children():
		child.queue_free()

	for weapon_name in WeaponSystem.get_all_weapon_names():
		list.add_child(_build_row(weapon_name))

func _build_row(weapon_name: String) -> Control:
	var data := WeaponSystem.get_weapon_data(weapon_name)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon := TextureRect.new()
	var sprite_path: String = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		icon.texture = load(sprite_path)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := Label.new()
	label.text = "%s\nDaño %d · Radio %d" % [data.get("display_name", weapon_name), int(data.get("damage", 1)), int(data.get("radius", 50))]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(140, 44)
	var owned: bool = weapon_name in GameManager.unlocked_weapons
	var equipped: bool = weapon_name == GameManager.equipped_weapon

	if equipped:
		button.text = "Equipado"
		button.disabled = true
	elif owned:
		button.text = "Equipar"
		button.pressed.connect(func():
			GameManager.equip_weapon(weapon_name)
			_refresh()
		)
	else:
		var price := int(data.get("price", 0))
		button.text = "Comprar (%d)" % price
		button.disabled = GameManager.player_coins < price
		button.pressed.connect(func():
			if GameManager.purchase_weapon(weapon_name):
				AudioManager.play_sfx("unlock")
				_refresh()
		)

	row.add_child(button)
	return row
