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

## Botón del Modo Extremo. Se arma por código y se mete justo debajo de
## "Jugar": es una segunda puerta de entrada al mismo juego, no una
## opción de configuración, así que va con los otros botones y no en
## Ajustes. Mientras esté bloqueado se ve igual pero apagado y con el
## motivo escrito, que enseña que existe algo más adelante.
var _extreme_button: Button
## Renglón chico debajo del botón con el motivo del candado. Va aparte y
## no dentro del botón porque un Button de una línea con dos renglones
## adentro se desborda del cartel de madera.
var _extreme_hint: Label
const EXTREME_TINT := Color(1.35, 0.52, 0.46)
const EXTREME_TINT_LOCKED := Color(0.72, 0.60, 0.58)

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
	_build_extreme_button()
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

	if _extreme_button:
		# Misma madera que el resto, teñida de rojo: se lee como parte del
		# menú pero avisa sola que no es el modo de siempre.
		var tinte: Color = EXTREME_TINT if not _extreme_button.disabled else EXTREME_TINT_LOCKED
		_extreme_button.add_theme_stylebox_override("normal", _wood_style(wood, tinte))
		_extreme_button.add_theme_stylebox_override("hover", _wood_style(wood, tinte * 1.1))
		_extreme_button.add_theme_stylebox_override("pressed", _wood_style(wood, tinte * 0.85))
		_extreme_button.add_theme_stylebox_override("focus", _wood_style(wood, tinte))
		_extreme_button.add_theme_stylebox_override("disabled", _wood_style(wood, EXTREME_TINT_LOCKED))

func _wood_style(wood: Texture2D, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = wood
	style.modulate_color = tint
	style.texture_margin_left = WOOD_MARGIN
	style.texture_margin_right = WOOD_MARGIN
	style.texture_margin_top = WOOD_MARGIN * 0.5
	style.texture_margin_bottom = WOOD_MARGIN * 0.5
	return style

## Crea el botón del Modo Extremo y lo inserta debajo de "Jugar".
func _build_extreme_button() -> void:
	var padre := play_button.get_parent()
	if not padre:
		return
	_extreme_button = Button.new()
	_extreme_button.custom_minimum_size = play_button.custom_minimum_size
	_extreme_button.size_flags_horizontal = play_button.size_flags_horizontal
	_extreme_button.focus_mode = Control.FOCUS_NONE
	_extreme_button.add_theme_color_override("font_color", Color(1, 0.94, 0.90))
	_extreme_button.add_theme_color_override("font_disabled_color", Color(0.86, 0.80, 0.78, 0.75))
	_extreme_button.pressed.connect(_on_extreme_pressed)
	padre.add_child(_extreme_button)
	padre.move_child(_extreme_button, play_button.get_index() + 1)

	_extreme_hint = Label.new()
	_extreme_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extreme_hint.add_theme_font_size_override("font_size", 16)
	_extreme_hint.add_theme_color_override("font_color", Color(1, 0.86, 0.82, 0.9))
	_extreme_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_extreme_hint.add_theme_constant_override("shadow_offset_y", 2)
	padre.add_child(_extreme_hint)
	padre.move_child(_extreme_hint, _extreme_button.get_index() + 1)

	_refresh_extreme_button()

func _refresh_extreme_button() -> void:
	if not _extreme_button:
		return
	var abierto: bool = GameManager.is_hardcore_unlocked()
	_extreme_button.disabled = not abierto
	_extreme_button.text = tr("Modo Extremo")
	if _extreme_hint:
		# El motivo tiene que estar escrito: un botón gris sin explicación
		# se lee como "roto", no como "todavía no".
		_extreme_hint.text = tr("Se abre en el nivel 100")
		_extreme_hint.visible = not abierto

func _refresh_labels() -> void:
	level_label.text = tr("Nivel %d / 1000") % GameManager.max_level_unlocked
	if GameManager.hardcore:
		# Al volver de una partida extrema el menú sigue en ese modo, y el
		# avance que muestra es el de ESE modo: sin la marca parecería que
		# se perdió el progreso del normal.
		level_label.text += " · " + tr("Extremo")
	collection_label.text = tr("Incógnitos: %d / 100") % GameManager.get_unlocked_insect_count()
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
	lives_label.text = tr("Próxima vida en %02d:%02d") % [int(remaining / 60), remaining % 60]
	_refill_button.text = tr("Llenar vidas por %d") % GameManager.REFILL_LIVES_COST
	# Si no alcanza la plata el botón se apaga en vez de no hacer nada al
	# tocarlo, que se siente como que el juego se colgó.
	_refill_button.disabled = GameManager.player_coins < GameManager.REFILL_LIVES_COST

func _on_refill_pressed() -> void:
	if GameManager.refill_lives_with_coins():
		AudioManager.play_sfx("unlock")
	_refresh_labels()

func _on_play_pressed() -> void:
	# Cada botón entra en su modo: así el jugador nunca arranca un nivel
	# en un modo distinto del que tocó, sin tener que leer ningún estado.
	GameManager.set_hardcore(false)
	get_tree().change_scene_to_file("res://scenes/menu/world_map.tscn")

func _on_extreme_pressed() -> void:
	if not GameManager.is_hardcore_unlocked():
		return
	GameManager.set_hardcore(true)
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
