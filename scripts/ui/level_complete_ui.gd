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

## Tiempos de la entrada. La pantalla aparecía de golpe, como un cartel
## pegado encima; con el rebote corto se siente parte del juego sin
## hacerte esperar para tocar "Seguir".
const PANEL_POP := 0.30
const ROW_FADE := 0.16
const ROW_STAGGER := 0.06
const COUNT_TIME := 0.55

@onready var dim: ColorRect = $Dim
@onready var panel: Control = $Dim/Panel
@onready var inset: Panel = $Dim/Panel/Inset
@onready var frame: NinePatchRect = $Dim/Panel/Frame
@onready var combo_plate: NinePatchRect = $Dim/Panel/ComboPlate
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
## La animación de entrada en curso, para cortarla si se vuelve a mostrar
## la pantalla antes de que termine (reintento rápido).
var _intro: Tween = null

## Botón de anuncio con premio del resumen. Es el mismo nodo para los
## dos usos, porque nunca conviven: al ganar ofrece duplicar la
## recompensa, al perder sin vidas ofrece una vida para seguir jugando.
##
## Los dos son el mismo negocio: el momento en que el jugador MÁS quiere
## algo es justo cuando acaba de terminar un nivel. Ofrecerle el anuncio
## en cualquier otro lado convierte muchísimo menos.
var _ad_button: Button
## Recompensa del nivel que se está mostrando, para poder duplicarla.
var _reward_shown: int = 0

func _ready() -> void:
	visible = false
	_build_ad_button()
	for node: Control in _block():
		_base_top[node] = node.offset_top
	UITheme.style_wood_button(menu_button)
	UITheme.style_wood_button(shop_button)
	UITheme.style_wood_button(next_button, NEXT_TINT)
	next_button.pressed.connect(_on_next_pressed)
	menu_button.pressed.connect(func(): menu_pressed.emit())
	shop_button.pressed.connect(func(): shop_pressed.emit())

## Se arma por código y no en la escena porque es de la versión gratis:
## así el día que se compile la versión de pago alcanza con que
## `Store.no_ads()` y el resto quede en su lugar, sin tocar el .tscn.
func _build_ad_button() -> void:
	_ad_button = Button.new()
	_ad_button.name = "AdButton"
	_ad_button.anchor_left = 0.5
	_ad_button.anchor_right = 0.5
	_ad_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ad_button.offset_left = -238.0
	_ad_button.offset_right = 238.0
	_ad_button.offset_top = 800.0
	_ad_button.offset_bottom = 858.0
	_ad_button.focus_mode = Control.FOCUS_NONE
	_ad_button.add_theme_font_size_override("font_size", 20)
	_ad_button.visible = false
	UITheme.style_wood_button(_ad_button, Color(1.15, 1.25, 0.85))
	panel.add_child(_ad_button)

func _block() -> Array[Control]:
	return [title_ribbon, title_label, plaque, frame, inset, rows_box, note_label,
		buttons_box, _ad_button]

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
	frame.offset_bottom -= shrink
	inset.offset_bottom -= shrink
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

func show_results(score: int, combo_max: int, reward: int, was_boss: bool = false,
		misses: int = -1) -> void:
	title_label.text = _pick_title(combo_max, was_boss)
	# La racha se luce arriba, en el cartel dorado; las filas de abajo
	# quedan para los números que se leen de un vistazo.
	var show_banner := combo_max >= BANNER_COMBO
	combo_banner.visible = show_banner
	combo_caption.visible = show_banner
	combo_plate.visible = show_banner
	combo_label.visible = show_banner
	combo_caption.text = tr("¡COMBO PERFECTO!") if combo_max >= PERFECT_COMBO else tr("¡BUENA RACHA!")
	combo_label.text = "x%d" % combo_max
	_layout(0.0 if show_banner else BANNER_SHIFT, 0)

	medal_row.visible = true
	medal_value.text = _pick_medal(combo_max)
	score_icon.texture = ICON_STAR
	combo_icon.texture = ICON_MEDAL
	_set_score(score)
	combo_value.text = tr("Racha más Larga: x%d") % combo_max
	reward_row.visible = true
	_set_reward(reward)
	note_label.text = _pick_note(combo_max, misses)
	shop_button.visible = true
	next_button.text = "Seguir"
	next_button.visible = true
	_reward_shown = reward
	_ofrecer_duplicar(reward)
	await _appear()
	# Los números suben desde cero: el puntaje del nivel se siente ganado
	# en vez de aparecer ya escrito.
	var count := create_tween()
	count.set_parallel(true)
	count.tween_method(_set_score, 0, score, COUNT_TIME).set_delay(0.20)
	count.tween_method(_set_reward, 0, reward, COUNT_TIME).set_delay(0.32)

## Ofrece duplicar la recompensa mirando un anuncio.
func _ofrecer_duplicar(reward: int) -> void:
	_desconectar_ad()
	_ad_button.visible = reward > 0 and Store.can_watch_rewarded()
	if not _ad_button.visible:
		return
	_ad_button.text = tr("Ver anuncio: recompensa x2")
	_ad_button.pressed.connect(_on_duplicar_pressed)

