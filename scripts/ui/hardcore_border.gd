extends CanvasLayer

## Aura roja en los bordes de la pantalla mientras se juega en Modo
## Extremo. No es decoración suelta: es lo único que le avisa al jugador,
## sin leer nada, en qué modo está. Late despacio para que se note pero
## no compita con el aura de los bichos élite, que late rápido.
##
## Va en layer 2, arriba del HUD (1) y abajo del cuadro de diálogo (3):
## el borde tiene que enmarcar todo, incluido el HUD, pero no taparle la
## cara a Sofía cuando habla.

## Ancho del degradado, en píxeles de pantalla.
const GROSOR := 46.0
## Cuántas franjas se dibujan para simular el degradado. Con menos se
## ven escalones; con más no cambia nada y cuesta.
const PASOS := 16
const ALPHA_MIN := 0.30
const ALPHA_MAX := 0.55
const PULSO_SPEED := 1.9
const COLOR_BASE := Color(0.90, 0.06, 0.05)

var _fase: float = 0.0

@onready var _marco := Control.new()

func _ready() -> void:
	layer = 2
	_marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marco.draw.connect(_dibujar_marco)
	add_child(_marco)

func _process(delta: float) -> void:
	_fase += delta * PULSO_SPEED
	_marco.queue_redraw()

func _dibujar_marco() -> void:
	var tam := _marco.size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return
	var t: float = (sin(_fase) + 1.0) * 0.5
	var alpha: float = lerpf(ALPHA_MIN, ALPHA_MAX, t)

	# Cada franja es un rectángulo hueco un poco más adentro y un poco
	# más transparente que el anterior. Dibujar rectángulos huecos (con
	# `filled = false`) en vez de rellenos evita repintar el centro de la
	# pantalla 16 veces.
	for i in range(PASOS):
		var avance: float = float(i) / float(PASOS - 1)
		var margen: float = avance * GROSOR
		var a: float = alpha * pow(1.0 - avance, 1.6)
		if a <= 0.004:
			continue
		var color := Color(COLOR_BASE.r, COLOR_BASE.g, COLOR_BASE.b, a)
		var rect := Rect2(margen, margen, tam.x - margen * 2.0, tam.y - margen * 2.0)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		_marco.draw_rect(rect, color, false, GROSOR / float(PASOS) + 1.0)
