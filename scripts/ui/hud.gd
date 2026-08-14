extends CanvasLayer

## HUD de la partida: nivel, puntuación, monedas, combo y tiempo restante.

@onready var level_label: Label = $Margin/VBox/LevelLabel
@onready var score_label: Label = $Margin/VBox/TopRow/ScoreLabel
@onready var coins_label: Label = $Margin/VBox/TopRow/CoinsLabel
@onready var combo_label: Label = $Margin/VBox/ComboLabel
@onready var time_label: Label = $Margin/VBox/TimeLabel

func set_level_label(level: int, chapter_name: String) -> void:
	level_label.text = "Nivel %d - %s" % [level, chapter_name]

func set_score(value: int) -> void:
	score_label.text = "Puntos: %d" % value

func set_coins(value: int) -> void:
	coins_label.text = "🪙 %d" % value

func set_combo(value: int) -> void:
	if value >= 2:
		combo_label.text = "Combo x%d" % value
		combo_label.visible = true
	else:
		combo_label.visible = false

func set_time(seconds: float) -> void:
	var total := int(ceil(seconds))
	time_label.text = "%02d:%02d" % [total / 60, total % 60]
