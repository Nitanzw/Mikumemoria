extends CanvasLayer

signal next_level_pressed
signal menu_pressed
## Ir derecho a la tienda desde el resumen: sin esto había que volver al
## menú, entrar a la tienda y rehacer todo el camino hasta el nivel.
signal shop_pressed
signal retry_pressed

## Umbrales de combo para elegir el título y el comentario.
const PERFECT_COMBO := 15
const GOOD_COMBO := 8
## Debajo de esto el cartel dorado de racha no aparece: un "x2" en un
## banner enorme queda ridículo y le saca peso al que sí importa.
const BANNER_COMBO := 5
## Lo que sube el bloque de la placa cuando no hay cartel de racha, para
## que no quede un agujero entre el moño y la madera.
const BANNER_SHIFT := 90.0
## Y lo que sube la nota cuando no hay fila de recompensa (derrota).
const NOTE_SHIFT := 56.0

const DEFEAT_TITLES := [
	"Esta vez no",
	"Te ganó",
	"Se te escapó",
]

@onready var title_label: Label = $Dim/Panel/Title
@onready var combo_banner: NinePatchRect = $Dim/Panel/ComboBanner
@onready var combo_label: Label = $Dim/Panel/ComboLabel
@onready var score_value: Label = $Dim/Panel/Rows/ScoreRow/ScoreValue
@onready var combo_value: Label = $Dim/Panel/Rows/ComboRow/ComboValue
@onready var reward_row: NinePatchRect = $Dim/Panel/Rows/RewardRow
@onready var reward_value: Label = $Dim/Panel/Rows/RewardRow/RewardValue
@onready var note_label: Label = $Dim/Panel/Note
@onready var plaque: NinePatchRect = $Dim/Panel/Plaque
@onready var rows_box: VBoxContainer = $Dim/Panel/Rows
@onready var buttons_box: HBoxContainer = $Dim/Panel/Buttons
@onready var score_icon: TextureRect = $Dim/Panel/Rows/ScoreRow/Icon
@onready var combo_icon: TextureRect = $Dim/Panel/Rows/ComboRow/Icon

## En la derrota las filas dicen otra cosa, así que también cambian los
## íconos: una medalla al lado de "Vidas" no tiene sentido.
const ICON_STAR := preload("res://assets/sprites/ui/hud_star.png")
const ICON_MEDAL := preload("res://assets/sprites/ui/icon_medal.png")
const ICON_HEART := preload("res://assets/sprites/ui/hud_heart_icon.png")
@onready var next_button: Button = $Dim/Panel/Buttons/NextButton
@onready var menu_button: Button = $Dim/Panel/Buttons/MenuButton
@onready var shop_button: Button = $Dim/Panel/Buttons/ShopButton

## Posición original de cada nodo del bloque inferior, para poder subirlo
## y devolverlo sin ir acumulando corrimientos.
var _base_top: Dictionary = {}

func _ready() -> void:
	visible = false
	for node: Control in [plaque, rows_box, note_label, buttons_box]:
		_base_top[node] = node.offset_top
	for button: Button in [menu_button, shop_button, next_button]:
		UITheme.style_wood_button(button)
	next_button.pressed.connect(_on_next_pressed)
	menu_button.pressed.connect(func(): menu_pressed.emit())
	shop_button.pressed.connect(func(): shop_pressed.emit())

## Sube o baja el bloque de la placa entero. Los nodos tienen alto fijo,
## así que mover el borde de arriba y el de abajo lo mismo los traslada.
func _layout(shift: float, note_extra: float) -> void:
	for node: Control in [plaque, rows_box, note_label, buttons_box]:
		var delta: float = shift + (note_extra if node == note_label else 0.0)
		var height: float = node.offset_bottom - node.offset_top
		node.offset_top = _base_top[node] - delta
		node.offset_bottom = node.offset_top + height

func _on_next_pressed() -> void:
	# El mismo botón sirve para avanzar o reintentar según cómo terminó.
	if next_button.text == "Reintentar" or next_button.text == "Otra vez":
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
	# La racha se luce arriba, en el cartel dorado; las filas de abajo
	# quedan para los números que se leen de un vistazo.
	var show_banner := combo_max >= BANNER_COMBO
	combo_banner.visible = show_banner
	combo_label.visible = show_banner
	combo_label.text = "x%d" % combo_max
	_layout(0.0 if show_banner else BANNER_SHIFT, 0.0)
	score_icon.texture = ICON_STAR
	combo_icon.texture = ICON_MEDAL
	score_value.text = "Puntos: %s" % _thousands(score)
	combo_value.text = "Racha más larga: x%d" % combo_max
	reward_row.visible = true
	reward_value.text = "Monedas: +%s" % _thousands(reward)
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
## "reintentar", y desaparece si ya no quedan vidas: sin vidas no se puede
## reintentar hasta que regeneren o se paguen.
func show_defeat(reason: String, lives_left: int) -> void:
	title_label.text = DEFEAT_TITLES[randi() % DEFEAT_TITLES.size()]
	# En una derrota no hay racha que festejar: el cartel dorado se va.
	combo_banner.visible = false
	combo_label.visible = false
	_layout(BANNER_SHIFT, NOTE_SHIFT)
	score_icon.texture = ICON_HEART
	combo_icon.texture = ICON_HEART
	score_value.text = reason
	combo_value.text = "Vidas: %s" % ("❤".repeat(lives_left) if lives_left > 0 else "sin vidas")
	reward_row.visible = false
	shop_button.visible = true
	if lives_left > 0:
		note_label.text = "Sacudite y volvé a entrar.\nPasá por la tienda si querés mejorar algo."
		next_button.text = "Otra vez"
		next_button.visible = true
	else:
		note_label.text = "Te quedaste sin vidas.\nRegeneran solas, o las recargás en el menú."
		next_button.visible = false
	visible = true
