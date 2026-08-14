extends Node2D

## Intro narrativa (estilo "cómic" con diálogo, no ilustraciones fijas):
## se muestra una vez la primera vez que se abre el juego, y se puede
## volver a ver desde el menú principal (botón "Historia", que setea
## GameManager.force_show_story antes de cambiar a esta escena).

const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")

@onready var skip_button: Button = $SkipButton

func _ready() -> void:
	if GameManager.story_seen and not GameManager.force_show_story:
		_go_to_menu()
		return

	GameManager.force_show_story = false
	skip_button.pressed.connect(_go_to_menu)

	var box := DialogueBoxScene.instantiate()
	add_child(box)
	box.finished.connect(_on_dialogue_finished)
	box.show_dialogue(StoryData.INTRO)

func _on_dialogue_finished() -> void:
	GameManager.mark_story_seen()
	_go_to_menu()

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
