extends CanvasLayer

## HUD de la partida: nivel, puntuación, monedas, combo y tiempo restante.

## El grupo es para que el diálogo lo pueda esconder mientras habla, sin
## tener que conocer la ruta del nodo ni depender de que exista (los
## diálogos también corren en la intro y en el mapa, donde no hay HUD).
const GRUPO := "hud"

@onready var level_label: Label = $TopBar/LevelLabel
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var coins_label: Label = $TopBar/CoinsLabel
@onready var combo_label: Label = $UnderBar/ComboLabel
@onready var time_label: Label = $TopBar/TimeLabel

func _ready() -> void:
	add_to_group(GRUPO)

func set_level_label(level: int, chapter_name: String) -> void:
	level_label.text = "Nivel %d · %s" % [level, chapter_name]

func set_score(value: int) -> void:
	score_label.text = str(value)

func set_coins(value: int) -> void:
	coins_label.text = str(value)

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
# Las dos vidas van en un panel ABAJO, con el número exacto debajo de
# cada barra. Antes eran barras verticales a los costados y antes de eso
# horizontales arriba y abajo; con el número a la vista se entiende
# cuánto falta de verdad, y permite que la vida crezca (Sofía arranca con
# 1000 y la sube en la tienda) sin que la barra deje de decir nada.

@onready var boss_box: VBoxContainer = $UnderBar/BossBox
@onready var boss_name_label: Label = $UnderBar/BossBox/BossName
@onready var boss_bar: ProgressBar = $UnderBar/BossBox/BossBar
@onready var announce_label: Label = $UnderBar/Announce
@onready var bottom_bars: Control = $BottomBars
@onready var boss_fill: ProgressBar = $BottomBars/BossFill
@onready var boss_value: Label = $BottomBars/BossValue
@onready var boss_title: Label = $BottomBars/BossTitle
@onready var player_fill: ProgressBar = $BottomBars/PlayerFill
@onready var player_value: Label = $BottomBars/PlayerValue
@onready var powers_box: VBoxContainer = $PowersBox
@onready var damage_flash: ColorRect = $DamageFlash

var _announce_timer: float = 0.0

func setup_boss_bars(max_hp: int, boss_name: String) -> void:
	# El nombre del jefe sigue arriba; las barras viejas quedan ocultas.
	boss_box.visible = true
	boss_bar.visible = false
	bottom_bars.visible = true
	boss_name_label.text = boss_name

	# En la placa de abajo no entra el nombre completo, así que va la
	# primera palabra; el nombre entero se lee arriba.
	boss_title.text = "VIDA " + boss_name.split(" ")[0].to_upper()
	set_player_hp(max_hp, max_hp)

func set_boss_hp(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	_update_bar(boss_fill, boss_value, current, maximum)
	var tween := create_tween()
	tween.tween_property(boss_bar, "value", (float(current) / float(maximum)) * 100.0, 0.2)

## Cuando el jefe está protegido (minions vivos o escudo levantado), la
## barra se pone azul: es la señal de que pegarle ahí no sirve.
func set_boss_shield(active: bool) -> void:
	for bar: ProgressBar in [boss_bar, boss_fill]:
		var style: StyleBox = bar.get_theme_stylebox("fill")
		if style is StyleBoxFlat:
			var box: StyleBoxFlat = style.duplicate()
			box.bg_color = Color(0.35, 0.6, 0.95) if active else Color(0.85, 0.2, 0.25)
			bar.add_theme_stylebox_override("fill", box)

func set_player_hp(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	_update_bar(player_fill, player_value, current, maximum)

## Mueve la barra y escribe el número. Los miles van con punto: "2.500"
## se lee de un vistazo y "2500" no.
func _update_bar(bar: ProgressBar, label: Label, current: int, maximum: int) -> void:
	var pct := (float(current) / float(maximum)) * 100.0
	var tween := create_tween()
	tween.tween_property(bar, "value", pct, 0.18)
	label.text = "%s / %s" % [_thousands(current), _thousands(maximum)]

func _thousands(value: int) -> String:
	var digits := str(maxi(value, 0))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out

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


# --- Poderes activos ---
#
# Un botón por poder comprado, apilados abajo a la derecha: lejos de
# donde camina Sofía, para no taparla ni robarle taps al juego. Los que
# no comprás no ocupan lugar.

signal power_pressed(power_id: String)

var _power_buttons: Dictionary = {}

func setup_powers(power_ids: Array) -> void:
	for child in powers_box.get_children():
		child.queue_free()
	_power_buttons.clear()

	for power_id in power_ids:
		var button := Button.new()
		button.custom_minimum_size = Vector2(92, 62)
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_constant_override("outline_size", 5)
		button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		button.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
		UITheme.style_wood_button(button)
		button.pressed.connect(_on_power_pressed.bind(power_id))
		# El precio va EN el botón: hay que poder decidir si conviene
		# gastarlo sin dejar de mirar la pantalla.
		button.text = "%s\n%d" % [
			ItemSystem.get_power_label(power_id),
			ItemSystem.get_power_use_cost(power_id),
		]
		powers_box.add_child(button)
		_power_buttons[power_id] = button

## Apaga los poderes que no te alcanzan. Se llama cada vez que cambian
## las monedas, así el botón nunca miente sobre si podés usarlo.
func refresh_power_affordability(coins: int) -> void:
	for power_id in _power_buttons.keys():
		var button: Button = _power_buttons[power_id]
		button.disabled = coins < ItemSystem.get_power_use_cost(power_id)

func _on_power_pressed(power_id: String) -> void:
	power_pressed.emit(power_id)
