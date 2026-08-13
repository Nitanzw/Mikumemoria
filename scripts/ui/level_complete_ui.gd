extends CanvasLayer

signal next_level_pressed
signal menu_pressed

@onready var score_value: Label = $Dim/Panel/VBox/ScoreValue
@onready var combo_value: Label = $Dim/Panel/VBox/ComboValue
@onready var reward_value: Label = $Dim/Panel/VBox/RewardValue
@onready var next_button: Button = $Dim/Panel/VBox/Buttons/NextButton
@onready var menu_button: Button = $Dim/Panel/VBox/Buttons/MenuButton

func _ready() -> void:
	visible = false
	next_button.pressed.connect(func(): next_level_pressed.emit())
	menu_button.pressed.connect(func(): menu_pressed.emit())

func show_results(score: int, combo_max: int, reward: int) -> void:
	score_value.text = "Puntos: %d" % score
	combo_value.text = "Mejor combo: x%d" % combo_max
	reward_value.text = "Monedas ganadas: +%d 🪙" % reward
	visible = true
