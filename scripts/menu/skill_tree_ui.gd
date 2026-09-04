extends Control

## Árbol de habilidades con 3 ramas (Fuerza, Fortuna, Precisión).
## Cada rama tiene 5 niveles; el costo sube con SkillSystem.
##
## Mismo arreglo de layout que la tienda: antes el título de la rama y el
## botón compartían fila y se salían de la pantalla. Ahora cada rama es
## una tarjeta con el nombre arriba, la barra de progreso en el medio y
## el botón a lo ancho abajo.

const MAX_TIER := SkillSystem.MAX_TIER

## Ícono por rama, para que se distingan de un vistazo sin leer.
const BRANCH_ICONS := {
	"fuerza": "res://assets/sprites/weapons/sarten_hierro.png",
	"fortuna": "res://assets/sprites/ui/coin.png",
	"precision": "res://assets/sprites/weapons/matamoscas_metalico.png",
}

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var title: Label = $Margin/VBox/Header/HeaderVBox/Title
@onready var coins_holder: HBoxContainer = $Margin/VBox/Header/HeaderVBox/CoinsHolder
@onready var header: PanelContainer = $Margin/VBox/Header
@onready var back_button: Button = $Margin/VBox/BackButton

var skill_system := SkillSystem.new()

func _ready() -> void:
	header.add_theme_stylebox_override("panel", UITheme.scrim_style(0.55))
	UITheme.style_title(title, 28)
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

	for branch in SkillSystem.BRANCHES.keys():
		list.add_child(_build_row(branch))

func _build_row(branch: String) -> Control:
	var branch_data: Dictionary = SkillSystem.BRANCHES[branch]
	var tier := skill_system.get_tier(GameManager.skill_tree, branch)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card_style())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)

	var icon_path: String = BRANCH_ICONS.get(branch, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_label := Label.new()
	name_label.text = "%s  ·  %d/%d" % [branch_data.display_name, tier, MAX_TIER]
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(name_label, 22)
	info.add_child(name_label)

	var desc := Label.new()
	desc.text = str(branch_data.description)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_body(desc, 16)
	desc.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	info.add_child(desc)

	top.add_child(info)
	box.add_child(top)

	box.add_child(_build_pips(tier))

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 20)
	UITheme.style_wood_button(button)

	if tier >= MAX_TIER:
		button.text = tr("Al máximo")
		button.disabled = true
	else:
		var cost := skill_system.get_cost_for_next_tier(GameManager.skill_tree, branch)
		button.text = tr("Mejorar · %d") % cost
		button.disabled = GameManager.player_coins < cost
		button.pressed.connect(func():
			if GameManager.purchase_skill(branch):
				AudioManager.play_sfx("unlock")
				_refresh()
		)

	box.add_child(button)
	return card

## 5 casilleros en vez de una barra continua: con solo 5 niveles se lee
## mucho más rápido cuántos faltan.
func _build_pips(tier: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for i in range(MAX_TIER):
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(0, 14)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.78, 0.25) if i < tier else Color(0.20, 0.16, 0.12, 0.75)
		style.corner_radius_top_left = 7
		style.corner_radius_top_right = 7
		style.corner_radius_bottom_left = 7
		style.corner_radius_bottom_right = 7
		if i < tier:
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_color = Color(1, 1, 1, 0.35)
		pip.add_theme_stylebox_override("panel", style)
		row.add_child(pip)
	return row
