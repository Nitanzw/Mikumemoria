extends CanvasLayer

signal next_level_pressed
signal menu_pressed
## Ir derecho a la tienda desde el resumen: sin esto había que volver al
## menú, entrar a la tienda y rehacer todo el camino hasta el nivel.
signal shop_pressed
signal retry_pressed

## Umbrales de combo para elegir el título, la medalla y el comentario.
const PERFECT_COMBO := 15
const GOOD_COMBO := 8
## Debajo de esto el cartel dorado de racha no aparece: un "x2" en un
## cartel enorme queda ridículo y le saca peso al que sí importa.
const BANNER_COMBO := 5

## Lo que sube el bloque cuando no hay cartel de racha, para que no quede
## un agujero entre el cartel y la placa.
const BANNER_SHIFT := 100.0
## Alto de una fila más su separación: lo que se encoge la placa por cada
## fila que se esconde.
const ROW_STEP := 56.0

## Verde para el botón que uno busca con el pulgar sin leer. Los otros
## dos quedan en madera, así "Seguir" se distingue de un vistazo.
const NEXT_TINT := Color(0.52, 1.05, 0.55)

@onready var title_label: Label = $Dim/Panel/Title
@onready var title_ribbon: NinePatchRect = $Dim/Panel/TitleRibbon
@onready var combo_banner: NinePatchRect = $Dim/Panel/ComboBanner
@onready var combo_caption: Label = $Dim/Panel/ComboCaption
@onready var combo_label: Label = $Dim/Panel/ComboLabel
@onready var plaque: NinePatchRect = $Dim/Panel/Plaque
@onready var rows_box: VBoxContainer = $Dim/Panel/Rows
@onready var medal_row: NinePatchRect = $Dim/Panel/Rows/MedalRow
@onready var medal_value: Label = $Dim/Panel/Rows/MedalRow/MedalValue
@onready var score_value: Label = $Dim/Panel/Rows/ScoreRow/ScoreValue
@onready var combo_value: Label = $Dim/Panel/Rows/ComboRow/ComboValue
@onready var reward_row: NinePatchRect = $Dim/Panel/Rows/RewardRow
@onready var reward_value: Label = $Dim/Panel/Rows/RewardRow/RewardValue
@onready var note_label: Label = $Dim/Panel/Note
@onready var buttons_box: HBoxContainer = $Dim/Panel/Buttons
@onready var next_button: Button = $Dim/Panel/Buttons/NextButton
@onready var menu_button: Button = $Dim/Panel/Buttons/MenuButton
@onready var shop_button: Button = $Dim/Panel/Buttons/ShopButton
@onready var score_icon: TextureRect = $Dim/Panel/Rows/ScoreRow/Icon
@onready var combo_icon: TextureRect = $Dim/Panel/Rows/ComboRow/Icon

const ICON_STAR := preload("res://assets/sprites/ui/hud_star.png")
const ICON_MEDAL := preload("res://assets/sprites/ui/icon_medal.png")
const ICON_HEART := preload("res://assets/sprites/ui/hud_heart_icon.png")

const DEFEAT_TITLES := [
	"¡ESTA VEZ NO!",
	"¡TE GANÓ!",
	"¡SE TE ESCAPÓ!",
]

## Títulos de victoria según cómo te fue. Antes era siempre "¡Nivel
## Completado!", que no dice nada y se lee como pantalla de prueba.
## Van en mayúscula porque son el cartel del huerto, no una línea de log.
const WIN_TITLES_PERFECT := [
	"¡PERFECCIÓN EN EL HUERTO!",
	"¡NI UNO SE ESCAPÓ!",
	"¡SIN FALLAR UNA!",
]
const WIN_TITLES_GOOD := [
	"¡EL HUERTO RESPIRA!",
	"¡ZONA DESPEJADA!",
	"¡BUENA MANO!",
]
const WIN_TITLES_OK := [
	"¡NIVEL SUPERADO!",
	"¡AHÍ ESTÁ!",
	"¡UNO MENOS!",
]
const WIN_TITLES_BOSS := [
	"¡ESE NO VUELVE!",
	"¡SE TERMINÓ!",
	"¡LE GANASTE!",
]

## La medalla del nivel. Siempre hay una, para que la fila no quede vacía
## y para que se note el salto cuando encadenás más golpes.
const MEDALS := [
	"Medalla de Huerto Perfecto",
	"Medalla de Buena Mano",
	"Medalla de Jardinero",
	"Sin medalla esta vez",
]

## Comentarios al pie, que cambian con el combo. Le dan aire al panel sin
## agregar información que no exista.
const WIN_NOTES := {
	"perfect": "No erraste ni un golpe. ¡Así se hace, maestro jardinero!",
	"great": "Cadena larga. Se te está dando.",
	"ok": "Prolijo. Un poco más de racha y volás.",
	"low": "Salió, pero te costó. Encadená más golpes.",
}

