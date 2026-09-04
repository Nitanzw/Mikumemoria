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

const GRID_COLUMNS := 4
const TILE := Vector2(114, 156)

## Alto de la barrita de nivel de cada casillero.
const BAR_HEIGHT := 18.0
const BAR_TRACK_TEX := "res://assets/sprites/ui/bar_track.png"
const BAR_FILL_TEX := "res://assets/sprites/ui/bar_fill.png"
const BAR_FULL_TEX := "res://assets/sprites/ui/bar_fill_gold.png"
## Los extremos redondeados no se pueden estirar: el 9-slice deja las
## puntas fijas y estira sólo el tramo del medio.
const BAR_CAP := 30
## Cuánto entra la ranura respecto del borde del track.
const GROOVE_INSET_X := 13.0
const GROOVE_INSET_Y := 4.0
const COIN_ICON := "res://assets/sprites/ui/coin.png"

func _ready() -> void:
	header.add_theme_stylebox_override("panel", UITheme.scrim_style(0.55))
	UITheme.style_title(title, 30)
	UITheme.style_wood_button(back_button)

	back_button.text = tr("Volver al nivel") if GameManager.return_to_game_after_shop else tr("Volver")
	back_button.pressed.connect(_on_back_pressed)

	GameManager.coins_changed.connect(func(_v): _refresh())
	_refresh()

func _refresh() -> void:
	for child in coins_holder.get_children():
		child.queue_free()
	coins_holder.add_child(UITheme.build_coin_row(GameManager.player_coins, 24))

	for child in list.get_children():
		child.queue_free()

	_build_grid_view()

## La tienda va SIEMPRE en cuadrícula. Había un botón para alternar con
## una vista de lista, con una tarjeta grande por artículo: ocupaba mucho
## más alto, obligaba a scrollear un montón para ver el catálogo y no
## dejaba comparar dos armas de un vistazo. La ficha con la descripción no
## se perdió, se abre tocando el artículo — que es donde se la busca.
##
## Cuadrícula: sólo íconos, con la barra de nivel y el precio abajo.
func _build_grid_view() -> void:
	_build_premium()
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

## Sección premium: monedas gratis por anuncio y las compras de plata
## de verdad. Va PRIMERA, arriba de las armas.
##
## Va primera y no escondida en un botón aparte porque el que nunca pensó
## en pagar tiene que verlo sin buscarlo; y arriba del todo está el
## anuncio que da monedas gratis, no la compra: la tienda tiene que
## ofrecerle algo al que no puede pagar, si no la única lectura posible
## es "acá vengo a que me saquen plata".
func _build_premium() -> void:
	list.add_child(_build_section("Premium"))

	if Store.can_watch_rewarded():
		var gratis := Button.new()
		gratis.custom_minimum_size = Vector2(0, 58)
		gratis.text = tr("Ver anuncio: +%d monedas") % Store.REWARDED_COINS
		gratis.add_theme_font_size_override("font_size", 20)
		gratis.focus_mode = Control.FOCUS_NONE
		UITheme.style_wood_button(gratis, Color(1.12, 1.24, 0.86))
		gratis.pressed.connect(func():
			AdsService.mostrar_con_premio(self, tr("Monedas gratis"), func():
				GameManager.add_coins_and_save(Store.REWARDED_COINS)
				AudioManager.play_sfx("unlock")
				_refresh()))
		list.add_child(gratis)

	for id in IapData.permanentes():
		list.add_child(_build_premium_card(id))
	for id in IapData.packs_monedas():
		list.add_child(_build_premium_card(id))

func _build_premium_card(id: String) -> Control:
	var datos := IapData.datos(id)
	var comprado: bool = IapData.es_permanente(id) and Store.has(id)

	var tarjeta := PanelContainer.new()
	tarjeta.add_theme_stylebox_override("panel", UITheme.card_style())

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	tarjeta.add_child(fila)

	var icono_path: String = str(datos.get("icono", ""))
	if icono_path != "" and ResourceLoader.exists(icono_path):
		fila.add_child(UITheme.icon_rect(icono_path, 56.0))

	var texto := VBoxContainer.new()
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.add_theme_constant_override("separation", 2)
	fila.add_child(texto)

	var titulo := Label.new()
	titulo.text = str(datos.get("titulo", id))
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_title(titulo, 20)
	texto.add_child(titulo)

	var detalle := Label.new()
	if datos.has("monedas"):
		detalle.text = tr("%s monedas") % str(int(datos["monedas"]))
		if datos.has("extra"):
			detalle.text += " · " + str(datos["extra"])
	else:
		detalle.text = str(datos.get("detalle", ""))
	detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(detalle, 15)
	texto.add_child(detalle)

	var boton := Button.new()
	boton.custom_minimum_size = Vector2(112, 54)
	# Sin esto el botón se estira a lo alto de toda la tarjeta y queda un
	# bloque naranja gigante al lado de tres renglones de texto.
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton.add_theme_font_size_override("font_size", 17)
	boton.focus_mode = Control.FOCUS_NONE
	boton.text = tr("Comprado") if comprado else IapData.precio(id)
	boton.disabled = comprado
	UITheme.style_wood_button(boton, Color(0.9, 0.9, 0.9) if comprado else Color(1.2, 1.05, 0.7))
	if not comprado:
		boton.pressed.connect(func(): BillingService.comprar(self, id, _refresh))
	fila.add_child(boton)

	return tarjeta

