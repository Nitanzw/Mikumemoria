extends CanvasLayer

## HUD de la partida: nivel, puntuación, monedas, combo y tiempo restante.

@onready var level_label: Label = $Margin/TopPanel/VBox/LevelLabel
@onready var score_label: Label = $Margin/TopPanel/VBox/TopRow/ScoreLabel
@onready var coins_label: Label = $Margin/TopPanel/VBox/TopRow/CoinsLabel
@onready var combo_label: Label = $Margin/TopPanel/VBox/ComboLabel
@onready var time_label: Label = $Margin/TopPanel/VBox/TimeLabel

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

# --- Pelea de jefe ---
#
# Las dos barras solo se muestran en niveles de jefe: en un nivel normal
# no hay nada que perder, así que ocuparían pantalla al pedo.
#
# Van **verticales, pegadas a los costados**: la de Sofía a la izquierda
# y la del jefe a la derecha. Antes estaban horizontales arriba y abajo,
# comiéndose el alto de una pantalla de celular justo donde pasa la
# acción. A los costados quedan siempre visibles sin tapar nada.

@onready var boss_box: VBoxContainer = $Margin/TopPanel/VBox/BossBox
@onready var boss_name_label: Label = $Margin/TopPanel/VBox/BossBox/BossName
@onready var boss_bar: ProgressBar = $Margin/TopPanel/VBox/BossBox/BossBar
@onready var announce_label: Label = $Margin/TopPanel/VBox/Announce
@onready var player_hp_box: VBoxContainer = $Margin/PlayerHPBox
@onready var player_bar: ProgressBar = $Margin/PlayerHPBox/PlayerBar
@onready var side_bars: Control = $SideBars
@onready var boss_side: ProgressBar = $SideBars/BossSide
@onready var boss_side_label: Label = $SideBars/BossSideLabel
@onready var player_side: ProgressBar = $SideBars/PlayerSide
@onready var damage_flash: ColorRect = $DamageFlash

var _announce_timer: float = 0.0

func setup_boss_bars(max_hp: int, boss_name: String) -> void:
	# El nombre del jefe sigue arriba, en el panel; las barras van al
	# costado. Las horizontales viejas quedan ocultas.
	boss_box.visible = true
	boss_bar.visible = false
	player_hp_box.visible = false
	side_bars.visible = true
	boss_name_label.text = boss_name

	# El nombre completo no entra en la etiqueta finita del costado, así
	# que ahí va solo la primera palabra.
	boss_side_label.text = boss_name.split(" ")[0]

	for bar: ProgressBar in [boss_bar, boss_side]:
		bar.max_value = 100.0
		bar.value = 100.0
	set_player_hp(max_hp, max_hp)

func set_boss_hp(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	var pct := (float(current) / float(maximum)) * 100.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(boss_bar, "value", pct, 0.2)
	tween.tween_property(boss_side, "value", pct, 0.2)

## Cuando el jefe está protegido (minions vivos o escudo levantado), la
## barra se pone azul: es la señal de que pegarle ahí no sirve.
func set_boss_shield(active: bool) -> void:
	# `bar` sale del array sin tipo, así que get_theme_stylebox devuelve
	# Variant y hay que declarar el tipo a mano.
	for bar: ProgressBar in [boss_bar, boss_side]:
		var style: StyleBox = bar.get_theme_stylebox("fill")
		if style is StyleBoxFlat:
			var box: StyleBoxFlat = style.duplicate()
			box.bg_color = Color(0.35, 0.6, 0.95) if active else Color(0.85, 0.2, 0.25)
			bar.add_theme_stylebox_override("fill", box)

func set_player_hp(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	var pct := (float(current) / float(maximum)) * 100.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_bar, "value", pct, 0.15)
	tween.tween_property(player_side, "value", pct, 0.15)

func announce(text: String) -> void:
	if text == "":
		return
	announce_label.text = text
	announce_label.visible = true
	announce_label.modulate.a = 1.0
	_announce_timer = 2.4

func flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(damage_flash, "color", Color(1, 0, 0, 0.35), 0.06)
	tween.tween_property(damage_flash, "color", Color(1, 0, 0, 0.0), 0.28)

func _process(delta: float) -> void:
	if _announce_timer <= 0.0:
		return
	_announce_timer -= delta
	if _announce_timer <= 0.6:
		announce_label.modulate.a = maxf(_announce_timer / 0.6, 0.0)
	if _announce_timer <= 0.0:
		announce_label.visible = false
