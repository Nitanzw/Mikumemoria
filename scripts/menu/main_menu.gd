extends Control

## Menú principal: fondo ilustrado del huerto, logo, Sofía saludando y
## botones con textura de cartel de madera.
##
## La madera se aplica por código y no desde el .tscn a propósito: hay un
## solo `button_wood.png` que se reutiliza en los 4 botones, así alcanza
## con cambiar ese archivo para que cambien todos, y el texto de cada
## botón sigue siendo texto (se puede traducir sin tocar el arte).

const WOOD_TEXTURE := "res://assets/sprites/ui/button_wood.png"

# El cartel de madera tiene tornillos en las puntas y un borde tallado:
# si se estirara entero, se deformarían. Con el margen de 9-slice, Godot
# estira solo el centro y deja las puntas intactas.
const WOOD_MARGIN := 46.0

@onready var level_label: Label = $Margin/VBox/Stats/StatsVBox/LevelLabel
@onready var collection_label: Label = $Margin/VBox/Stats/StatsVBox/CollectionLabel
@onready var lives_label: Label = $Margin/VBox/Stats/StatsVBox/LivesLabel
@onready var logo: TextureRect = $Margin/VBox/Logo
@onready var play_button: Button = $Margin/VBox/Buttons/PlayButton
@onready var shop_button: Button = $Margin/VBox/Buttons/ShopButton
@onready var skills_button: Button = $Margin/VBox/Buttons/SkillsButton
@onready var story_button: Button = $Margin/VBox/Buttons/StoryButton

var _logo_phase: float = 0.0
## Cada cuánto se refresca el texto de vidas, para que la cuenta regresiva
## de la próxima vida avance sola sin recalcular en cada frame.
const LIVES_REFRESH_INTERVAL := 1.0
var _lives_refresh: float = 0.0

func _ready() -> void:
	AudioManager.play_music("menu_theme")
	_refresh_labels()
	_style_buttons()

	lives_label.mouse_filter = Control.MOUSE_FILTER_STOP
	lives_label.gui_input.connect(_on_lives_input)

	play_button.pressed.connect(_on_play_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	skills_button.pressed.connect(_on_skills_pressed)
	story_button.pressed.connect(_on_story_pressed)

func _process(delta: float) -> void:
	# El logo flota apenas, para que el menú no se vea congelado.
	_logo_phase += delta * 1.3
	logo.position.y = sin(_logo_phase) * 5.0

	_lives_refresh -= delta
	if _lives_refresh <= 0.0:
		_lives_refresh = LIVES_REFRESH_INTERVAL
		_refresh_lives()

func _style_buttons() -> void:
	if not ResourceLoader.exists(WOOD_TEXTURE):
		return
	var wood: Texture2D = load(WOOD_TEXTURE)
	for button in [play_button, shop_button, skills_button, story_button]:
		button.add_theme_stylebox_override("normal", _wood_style(wood, Color(1, 1, 1)))
		button.add_theme_stylebox_override("hover", _wood_style(wood, Color(1.12, 1.12, 1.12)))
		button.add_theme_stylebox_override("pressed", _wood_style(wood, Color(0.82, 0.82, 0.82)))
		button.add_theme_stylebox_override("focus", _wood_style(wood, Color(1, 1, 1)))

func _wood_style(wood: Texture2D, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = wood
	style.modulate_color = tint
	style.texture_margin_left = WOOD_MARGIN
	style.texture_margin_right = WOOD_MARGIN
	style.texture_margin_top = WOOD_MARGIN * 0.5
	style.texture_margin_bottom = WOOD_MARGIN * 0.5
	return style

func _refresh_labels() -> void:
	level_label.text = "Nivel %d / 1000" % GameManager.max_level_unlocked
	collection_label.text = "Incógnitos: %d / 100" % GameManager.get_unlocked_insect_count()
	_refresh_lives()

## Muestra los corazones y, si faltan, cuánto queda para la próxima. Al
## tocar el texto con vidas incompletas se ofrece recargar con monedas.
func _refresh_lives() -> void:
	var lives := GameManager.get_lives()
	var hearts := "❤".repeat(lives) + "♡".repeat(GameManager.MAX_LIVES - lives)
	if lives >= GameManager.MAX_LIVES:
		lives_label.text = hearts
		return
	var remaining := GameManager.seconds_until_next_life()
	lives_label.text = "%s  próxima en %02d:%02d  (tocá para recargar: %d 🪙)" % [
		hearts, int(remaining / 60), remaining % 60, GameManager.REFILL_LIVES_COST,
	]

func _on_lives_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch and touch.pressed:
		if GameManager.refill_lives_with_coins():
			AudioManager.play_sfx("unlock")
		_refresh_labels()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/world_map.tscn")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/shop.tscn")

func _on_skills_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/skill_tree.tscn")

func _on_story_pressed() -> void:
	GameManager.force_show_story = true
	get_tree().change_scene_to_file("res://scenes/story/story_intro.tscn")
