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
## Fila de corazones y botón de recarga, armados con arte propio. Se
## construyen por código y se insertan alrededor del label viejo.
var _hearts_row: HBoxContainer
var _refill_button: Button

const HEART_FULL := preload("res://assets/sprites/ui/ui_corazon.png")
const HEART_EMPTY := preload("res://assets/sprites/ui/ui_corazon_vacio.png")
const HEART_SIZE := 34
@onready var logo: TextureRect = $Margin/VBox/Logo
@onready var play_button: Button = $Margin/VBox/Buttons/PlayButton
@onready var shop_button: Button = $Margin/VBox/Buttons/ShopButton
@onready var skills_button: Button = $Margin/VBox/Buttons/SkillsButton
@onready var story_button: Button = $Margin/VBox/Buttons/StoryButton
@onready var settings_button: Button = $Margin/VBox/Buttons/SettingsButton

var _logo_phase: float = 0.0
## Cada cuánto se refresca el texto de vidas, para que la cuenta regresiva
## de la próxima vida avance sola sin recalcular en cada frame.
const LIVES_REFRESH_INTERVAL := 1.0
var _lives_refresh: float = 0.0

func _ready() -> void:
	AudioManager.play_music("menu_theme")
	# La fila de vidas se arma ANTES del primer refresco: _refresh_lives
	# escribe en los nodos que crea esta función.
	_build_lives_row()
	_refresh_labels()
	_style_buttons()

	play_button.pressed.connect(_on_play_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	skills_button.pressed.connect(_on_skills_pressed)
	story_button.pressed.connect(_on_story_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

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
	for button in [play_button, shop_button, skills_button, story_button, settings_button]:
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

## Arma la fila de corazones y el botón de recarga.
##
## Antes esto era UN solo Label con todo adentro: los corazones, el reloj
## y "(tocá para recargar: 150 monedas)". Sin ajuste de línea y centrado,
## al quedarte sin vidas el texto se salía de la pantalla POR LOS DOS
## LADOS: no se leía ni el corazón de la izquierda ni el precio de la
## derecha. Y encima los corazones y la moneda eran emoji del sistema,
## que se dibujan con la fuente del celular y no pegan con nada del resto.
##
## Ahora son tres cosas separadas: corazones de arte propio, el reloj como
## texto solo, y la recarga como BOTÓN. Que sea botón además arregla algo
## que no era visual: un texto que dice "tocá para recargar" no se ve
## tocable, y había que saberlo de antes.
func _build_lives_row() -> void:
	var padre := lives_label.get_parent()
	var indice := lives_label.get_index()

	_hearts_row = HBoxContainer.new()
	_hearts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hearts_row.add_theme_constant_override("separation", 4)
	_hearts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(GameManager.MAX_LIVES):
		var corazon := TextureRect.new()
		corazon.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
		corazon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		corazon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corazon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hearts_row.add_child(corazon)
	padre.add_child(_hearts_row)
	padre.move_child(_hearts_row, indice)

	_refill_button = Button.new()
	_refill_button.custom_minimum_size = Vector2(0, 44)
	_refill_button.add_theme_font_size_override("font_size", 17)
	_refill_button.focus_mode = Control.FOCUS_NONE
	# La moneda va en el `icon` del Button, que la pone a la izquierda del
	# texto. Acá sí sirve esa propiedad (a diferencia del botón de mute,
	# donde el ícono tenía que ocupar todo el botón).
	if ResourceLoader.exists(UITheme.COIN_ICON):
		_refill_button.icon = load(UITheme.COIN_ICON)
		_refill_button.add_theme_constant_override("h_separation", 8)
		# `icon_max_width` y NO `expand_icon`: la moneda es de 128px y
		# expand_icon la estira a lo que dé el botón, que la tapaba. Esta
		# constante la limita respetando la proporción.
		_refill_button.add_theme_constant_override("icon_max_width", 24)
	UITheme.style_wood_button(_refill_button)
	_refill_button.pressed.connect(_on_refill_pressed)
	padre.add_child(_refill_button)
	padre.move_child(_refill_button, indice + 2)

	# El label viejo queda, pero sólo con el reloj.
	lives_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_lives() -> void:
	var lives := GameManager.get_lives()
	if _hearts_row:
		for i in range(_hearts_row.get_child_count()):
			var corazon := _hearts_row.get_child(i) as TextureRect
			corazon.texture = HEART_FULL if i < lives else HEART_EMPTY

	var completas := lives >= GameManager.MAX_LIVES
	lives_label.visible = not completas
	if _refill_button:
		_refill_button.visible = not completas
	if completas:
		return

	var remaining := GameManager.seconds_until_next_life()
	lives_label.text = "Próxima vida en %02d:%02d" % [int(remaining / 60), remaining % 60]
	_refill_button.text = "Llenar vidas por %d" % GameManager.REFILL_LIVES_COST
	# Si no alcanza la plata el botón se apaga en vez de no hacer nada al
	# tocarlo, que se siente como que el juego se colgó.
	_refill_button.disabled = GameManager.player_coins < GameManager.REFILL_LIVES_COST

func _on_refill_pressed() -> void:
	if GameManager.refill_lives_with_coins():
		AudioManager.play_sfx("unlock")
	_refresh_labels()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/world_map.tscn")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/shop.tscn")

func _on_skills_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/skill_tree.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/settings.tscn")

func _on_story_pressed() -> void:
	GameManager.force_show_story = true
	get_tree().change_scene_to_file("res://scenes/story/story_intro.tscn")
