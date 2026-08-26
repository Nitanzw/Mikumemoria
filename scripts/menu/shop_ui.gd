extends Control

## Tienda de armas: genera una fila por arma en WeaponSystem.WEAPONS
## y permite comprar/equipar contra el mismo estado que usa Player.
##
## Sobre el layout: la versión anterior se salía de la pantalla a la
## derecha (aparecía scroll horizontal y los botones quedaban cortados).
## Pasaba porque el ScrollContainer permitía scroll horizontal y los
## textos largos empujaban la fila más ancha que el viewport. Ahora el
## scroll horizontal está desactivado en la escena, los textos van con
## autowrap y el nombre queda arriba del botón en vez de al lado, que a
## 540px de ancho es lo único que entra cómodo.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var title: Label = $Margin/VBox/Header/HeaderVBox/Title
@onready var coins_holder: HBoxContainer = $Margin/VBox/Header/HeaderVBox/CoinsHolder
@onready var header: PanelContainer = $Margin/VBox/Header
@onready var back_button: Button = $Margin/VBox/BackButton

func _ready() -> void:
	header.add_theme_stylebox_override("panel", UITheme.scrim_style(0.55))
	UITheme.style_title(title, 30)
	UITheme.style_wood_button(back_button)

	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	GameManager.coins_changed.connect(func(_v): _refresh())
	_refresh()

func _refresh() -> void:
	for child in coins_holder.get_children():
		child.queue_free()
	coins_holder.add_child(UITheme.build_coin_row(GameManager.player_coins, 24))

	for child in list.get_children():
		child.queue_free()

	for weapon_name in WeaponSystem.get_all_weapon_names():
		list.add_child(_build_row(weapon_name))

func _build_row(weapon_name: String) -> Control:
	var data := WeaponSystem.get_weapon_data(weapon_name)
	var owned: bool = weapon_name in GameManager.unlocked_weapons
	var equipped: bool = weapon_name == GameManager.equipped_weapon

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card_style())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# Fila de arriba: ícono + nombre y stats.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)

	var icon := TextureRect.new()
	var sprite_path: String = data.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		icon.texture = load(sprite_path)
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = str(data.get("display_name", weapon_name))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(name_label, 22)
	info.add_child(name_label)

	var stats := Label.new()
	stats.text = "Daño %d · Radio %d" % [int(data.get("damage", 1)), int(data.get("radius", 50))]
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(stats, 17)
	stats.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	info.add_child(stats)

	top.add_child(info)
	box.add_child(top)

	# Botón a lo ancho de la tarjeta: a 540px no entra al lado del texto.
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 20)
	UITheme.style_wood_button(button)

	if equipped:
		button.text = "Equipado"
		button.disabled = true
	elif owned:
		button.text = "Equipar"
		button.pressed.connect(func():
			GameManager.equip_weapon(weapon_name)
			AudioManager.play_sfx("unlock")
			_refresh()
		)
	else:
		var price := int(data.get("price", 0))
		button.text = "Comprar · %d" % price
		button.disabled = GameManager.player_coins < price
		button.pressed.connect(func():
			if GameManager.purchase_weapon(weapon_name):
				AudioManager.play_sfx("unlock")
				_refresh()
		)

	box.add_child(button)
	return card