func _on_duplicar_pressed() -> void:
	_ad_button.disabled = true
	AdsService.mostrar_con_premio(self, tr("Recompensa doble"), func():
		GameManager.add_coins_and_save(_reward_shown)
		_set_reward(_reward_shown * 2)
		AudioManager.play_sfx("unlock")
		# Se ofrece UNA vez por nivel: si se pudiera repetir, el anuncio
		# dejaría de ser un premio y pasaría a ser la única forma sensata
		# de juntar monedas.
		_ad_button.visible = false)

## Al perder sin vidas: una vida a cambio de un anuncio, para poder
## reintentar en el momento. Es el anuncio que más se mira de todos —
## justo ahí el jugador quiere seguir — y de paso evita el peor final
## posible, que es cerrar el juego porque no queda nada para hacer.
func _ofrecer_vida() -> void:
	_desconectar_ad()
	_ad_button.visible = Store.can_watch_rewarded()
	if not _ad_button.visible:
		return
	_ad_button.text = tr("Ver anuncio: +1 vida")
	_ad_button.pressed.connect(_on_vida_pressed)

func _on_vida_pressed() -> void:
	_ad_button.disabled = true
	AdsService.mostrar_con_premio(self, tr("Una vida más"), func():
		GameManager.add_lives(1)
		AudioManager.play_sfx("unlock")
		_ad_button.visible = false
		combo_value.text = tr("Vidas: %d") % GameManager.get_lives()
		note_label.text = tr("Sacudite y volvé a entrar.")
		next_button.text = "Otra vez"
		next_button.visible = true)

func _desconectar_ad() -> void:
	_ad_button.disabled = false
	for conexion in _ad_button.pressed.get_connections():
		_ad_button.pressed.disconnect(conexion["callable"])

func _set_score(value: int) -> void:
	score_value.text = "Total de Puntos: %s" % _thousands(value)

func _set_reward(value: int) -> void:
	reward_value.text = tr("Recompensa: %s Monedas") % _thousands(value)


## Entrada del panel. Se arranca invisible y se deja pasar un cuadro para
## que el contenedor de filas ya tenga medidas: sin eso los pivotes salen
## en cero y las tiras escalan desde la esquina en vez del centro.
func _appear() -> void:
	if _intro and _intro.is_valid():
		_intro.kill()
	dim.modulate.a = 0.0
	visible = true
	await get_tree().process_frame

	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	var rows: Array[Control] = []
	for row in rows_box.get_children():
		var control := row as Control
		if control == null or not control.visible:
			continue
		control.pivot_offset = control.size / 2.0
		control.scale = Vector2(0.94, 0.94)
		control.modulate.a = 0.0
		rows.append(control)

	var pops: Array[Control] = [combo_banner, combo_caption, combo_plate, combo_label]
	for node in pops:
		node.pivot_offset = node.size / 2.0
		node.scale = Vector2(0.6, 0.6)

	_intro = create_tween()
	_intro.set_parallel(true)
	_intro.tween_property(dim, "modulate:a", 1.0, 0.16)
	_intro.tween_property(panel, "scale", Vector2.ONE, PANEL_POP) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for node in pops:
		_intro.tween_property(node, "scale", Vector2.ONE, PANEL_POP + 0.06) \
			.set_delay(0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var delay := 0.14
	for row in rows:
		_intro.tween_property(row, "modulate:a", 1.0, ROW_FADE).set_delay(delay)
		_intro.tween_property(row, "scale", Vector2.ONE, ROW_FADE + 0.04) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += ROW_STAGGER

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

## `misses` en -1 significa "no me lo pasaron": se cae al criterio viejo,
## por combo. Con el dato real, "no erraste" exige justamente eso.
func _pick_note(combo_max: int, misses: int = -1) -> String:
	# El cartel decía "No erraste ni un golpe" mirando sólo el combo. El
	# combo mide la racha más larga, no los fallos: se podía tapear al
	# aire todo el nivel, encadenar quince al final y que igual te
	# felicitara por no haber errado.
	if combo_max >= PERFECT_COMBO and misses == 0:
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
	combo_plate.visible = false
	combo_label.visible = false
	medal_row.visible = false
	reward_row.visible = false
	_layout(BANNER_SHIFT, 2)

	score_icon.texture = ICON_HEART
	combo_icon.texture = ICON_HEART
	score_value.text = reason
	combo_value.text = (tr("Vidas: %d") % lives_left) if lives_left > 0 else tr("Sin vidas")
	shop_button.visible = true
	_ad_button.visible = false
	if lives_left > 0:
		note_label.text = tr("Sacudite y volvé a entrar.") + "\n" + tr("Pasá por la tienda si querés mejorar algo.")
		next_button.text = "Otra vez"
		next_button.visible = true
	else:
		note_label.text = tr("Te quedaste sin vidas.") + "\n" + tr("Regeneran solas, o las recargás en el menú.")
		next_button.visible = false
		_ofrecer_vida()
	await _appear()
