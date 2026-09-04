extends Control

## Pantalla de selección de idioma, la primera vez que se abre el juego.
##
## Sale ANTES del menú, y una sola vez: `SettingsManager.language_chosen`
## queda en true al elegir. Después se puede cambiar desde Ajustes.
##
## Cada idioma se muestra escrito EN SU PROPIO IDIOMA. Alguien que instala
## el juego y lo ve en un idioma que no entiende necesita reconocer el
## suyo en la lista, y a "日本語" lo reconoce; a "Japonés" no.

const COLUMNAS := 2
const BOTON := Vector2(0, 62)

@onready var titulo: Label = $Margin/VBox/Titulo
@onready var subtitulo: Label = $Margin/VBox/Subtitulo
@onready var grilla: GridContainer = $Margin/VBox/Scroll/Grilla

var _elegido: String = "en"

## Adónde se va después de elegir: al mismo lugar al que iba el juego
## antes de que esta pantalla existiera.
const SIGUIENTE := "res://scenes/story/story_intro.tscn"

func _ready() -> void:
	# Ya eligió alguna vez: esta pantalla no vuelve a aparecer nunca.
	if SettingsManager.language_chosen:
		get_tree().change_scene_to_file(SIGUIENTE)
		return

	# El idioma del celular arranca marcado: para la mayoría es el que
	# quieren, así que la pantalla se resuelve con un solo toque.
	_elegido = SettingsManager.suggested_language()
	SettingsManager.set_language(_elegido)

	grilla.columns = COLUMNAS
	for code in SettingsManager.LANGUAGES:
		grilla.add_child(_boton(code))
	$Margin/VBox/Confirmar.focus_mode = Control.FOCUS_NONE
	$Margin/VBox/Confirmar.pressed.connect(_confirmar)
	_refrescar()

func _boton(code: String) -> Button:
	var b := Button.new()
	b.text = str(SettingsManager.LANGUAGES[code])
	b.custom_minimum_size = BOTON
	b.add_theme_font_size_override("font_size", 21)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("code", code)
	b.pressed.connect(_on_elegir.bind(code))
	return b

func _on_elegir(code: String) -> void:
	if code == _elegido:
		# Segundo toque sobre el que ya estaba marcado: confirma y entra.
		# Así se puede resolver la pantalla con dos toques sin buscar un
		# botón de "aceptar" que además habría que traducir aparte.
		_confirmar()
		return
	_elegido = code
	# Se aplica al toque para poder VER el idioma antes de confirmarlo.
	SettingsManager.set_language(code)
	AudioManager.play_sfx("unlock")
	_refrescar()

func _refrescar() -> void:
	titulo.text = tr("Elegí tu idioma")
	subtitulo.text = tr("Se puede cambiar después en Ajustes.")
	for hijo in grilla.get_children():
		var b := hijo as Button
		if b == null:
			continue
		var elegido: bool = str(b.get_meta("code")) == _elegido
		UITheme.style_wood_button(b, Color(0.52, 1.05, 0.55) if elegido else Color(1, 1, 1))
	$Margin/VBox/Confirmar.text = tr("Seguir")
	UITheme.style_wood_button($Margin/VBox/Confirmar, Color(0.52, 1.05, 0.55))

func _confirmar() -> void:
	SettingsManager.confirm_language(_elegido)
	get_tree().change_scene_to_file(SIGUIENTE)