func _build_grid(ids: Array, are_weapons: bool) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for item_id in ids:
		grid.add_child(_build_tile(item_id, are_weapons))
	return grid

## Casillero de la cuadrícula: ícono, nivel, barra de progreso y precio
## con la moneda. La barra es lo que hace que el avance se lea de un
## vistazo — con 10 niveles por artículo, "3/10" en texto chico no
## alcanza para ver de un barrido en qué estás cerca de completar.
func _build_tile(item_id: String, is_weapon: bool) -> Control:
	var info := _tile_info(item_id, is_weapon)

	# Panel y no Button: un Button se come el arrastre y la cuadrícula solo
	# se podía deslizar tocando los huecos entre casilleros. Ver
	# UITheme.make_tappable.
	var button := Panel.new()
	button.custom_minimum_size = TILE
	button.add_theme_stylebox_override("panel", UITheme.card_style())
	UITheme.make_tappable(button, _show_detail.bind(item_id, is_weapon))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6.0
	box.offset_right = -6.0
	box.offset_top = 6.0
	box.offset_bottom = -15.0
	box.add_theme_constant_override("separation", 3)
	button.add_child(box)

	var icon := TextureRect.new()
	var path: String = _icon_path(item_id, is_weapon)
	if path != "" and ResourceLoader.exists(path):
		icon.texture = load(path)
	icon.custom_minimum_size = Vector2(0, 50)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lo bloqueado se apaga: se distingue sin tener que leer el candado.
	if info["locked"]:
		icon.modulate = Color(0.5, 0.46, 0.42)
	box.add_child(icon)

	var level_label := Label.new()
	level_label.text = info["level_text"]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_body(level_label, 13)
	level_label.add_theme_color_override("font_color", info["level_color"])
	box.add_child(level_label)

	# Precio con la moneda al lado. Un número suelto no dice si es plata
	# o si es el nivel; con el ícono se lee de una.
	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 4)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if int(info["cost"]) > 0 and ResourceLoader.exists(COIN_ICON):
		var coin := TextureRect.new()
		coin.texture = load(COIN_ICON)
		coin.custom_minimum_size = Vector2(15, 15)
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.add_child(coin)
	var cost_label := Label.new()
	cost_label.text = str(info["cost_text"])
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_body(cost_label, 14)
	cost_label.add_theme_color_override("font_color", info["cost_color"])
	cost_row.add_child(cost_label)
	box.add_child(cost_row)

	box.add_child(_level_bar(int(info["level"]), int(info["max_level"])))

	if info["locked"]:
		button.add_child(_lock_badge())
	return button

## Candado en la esquina, encima del casillero. Va como hijo aparte del
## VBox para poder posicionarlo libre sin empujar el resto.
func _lock_badge() -> Control:
	var badge: Control = UITheme.icon_rect(UITheme.ICON_LOCK, 26.0)
	if badge == null:
		var texto := Label.new()
		texto.text = "-"
		badge = texto
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -32.0
	badge.offset_top = 6.0
	badge.offset_right = -8.0
	badge.offset_bottom = 34.0
	# El centrado y el estilo de texto son de Label. Cuando el candado
	# pasó de emoji a ícono, esto quedó apuntando a un TextureRect y
	# tiraba un error por cada casillero bloqueado que se dibujaba.
	var texto_badge := badge as Label
	if texto_badge:
		texto_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_body(texto_badge, 20)
	return badge

