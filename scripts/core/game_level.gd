extends Node2D

## Controlador de la escena de juego: fondo, spawner de insectos, HUD
## y pantalla de fin de nivel. Espera que GameManager.current_level ya
## esté configurado (start_level) antes de entrar a esta escena.

const InsectScene := preload("res://scenes/insect.tscn")
const MysteryBugScene := preload("res://scenes/mystery_bug.tscn")

const MAX_INSECTS_ON_SCREEN := 9
const SPAWN_MARGIN := 60.0

@onready var background: Sprite2D = $Background
@onready var insect_container: Node2D = $InsectContainer
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud = $HUD
@onready var level_complete_ui = $LevelComplete

var level_config: Dictionary = {}
var time_remaining: float = 60.0
var level_ended: bool = false

func _ready() -> void:
	GameManager.start_level(GameManager.current_level)
	level_config = GameManager.get_current_level_config()

	_play_chapter_music()
	_setup_background()

	time_remaining = float(level_config.get("time_limit", 30))
	hud.set_level_label(GameManager.current_level, level_config.get("chapter_name", ""))
	hud.set_time(time_remaining)
	hud.set_score(0)
	hud.set_coins(GameManager.player_coins)
	hud.set_combo(0)

	GameManager.score_changed.connect(hud.set_score)
	GameManager.coins_changed.connect(hud.set_coins)
	GameManager.combo_changed.connect(hud.set_combo)

	level_complete_ui.next_level_pressed.connect(_on_next_level_pressed)
	level_complete_ui.menu_pressed.connect(_on_menu_pressed)

	spawn_timer.wait_time = level_config.get("spawn_rate", 2.0)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

	if level_config.get("has_mystery_bug", false) and not GameManager.has_unlocked_insect(level_config.get("mystery_index", 0)):
		await get_tree().create_timer(1.0).timeout
		if not level_ended:
			_spawn_mystery_bug()

func _process(delta: float) -> void:
	if level_ended:
		return

	time_remaining -= delta
	hud.set_time(max(time_remaining, 0.0))

	if time_remaining <= 0.0:
		_end_level()

func _play_chapter_music() -> void:
	# Cada capítulo puede tener su propio tema (generado con
	# tools/generate_music_suno.py); si todavía no existe, se usa el del
	# capítulo 1 para que nunca falte música de fondo.
	var chapter_track := "level_theme_%d" % GameManager.current_chapter
	if AudioManager.has_music(chapter_track):
		AudioManager.play_music(chapter_track)
	else:
		AudioManager.play_music("level_theme_1")

func _setup_background() -> void:
	var path: String = level_config.get("background", "")
	if background and path != "" and ResourceLoader.exists(path):
		background.texture = load(path)

func _on_spawn_timer_timeout() -> void:
	if level_ended:
		return
	if insect_container.get_child_count() >= MAX_INSECTS_ON_SCREEN:
		return
	_spawn_random_insect()

func _spawn_random_insect() -> void:
	var types: Array = level_config.get("enemy_types", [])
	if types.is_empty():
		types = ["hormiga_obrera"]

	var insect_type: String = types[randi() % types.size()]
	var insect := InsectScene.instantiate() as Insect
	insect.insect_type = insect_type
	insect.speed_mult = level_config.get("enemy_speed_mult", 1.0)

	insect_container.add_child(insect)
	var spawn_pos := _random_edge_position()
	insect.global_position = spawn_pos
	insect.direction = (_screen_center() - spawn_pos).normalized()

func _spawn_mystery_bug() -> void:
	var bug := MysteryBugScene.instantiate() as MysteryBug
	insect_container.add_child(bug)
	bug.global_position = _screen_center()

func _random_edge_position() -> Vector2:
	var size := get_viewport_rect().size
	var edge := randi() % 4
	match edge:
		0:
			return Vector2(randf_range(0.0, size.x), -SPAWN_MARGIN)
		1:
			return Vector2(size.x + SPAWN_MARGIN, randf_range(0.0, size.y))
		2:
			return Vector2(randf_range(0.0, size.x), size.y + SPAWN_MARGIN)
		_:
			return Vector2(-SPAWN_MARGIN, randf_range(0.0, size.y))

func _screen_center() -> Vector2:
	return get_viewport_rect().size / 2.0

func _end_level() -> void:
	level_ended = true
	spawn_timer.stop()

	for insect in insect_container.get_children():
		insect.queue_free()

	AudioManager.play_sfx("level_complete")
	var reward := GameManager.on_level_complete()
	level_complete_ui.show_results(GameManager.player_score, GameManager.combo_max, reward)

func _on_next_level_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
