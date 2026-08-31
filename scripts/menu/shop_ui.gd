extends Control

## Tienda, con DOS VISTAS que se alternan con el botón de arriba:
##
## - **Cuadrícula** (por defecto): una grilla de íconos tipo market. De un
##   vistazo se ve todo el catálogo; tocando uno se abre su ficha con la
##   descripción y el botón de comprar. Con 18 artículos, la lista con
##   texto completo obligaba a scrollear muchísimo para encontrar algo.
## - **Lista**: la vista detallada de siempre, con nombre y descripción
##   visibles en cada fila.
##
## La vista elegida se guarda, así no hay que volver a cambiarla.
##
## Tres secciones.
##
## **Armas** (WeaponSystem): se compran una vez y se equipan; solo una a
## la vez. **Objetos** (ItemSystem): mejoras pasivas por niveles que
## hacen efecto solas, pensadas para aguantar las peleas de jefe —
## vida extra, bloquear golpes, frenar a los refuerzos.
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

const GRID_COLUMNS := 3
const TILE := Vector2(96, 108)

var _grid_view: bool = true
var _view_button: Button

func _ready() -> void:
	header.add_theme_stylebox_override("panel", UITheme.scrim_style(0.55))
	UITheme.style_title(title, 30)
	UITheme.style_wood_button(back_button)

	back_button.text = "Volver al nivel" if GameManager.return_to_game_after_shop else "Volver"
	back_button.pressed.connect(_on_back_pressed)

	_grid_view = bool(GameManager.shop_grid_view)
	_build_view_toggle()

	GameManager.coins_changed.connect(func(_v): _refresh())
	_refresh()

## Botón para alternar vista. Va en el encabezado, arriba de todo, que es
## donde se lo busca.
func _build_view_toggle() -> void:
	_view_button = Button.new()
	_view_button.custom_minimum_size = Vector2(0, 46)
	_view_button.add_theme_font_size_override("font_size", 18)
	UITheme.style_wood_button(_view_button)
	_view_button.pressed.connect(func():
		_grid_view = not _grid_view
		GameManager.set_shop_grid_view(_grid_view)
		_refresh()
	)
	$Margin/VBox.add_child(_view_button)
	$Margin/VBox.move_child(_view_button, 1)

func _refresh() -> void:
	for child in coins_holder.get_children():
		child.queue_free()
	coins_holder.add_child(UITheme.build_coin_row(GameManager.player_coins, 24))

	for child in list.get_children():
		child.queue_free()

	if _view_button:
		_view_button.text = "Ver en lista" if _grid_view else "Ver en cuadrícula"

	if _grid_view:
		_build_grid_view()
	else:
		_build_list_view()

## Vista detallada: una tarjeta por artículo, con su descripción.
func _build_list_view() -> void:
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

## Vista cuadrícula: solo íconos, con su precio abajo. La descripción se
## ve tocando el artículo.
func _build_grid_view() -> void:
	list.add_child(_build_section("Armas"))
	list.add_child(_build_grid(WeaponSystem.get_all_weapon_names(), true))

	var pasivos: Array = []
	var poderes: Array = []
	for item_id in ItemSystem.get_all_item_ids():
		if ItemSystem.get_item(item_id).get("active", false):
			poderes.append(item_id)
		else:
			pasivos.append(item_id)

	list.add_child(_build_section("Objetos"))
	list.add_child(_build_grid(pasivos, false))
	list.add_child(_build_section("Poderes"))
	list.add_child(_build_grid(poderes, false))

func _build_grid(ids: Array, are_weapons: bool) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for item_id in ids:
		grid.add_child(_build_tile(item_id, are_weapons))
	return grid