## Barra de nivel. Se pone dorada al estar completa, que es la señal de
## que ya se puede pasar al siguiente eslabón de la cadena. Antes eran
## dos rectángulos planos dibujados a mano y se veían de plástico; ahora
## son texturas 9-sliceadas, con las puntas redondeadas fijas.
func _level_bar(level: int, max_level: int) -> Control:
	var track := NinePatchRect.new()
	track.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BAR_TRACK_TEX):
		track.texture = load(BAR_TRACK_TEX)
	track.patch_margin_left = BAR_CAP
	track.patch_margin_right = BAR_CAP
	# Un 9-slice no puede dibujarse más angosto que sus dos puntas
	# juntas: con el nivel 1 de 10 el relleno se salía de la ranura por
	# la izquierda. Recortar contra la ranura lo resuelve sin tener que
	# renunciar a las puntas redondeadas.
	track.clip_contents = true
	track.patch_margin_top = 5
	track.patch_margin_bottom = 5

	# El hueco real de la ranura, sin las puntas redondeadas: el relleno
	# vive acá adentro. Sin esto arrancaba sobre la punta izquierda y se
	# veía verde asomando fuera del canal.
	var groove := Control.new()
	groove.mouse_filter = Control.MOUSE_FILTER_IGNORE
	groove.set_anchors_preset(Control.PRESET_FULL_RECT)
	groove.offset_left = GROOVE_INSET_X
	groove.offset_right = -GROOVE_INSET_X
	groove.offset_top = GROOVE_INSET_Y
	groove.offset_bottom = -GROOVE_INSET_Y
	groove.clip_contents = true
	track.add_child(groove)

	if level > 0 and max_level > 0:
		var fill := NinePatchRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture_path := BAR_FULL_TEX if level >= max_level else BAR_FILL_TEX
		if ResourceLoader.exists(texture_path):
			fill.texture = load(texture_path)
		fill.patch_margin_left = 10
		fill.patch_margin_right = 10
		fill.patch_margin_top = 4
		fill.patch_margin_bottom = 4
		fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		fill.anchor_right = clampf(float(level) / float(max_level), 0.0, 1.0)
		fill.offset_left = 0.0
		fill.offset_right = 0.0
		fill.offset_top = 0.0
		fill.offset_bottom = 0.0
		groove.add_child(fill)
	return track

## Todo lo que el casillero necesita mostrar, en un solo lugar, para que
## armas y objetos no tengan dos caminos distintos.
func _tile_info(item_id: String, is_weapon: bool) -> Dictionary:
	var level: int
	var max_level: int
	var cost: int
	var locked: bool
	if is_weapon:
		level = GameManager.get_weapon_level(item_id)
		max_level = WeaponSystem.MAX_LEVEL
		cost = WeaponSystem.get_upgrade_cost(item_id, level)
		locked = not WeaponSystem.is_unlocked(GameManager.weapon_levels, item_id)
	else:
		level = ItemSystem.get_level(GameManager.items, item_id)
		max_level = ItemSystem.get_max_level(item_id)
		cost = ItemSystem.get_cost(GameManager.items, item_id)
		locked = not ItemSystem.is_unlocked(GameManager.items, item_id)

	var cost_text := str(cost)
	var cost_color := Color(1, 0.88, 0.5)
	if locked:
		cost_text = tr("Bloqueado")
		cost_color = Color(0.72, 0.66, 0.6)
		cost = 0
	elif cost < 0:
		cost_text = "Completo"
		cost_color = Color(1, 0.82, 0.35)
		cost = 0
	elif GameManager.player_coins < cost:
		cost_color = Color(0.85, 0.6, 0.5)

	return {
		"level": level,
		"max_level": max_level,
		"cost": cost,
		"cost_text": cost_text,
		"cost_color": cost_color,
		"locked": locked,
		"level_text": tr("Nivel %d/%d") % [level, max_level],
		"level_color": Color(0.72, 0.66, 0.6) if locked else Color(0.96, 0.92, 0.84),
	}

func _icon_path(item_id: String, is_weapon: bool) -> String:
	if is_weapon:
		return str(WeaponSystem.get_weapon_data(item_id).get("sprite", ""))
	return str(ItemSystem.get_item(item_id).get("icon", ""))

	if not ItemSystem.is_unlocked(GameManager.items, item_id):
		return tr("Bloqueado")
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
	close.text = tr("Cerrar")
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
## Encabezado de sección: el título entre dos filetes con una cuenta
## dorada a cada lado. Antes era un Label suelto y las tres secciones se
## leían como una lista larga sin cortes.
func _build_section(title: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(_rule())
	row.add_child(_bead())

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_title(label, 24)
	row.add_child(label)

	row.add_child(_bead())
	row.add_child(_rule())
	return row

## Filete: se estira para llenar lo que sobra a cada lado del título.
func _rule() -> Control:
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0, 4)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.62, 0.44, 0.20, 0.9)
	style.set_corner_radius_all(2)
	style.border_color = Color(0.25, 0.15, 0.05, 0.8)
	style.set_border_width_all(1)
	rule.add_theme_stylebox_override("panel", style)
	return rule

func _bead() -> Control:
	var bead := Panel.new()
	bead.custom_minimum_size = Vector2(10, 10)
	bead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.80, 0.30)
	style.set_corner_radius_all(5)
	style.border_color = Color(0.42, 0.26, 0.06)
	style.set_border_width_all(1)
	bead.add_theme_stylebox_override("panel", style)
	return bead

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
		button.text = tr("Al máximo")
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
	stats.text = tr("Daño %d · Radio %d") % [damage, int(data.get("radius", 50))]
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
		button.text = tr("Al máximo") if equipped else tr("Equipar")
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
		equip_button.text = tr("Equipar")
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
