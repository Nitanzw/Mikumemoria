extends Control

@onready var level_label: Label = $Margin/VBox/LevelLabel
@onready var collection_label: Label = $Margin/VBox/CollectionLabel
@onready var play_button: Button = $Margin/VBox/PlayButton
@onready var shop_button: Button = $Margin/VBox/ShopButton
@onready var skills_button: Button = $Margin/VBox/SkillsButton
@onready var story_button: Button = $Margin/VBox/StoryButton

func _ready() -> void:
	AudioManager.play_music("menu_theme")
	_refresh_labels()

	play_button.pressed.connect(_on_play_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	skills_button.pressed.connect(_on_skills_pressed)
	story_button.pressed.connect(_on_story_pressed)

func _refresh_labels() -> void:
	level_label.text = "Nivel actual: %d / 1000" % GameManager.current_level
	collection_label.text = "Insectos incógnito descubiertos: %d / 100" % GameManager.get_unlocked_insect_count()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/world_map.tscn")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/shop.tscn")

func _on_skills_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/skill_tree.tscn")

func _on_story_pressed() -> void:
	GameManager.force_show_story = true
	get_tree().change_scene_to_file("res://scenes/story/story_intro.tscn")
