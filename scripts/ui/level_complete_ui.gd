extends CanvasLayer

signal next_level_pressed
signal menu_pressed
signal retry_pressed

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

func show_results(score: int, combo_max: int, reward: int) -> void:
	title_label.text = "¡Nivel Completado!"
	score_value.text = "Puntos: %d" % score
	combo_value.text = "Mejor combo: x%d" % combo_max
	reward_value.text = "Monedas ganadas: +%d 🪙" % reward
	next_button.text = "Siguiente Nivel"
	next_button.visible = true
	visible = true

## Derrota en una pelea de jefe. El botón de "siguiente" se convierte en
## "reintentar", y desaparece si ya no quedan vidas: sin vidas no se puede
## reintentar hasta que regeneren o se paguen.
func show_defeat(reason: String, lives_left: int) -> void:
	title_label.text = "Te ganó el jefe"
	score_value.text = reason
	combo_value.text = "Vidas: %s" % ("❤".repeat(lives_left) if lives_left > 0 else "sin vidas")
	if lives_left > 0:
		reward_value.text = "Podés reintentar la pelea"
		next_button.text = "Reintentar"
		next_button.visible = true
	else:
		reward_value.text = "Se te acabaron las vidas.\nRegeneran solas, o las recargás en el menú."
		next_button.visible = false
	visible = true