## Casillero de la cuadrícula: ícono grande, y abajo el estado (precio,
## nivel comprado, o "Equipado"). Sin texto largo: para eso está la ficha.
func _build_tile(item_id: String, is_weapon: bool) -> Control:
	var button := Button.new()
	button.custom_minimum_size = TILE
	button.add_theme_stylebox_override("normal", UITheme.card_style())
	button.add_theme_stylebox_override("hover", UITheme.card_style())
	button.add_theme_stylebox_override("pressed", UITheme.card_style())
	button.pressed.connect(_show_detail.bind(item_id, is_weapon))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)

	var icon := TextureRect.new()
	var path: String = _icon_path(item_id, is_weapon)
	if path != "" and ResourceLoader.exists(path):
		icon.texture = load(path)
	icon.custom_minimum_size = Vector2(0, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var status := Label.new()
	status.text = _tile_status(item_id, is_weapon)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_body(status, 14)
	box.add_child(status)
	return button

func _icon_path(item_id: String, is_weapon: bool) -> String:
	if is_weapon:
		return str(WeaponSystem.get_weapon_data(item_id).get("sprite", ""))
	return str(ItemSystem.get_item(item_id).get("icon", ""))

func _tile_status(item_id: String, is_weapon: bool) -> String:
	if is_weapon:
		if not WeaponSystem.is_unlocked(GameManager.weapon_levels, item_id):
			return "🔒"
		var wl := GameManager.get_weapon_level(item_id)
		var wcost := WeaponSystem.get_upgrade_cost(item_id, wl)
		if wcost < 0:
			return "MAX %d/%d" % [wl, WeaponSystem.MAX_LEVEL]
		return "%d/%d\n%d" % [wl, WeaponSystem.MAX_LEVEL, wcost]

	if not ItemSystem.is_unlocked(GameManager.items, item_id):
		return "🔒"
	var level := ItemSystem.get_level(GameManager.items, item_id)
	var cost := ItemSystem.get_cost(GameManager.items, item_id)
	if cost < 0:
		return "MAX %d/%d" % [level, ItemSystem.get_max_level(item_id)]
	return "%d/%d\n%d" % [level, ItemSystem.get_max_level(item_id), cost]

## Ficha del artículo: se abre al tocar un casillero de la cuadrícula.
## Es la misma tarjeta que usa la vista de lista, sobre un fondo oscuro,
## para no tener dos formas distintas de mostrar lo mismo.
func _show_detail(item_id: String, is_weapon: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(440, 0)
	holder.add_theme_constant_override("separation", 10)
	center.add_child(holder)

	holder.add_child(_build_row(item_id) if is_weapon else _build_item_row(item_id))

	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(0, 50)
	close.add_theme_font_size_override("font_size", 20)
	UITheme.style_wood_button(close)
	close.pressed.connect(func(): dim.queue_free())
	holder.add_child(close)

	# Comprar desde la ficha cierra y refresca: si quedara abierta, el
	# precio y el nivel que muestra serían los de antes de la compra.
	GameManager.coins_changed.connect(func(_v):
		if is_instance_valid(dim):
			dim.queue_free()
	, CONNECT_ONE_SHOT)

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
	if not ItemSystem.is_unlocked(GameManager.items, item_id):
		button.text = ItemSystem.get_lock_reason(item_id)
		button.disabled = true
	elif cost < 0:
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
	var level := GameManager.get_weapon_level(weapon_name)
	var owned := level > 0
	var equipped: bool = weapon_name == GameManager.equipped_weapon
	var unlocked := WeaponSystem.is_unlocked(GameManager.weapon_levels, weapon_name)
	var cost := WeaponSystem.get_upgrade_cost(weapon_name, level)

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
	if owned:
		name_label.text += "  ·  nivel %d/%d" % [level, WeaponSystem.MAX_LEVEL]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(name_label, 22)
	info.add_child(name_label)

	var stats := Label.new()
	var damage := WeaponSystem.get_damage(weapon_name, level)
	stats.text = "Daño %d · Radio %d" % [damage, int(data.get("radius", 50))]
	if owned and cost > 0:
		# Ver el salto antes de pagar es lo que hace que la mejora se
		# entienda: "Daño 7 → 9" dice más que "nivel 4".
		stats.text += "   (sube a %d)" % WeaponSystem.get_damage(weapon_name, level + 1)
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

	if not unlocked:
		button.text = WeaponSystem.get_lock_reason(weapon_name)
		button.disabled = true
	elif cost < 0:
		button.text = "Al máximo" if equipped else "Equipar (máximo)"
		button.disabled = equipped
		if not equipped:
			button.pressed.connect(func():
				GameManager.equip_weapon(weapon_name)
				AudioManager.play_sfx("unlock")
				_refresh()
			)
	else:
		button.text = ("Mejorar · %d" % cost) if owned else ("Comprar · %d" % cost)
		button.disabled = GameManager.player_coins < cost
		button.pressed.connect(func():
			if GameManager.upgrade_weapon(weapon_name):
				AudioManager.play_sfx("unlock")
				_refresh()
		)

	box.add_child(button)

	# Un arma comprada pero no equipada necesita su propio botón: el de
	# arriba ahora es el de mejorar, no el de equipar.
	if owned and not equipped and cost >= 0:
		var equip_button := Button.new()
		equip_button.custom_minimum_size = Vector2(0, 48)
		equip_button.add_theme_font_size_override("font_size", 18)
		UITheme.style_wood_button(equip_button)
		equip_button.text = "Equipar"
		equip_button.pressed.connect(func():
			GameManager.equip_weapon(weapon_name)
			AudioManager.play_sfx("unlock")
			_refresh()
		)
		box.add_child(equip_button)
	return card


## Vuelve a donde estabas: al juego si entraste desde el resumen de un
## nivel, al menú principal si entraste desde el menú.
func _on_back_pressed() -> void:
	if GameManager.return_to_game_after_shop:
		GameManager.return_to_game_after_shop = false
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
