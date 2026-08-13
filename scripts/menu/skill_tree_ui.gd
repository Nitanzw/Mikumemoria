extends Control

## Árbol de habilidades con 3 ramas (Fuerza, Fortuna, Precisión).
## Cada rama tiene 5 niveles; el costo sube con SkillSystem.

const MAX_TIER := SkillSystem.MAX_TIER

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var coins_label: Label = $Margin/VBox/CoinsLabel
@onready var back_button: Button = $Margin/VBox/BackButton

var skill_system := SkillSystem.new()

func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	GameManager.coins_changed.connect(func(_v): _refresh())
	_refresh()

func _refresh() -> void:
	coins_label.text = "🪙 %d" % GameManager.player_coins

	for child in list.get_children():
		child.queue_free()

	for branch in SkillSystem.BRANCHES.keys():
		list.add_child(_build_row(branch))

func _build_row(branch: String) -> Control:
	var branch_data: Dictionary = SkillSystem.BRANCHES[branch]
	var tier := skill_system.get_tier(GameManager.skill_tree, branch)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "%s — %s (Nivel %d/%d)" % [branch_data.display_name, branch_data.description, tier, MAX_TIER]
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = MAX_TIER
	bar.value = tier
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var button := Button.new()
	button.custom_minimum_size = Vector2(140, 44)

	if tier >= MAX_TIER:
		button.text = "Máximo"
		button.disabled = true
	else:
		var cost := skill_system.get_cost_for_next_tier(GameManager.skill_tree, branch)
		button.text = "Mejorar (%d)" % cost
		button.disabled = GameManager.player_coins < cost
		button.pressed.connect(func():
			if GameManager.purchase_skill(branch):
				AudioManager.play_sfx("unlock")
				_refresh()
		)

	row.add_child(button)
	box.add_child(row)

	return box
