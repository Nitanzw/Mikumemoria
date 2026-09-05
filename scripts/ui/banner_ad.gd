class_name BannerAd
extends RefCounted

## BANNER DE ABAJO. La franja de publicidad permanente de la versión
## gratis: siempre a la vista, y se va sólo si el jugador paga.
##
## Lo importante de un banner no es mostrarlo: es RESERVARLE EL LUGAR. El
## banner de AdMob no es un nodo de Godot, es una vista de Android que se
## dibuja ENCIMA de la pantalla del juego. Si el juego no le deja el
## espacio libre, el banner le tapa lo que haya abajo — que acá son los
## pies de Sofía, la barra de vida en las peleas y el botón de "Volver" de
## todos los menús. Y un botón tapado por un anuncio es un toque
## accidental, que además de arruinar la partida es motivo de baneo de la
## cuenta de AdMob.
##
## Por eso esto tiene dos partes:
##   1. `alto()`, que dice cuánto hay que correr todo para arriba;
##   2. `mostrar()`, que dibuja la franja simulada en ese lugar, para
##      poder VER que el espacio quedó bien reservado antes de tener
##      AdMob de verdad.
##
## Cuando se enchufe AdMob, `mostrar()` pasa a pedirle el banner al
## plugin y listo: el espacio ya está reservado y no hay que tocar ni una
## pantalla más.

## Alto del banner estándar de AdMob, en dp.
const BANNER_DP := 50.0
## Topes en píxeles del viewport, para que un celular con un DPI raro no
## se coma media pantalla ni deje una franja de nada.
const ALTO_MIN := 58.0
const ALTO_MAX := 120.0
## Aire entre el banner y lo que queda justo arriba.
const AIRE := 6.0

const NOMBRE_CAPA := "BannerPublicidad"
## Meta donde se recuerda el margen original, para poder volver a
## calcular sin ir sumando de a poco en cada llamada.
const META_BASE := "_margen_sin_banner"

## Cuánto hay que dejar libre abajo. Cero si el jugador pagó por sacar la
## publicidad: ahí el juego usa la pantalla entera, que es parte de lo
## que compró.
static func alto(nodo: Node) -> float:
	if nodo == null or not is_instance_valid(nodo) or Store.no_ads():
		return 0.0
	var vista := nodo.get_viewport().get_visible_rect().size
	var pantalla := DisplayServer.window_get_size()
	var dpi: float = float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 160.0
	# dp -> píxeles reales de pantalla -> píxeles del viewport.
	var reales: float = BANNER_DP * dpi / 160.0
	var escala: float = vista.y / maxf(float(pantalla.y), 1.0)
	return clampf(reales * escala + AIRE, ALTO_MIN, ALTO_MAX)

## Le suma el alto del banner al margen de abajo de un MarginContainer.
## Es la forma más barata de correr una pantalla entera para arriba: casi
## todas las del juego cuelgan de uno.
static func reservar(margen: MarginContainer) -> void:
	if margen == null:
		return
	var base: int
	if margen.has_meta(META_BASE):
		base = int(margen.get_meta(META_BASE))
	else:
		base = margen.get_theme_constant("margin_bottom")
		margen.set_meta(META_BASE, base)
	# Se recalcula siempre desde el margen original: así llamarla dos
	# veces no acumula, y después de comprar "sin anuncios" el margen
	# vuelve solo a lo que era.
	margen.add_theme_constant_override("margin_bottom", base + int(round(alto(margen))))

## Dibuja la franja del banner. Hoy es un cartel simulado; mañana es el
## banner del plugin, en el mismo lugar.
static func mostrar(nodo: Node) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	var raiz := nodo.get_tree().root
	var vieja := raiz.get_node_or_null(NOMBRE_CAPA)
	if Store.no_ads():
		if vieja:
			vieja.queue_free()
		return
	if vieja:
		return

	print(AdsConfig.aviso("banner", AdsConfig.banner()))
	var franja := alto(nodo) - AIRE
	var capa := CanvasLayer.new()
	capa.name = NOMBRE_CAPA
	# Abajo de los anuncios de pantalla completa (20) y del diálogo (3),
	# arriba del HUD (1): el banner se ve siempre, pero un anuncio de
	# pantalla completa lo tapa, que es lo correcto.
	capa.layer = 5
	raiz.add_child(capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fondo.anchor_top = 1.0
	fondo.anchor_bottom = 1.0
	fondo.offset_top = -franja
	fondo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fondo.color = Color(0.09, 0.10, 0.12, 1.0)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(fondo)

	var texto := Label.new()
	texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.text = "BANNER SIMULADO · 320x50"
	texto.add_theme_font_size_override("font_size", 14)
	texto.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	fondo.add_child(texto)
