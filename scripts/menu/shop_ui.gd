extends Control

## Tienda: dos secciones.
##
## **Armas** (WeaponSystem): se compran una vez y se equipan; solo una a
## la vez. **Objetos** (ItemSystem): mejoras pasivas por niveles que
## hacen efecto solas, pensadas para aguantar las peleas de jefe —
## corazones extra, bloquear golpes, frenar a los refuerzos.
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

	list.add_child(_build_section("Armas"))
	for weapon_name in WeaponSystem.get_all_weapon_names():
		list.add_child(_build_row(weapon_name))

	# Objetos y poderes van separados: los pasivos hacen efecto solos, los
	# poderes son un botón en la pantalla de juego y además cobran monedas
	# cada vez que los usás. Mezclados no se entendía la diferencia.
	list.add_child(_build_section("Objetos"))
	for item_id in ItemSystem.get_all_item_ids():
		if not ItemSystem.get_item(item_id).get("active", false):
			list.add_child(_build_item_row(item_id))

	list.add_child(_build_section("Poderes"))
	for item_id in ItemSystem.get_all_item_ids():
		if ItemSystem.get_item(item_id).get("active", false):
			list.add_child(_build_item_row(item_id))

## Separador con el nombre de la sección: sin esto, armas y objetos
## quedaban mezclados en una sola lista larga y no se entendía qué era qué.
func _build_section(title: String) -> Control:
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_title(label, 24)
	label.custom_minimum_size = Vector2(0, 44)
	return label

## Fila de objeto pasivo. Igual que la de arma, pero muestra el nivel
## comprado sobre el máximo, porque son mejoras acumulables.
func _build_item_row(item_id: String) -> Control:
	var data := ItemSystem.get_item(item_id)
	var level := ItemSystem.get_level(GameManager.items, item_id)
	var max_level := ItemSystem.get_max_level(item_id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card_style())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)

	var icon_path: String = data.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = "%s  ·  %d/%d" % [data.get("display_name", item_id), level, max_level]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(name_label, 21)
	info.add_child(name_label)

	var desc := Label.new()
	var text: String = str(data.get("description", ""))
	if data.get("active", false):
		text += "\nCada uso: %d monedas" % ItemSystem.get_power_use_cost(item_id)
	desc.text = text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(desc, 16)
	desc.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	info.add_child(desc)

	top.add_child(info)
	box.add_child(top)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 20)
	UITheme.style_wood_button(button)

	var cost := ItemSystem.get_cost(GameManager.items, item_id)
	if cost < 0:
		button.text = "Al máximo"
		button.disabled = true
	else:
		button.text = ("Comprar · %d" % cost) if level == 0 else ("Mejorar · %d" % cost)
		button.disabled = GameManager.player_coins < cost
		button.pressed.connect(func():
			if GameManager.purchase_item(item_id):
				AudioManager.play_sfx("unlock")
				_refresh()
		)

	box.add_child(button)
	return card

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
