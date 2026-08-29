extends CanvasLayer

signal next_level_pressed
signal menu_pressed
signal retry_pressed

## Umbrales de combo para elegir el título y el comentario.
const PERFECT_COMBO := 15
const GOOD_COMBO := 8

const DEFEAT_TITLES := [
	"Esta vez no",
	"Te ganó",
	"Se te escapó",
]

@onready var score_value: Label = $Dim/Panel/VBox/ScoreValue
@onready var combo_value: Label = $Dim/Panel/VBox/ComboValue
@onready var reward_value: Label = $Dim/Panel/VBox/RewardValue
@onready var next_button: Button = $Dim/Panel/VBox/Buttons/NextButton
@onready var menu_button: Button = $Dim/Panel/VBox/Buttons/MenuButton
@onready var title_label: Label = $Dim/Panel/VBox/Title

func _ready() -> void:
	visible = false
	next_button.pressed.connect(_on_next_pressed)
	menu_button.pressed.connect(func(): menu_pressed.emit())

func _on_next_pressed() -> void:
	# El mismo botón sirve para avanzar o reintentar según cómo terminó.
	if next_button.text == "Reintentar":
		retry_pressed.emit()
	else:
		next_level_pressed.emit()

## Títulos de victoria según cómo te fue. Antes era siempre "¡Nivel
## Completado!", que no dice nada y se lee como pantalla de prueba.
## Ahora el juego reacciona a lo que hiciste, con la voz de Sofía.
const WIN_TITLES_PERFECT := [
	"Impecable",
	"Ni uno se escapó",
	"Sin fallar una",
]
const WIN_TITLES_GOOD := [
	"El huerto respira",
	"Zona despejada",
	"Buena mano",
]
const WIN_TITLES_OK := [
	"Salió bien",
	"Ahí está",
	"Uno menos",
]
const WIN_TITLES_BOSS := [
	"Se terminó",
	"Ese no vuelve",
	"Le ganaste",
]

## Comentarios al pie, que cambian con el combo. Le dan aire al panel sin
## agregar información que no exista.
const WIN_NOTES := {
	"perfect": "No erraste ni un golpe. Así se hace.",
	"great": "Cadena larga. Se te está dando.",
	"ok": "Prolijo. Un poco más de racha y volás.",
	"low": "Salió, pero te costó. Encadená más golpes.",
}

func show_results(score: int, combo_max: int, reward: int, was_boss: bool = false) -> void:
	title_label.text = _pick_title(combo_max, was_boss)
	score_value.text = "%d puntos" % score
	combo_value.text = "Racha más larga: x%d" % combo_max
	reward_value.text = "Te llevás %d monedas\n%s" % [reward, _pick_note(combo_max)]
	next_button.text = "Seguir"
	next_button.visible = true
	visible = true

func _pick_title(combo_max: int, was_boss: bool) -> String:
	var pool: Array = WIN_TITLES_OK
	if was_boss:
		pool = WIN_TITLES_BOSS
	elif combo_max >= PERFECT_COMBO:
		pool = WIN_TITLES_PERFECT
	elif combo_max >= GOOD_COMBO:
		pool = WIN_TITLES_GOOD
	return pool[randi() % pool.size()]

func _pick_note(combo_max: int) -> String:
	if combo_max >= PERFECT_COMBO:
		return WIN_NOTES["perfect"]
	if combo_max >= GOOD_COMBO:
		return WIN_NOTES["great"]
	if combo_max >= 3:
		return WIN_NOTES["ok"]
	return WIN_NOTES["low"]

## Derrota en una pelea de jefe. El botón de "siguiente" se convierte en
## "reintentar", y desaparece si ya no quedan vidas: sin vidas no se puede
## reintentar hasta que regeneren o se paguen.
func show_defeat(reason: String, lives_left: int) -> void:
	title_label.text = DEFEAT_TITLES[randi() % DEFEAT_TITLES.size()]
	score_value.text = reason
	combo_value.text = "Vidas: %s" % ("❤".repeat(lives_left) if lives_left > 0 else "sin vidas")
	if lives_left > 0:
		reward_value.text = "Sacudite y volvé a entrar."
		next_button.text = "Otra vez"
		next_button.visible = true
	else:
		reward_value.text = "Te quedaste sin vidas.\nRegeneran solas, o las recargás en el menú."
		next_button.visible = false
	visible = true