## Posición original de cada nodo, para poder correrlo y devolverlo sin
## ir acumulando corrimientos entre un nivel y el siguiente.
var _base_top: Dictionary = {}

func _ready() -> void:
	visible = false
	for node: Control in _block():
		_base_top[node] = node.offset_top
	UITheme.style_wood_button(menu_button)
	UITheme.style_wood_button(shop_button)
	UITheme.style_wood_button(next_button, NEXT_TINT)
	next_button.pressed.connect(_on_next_pressed)
	menu_button.pressed.connect(func(): menu_pressed.emit())
	shop_button.pressed.connect(func(): shop_pressed.emit())

func _block() -> Array[Control]:
	return [title_ribbon, title_label, plaque, rows_box, note_label, buttons_box]

## Acomoda el panel a lo que se muestra. `shift` sube todo el bloque
## cuando no hay cartel de racha; `hidden_rows` encoge la placa y sube lo
## que va debajo de las filas, así no queda madera vacía.
func _layout(shift: float, hidden_rows: int) -> void:
	var shrink := hidden_rows * ROW_STEP
	for node: Control in _block():
		var height: float = node.offset_bottom - node.offset_top
		node.offset_top = _base_top[node] - shift
		node.offset_bottom = node.offset_top + height
	plaque.offset_bottom -= shrink
	note_label.offset_top -= shrink
	note_label.offset_bottom -= shrink
	buttons_box.offset_top -= shrink
	buttons_box.offset_bottom -= shrink

func _on_next_pressed() -> void:
	# El mismo botón sirve para avanzar o reintentar según cómo terminó.
	if next_button.text == "Otra vez":
		retry_pressed.emit()
	else:
		next_level_pressed.emit()

func show_results(score: int, combo_max: int, reward: int, was_boss: bool = false) -> void:
	title_label.text = _pick_title(combo_max, was_boss)
	# La racha se luce arriba, en el cartel dorado; las filas de abajo
	# quedan para los números que se leen de un vistazo.
	var show_banner := combo_max >= BANNER_COMBO
	combo_banner.visible = show_banner
	combo_caption.visible = show_banner
	combo_label.visible = show_banner
	combo_caption.text = "¡COMBO PERFECTO!" if combo_max >= PERFECT_COMBO else "¡BUENA RACHA!"
	combo_label.text = "x%d" % combo_max
	_layout(0.0 if show_banner else BANNER_SHIFT, 0)

	medal_row.visible = true
	medal_value.text = _pick_medal(combo_max)
	score_icon.texture = ICON_STAR
	combo_icon.texture = ICON_MEDAL
	score_value.text = "Total de Puntos: %s" % _thousands(score)
	combo_value.text = "Racha más Larga: x%d" % combo_max
	reward_row.visible = true
	reward_value.text = "Recompensa: %s Monedas" % _thousands(reward)
	note_label.text = _pick_note(combo_max)
	shop_button.visible = true
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

func _pick_medal(combo_max: int) -> String:
	if combo_max >= PERFECT_COMBO:
		return MEDALS[0]
	if combo_max >= GOOD_COMBO:
		return MEDALS[1]
	if combo_max >= 3:
		return MEDALS[2]
	return MEDALS[3]

func _pick_note(combo_max: int) -> String:
	if combo_max >= PERFECT_COMBO:
		return WIN_NOTES["perfect"]
	if combo_max >= GOOD_COMBO:
		return WIN_NOTES["great"]
	if combo_max >= 3:
		return WIN_NOTES["ok"]
	return WIN_NOTES["low"]

## Separador de miles, igual que en el HUD: "12500" se lee mal de reojo,
## "12.500" no.
func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if value < 0 else "") + out

## Derrota en una pelea de jefe. El botón de "siguiente" se convierte en
## "otra vez", y desaparece si ya no quedan vidas: sin vidas no se puede
## reintentar hasta que regeneren o se paguen.
func show_defeat(reason: String, lives_left: int) -> void:
	title_label.text = DEFEAT_TITLES[randi() % DEFEAT_TITLES.size()]
	# En una derrota no hay racha ni medalla que festejar.
	combo_banner.visible = false
	combo_caption.visible = false
	combo_label.visible = false
	medal_row.visible = false
	reward_row.visible = false
	_layout(BANNER_SHIFT, 2)

	score_icon.texture = ICON_HEART
	combo_icon.texture = ICON_HEART
	score_value.text = reason
	combo_value.text = "Vidas: %s" % ("❤".repeat(lives_left) if lives_left > 0 else "sin vidas")
	shop_button.visible = true
	if lives_left > 0:
		note_label.text = "Sacudite y volvé a entrar.\nPasá por la tienda si querés mejorar algo."
		next_button.text = "Otra vez"
		next_button.visible = true
	else:
		note_label.text = "Te quedaste sin vidas.\nRegeneran solas, o las recargás en el menú."
		next_button.visible = false
	visible = true
