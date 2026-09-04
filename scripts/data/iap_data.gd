class_name IapData
extends RefCounted

## CATÁLOGO DE COMPRAS DE LA VERSIÓN GRATIS.
##
## Los precios están en dólares y son de referencia: el precio REAL lo
## fija Google Play por país, y es lo que hay que mostrar en pantalla
## cuando esté enchufado el facturador de verdad (ver BillingService).
## Hasta entonces se muestra este, con el cartel de simulado.
##
## Reglas que se siguieron para armar el catálogo, porque son las que
## deciden si esto factura o no:
##
##  - Nada de lo que se compra se puede perder. Un jugador que paga y
##    después ve que "se le gastó" no vuelve a pagar nunca.
##  - Nada de lo que se compra cierra contenido. El que no paga llega
##    igual al nivel 1000: paga por llegar más cómodo, no por llegar.
##  - Un solo paquete "todo incluido" más barato que la suma. Es el que
##    más factura, siempre.
##  - Quitar la publicidad es el más barato de los permanentes: es la
##    puerta de entrada, el que convierte a los que nunca pagaron nada.

## Compras permanentes (no consumibles).
const SIN_ANUNCIOS := "sin_anuncios"
const ARMA_LEGENDARIA := "arma_legendaria"
const RELOJ_ABUELA := "reloj_abuela"
const PACK_FUNDADOR := "pack_fundador"

## Cuánto más lento va TODO el bicherío con el Reloj de la Abuela.
const RELOJ_SPEED_MULT := 0.5
## Daño del arma de pago en su nivel 1, y cuánto suma cada mejora.
## De referencia: el arma máxima que se compra con monedas pega 107.
const ARMA_LEGENDARIA_DANIO := 250
const ARMA_LEGENDARIA_PASO := 12
const ARMA_LEGENDARIA_ID := "zapato_de_oro"

const CATALOGO := {
	SIN_ANUNCIOS: {
		"orden": 0,
		"precio_usd": 2.99,
		"titulo": "Sacar la publicidad",
		"detalle": "Nunca más un anuncio, ni entre niveles ni en ningún lado. Los anuncios que dan premio quedan, por si los querés seguir viendo.",
		"regalo_monedas": 500,
		"icono": "res://assets/sprites/ui/ui_tilde.png",
	},
	ARMA_LEGENDARIA: {
		"orden": 1,
		"precio_usd": 4.99,
		"titulo": "Zapato de Oro de la Abuela",
		"detalle": "Pega 250 de entrada, contra los 107 del arma más cara que se compra con monedas. Y tiene el radio más grande del juego.",
		"icono": "res://assets/sprites/weapons/zapato_de_oro.png",
	},
	RELOJ_ABUELA: {
		"orden": 2,
		"precio_usd": 3.99,
		"titulo": "Reloj de la Abuela",
		"detalle": "Todos los bichos, minions y jefes van a la MITAD de velocidad. Para siempre, en los dos modos.",
		"icono": "res://assets/sprites/ui/item_reloj_bolsillo.png",
	},
	PACK_FUNDADOR: {
		"orden": 3,
		"precio_usd": 9.99,
		"titulo": "Pack Fundador",
		"detalle": "Las tres cosas de arriba juntas, más 3.000 monedas. Sale 11,97 comprado por separado.",
		"incluye": [SIN_ANUNCIOS, ARMA_LEGENDARIA, RELOJ_ABUELA],
		"regalo_monedas": 3000,
		"icono": "res://assets/sprites/ui/hud_star.png",
	},
}

## Paquetes de monedas (consumibles: se pueden comprar muchas veces).
const MONEDAS := {
	"monedas_chico": {"orden": 10, "precio_usd": 1.99, "monedas": 2000, "titulo": "Bolsita de monedas",
		"icono": "res://assets/sprites/ui/icon_coinbag.png"},
	"monedas_medio": {"orden": 11, "precio_usd": 4.99, "monedas": 6000, "titulo": "Frasco de monedas",
		"extra": "+20% de yapa", "icono": "res://assets/sprites/ui/icon_coinbag.png"},
	"monedas_grande": {"orden": 12, "precio_usd": 9.99, "monedas": 15000, "titulo": "Baúl de monedas",
		"extra": "+50% de yapa", "icono": "res://assets/sprites/ui/icon_coinbag.png"},
}

static func es_permanente(id: String) -> bool:
	return CATALOGO.has(id)

static func datos(id: String) -> Dictionary:
	if CATALOGO.has(id):
		return CATALOGO[id]
	return MONEDAS.get(id, {})

static func precio(id: String) -> String:
	var d := datos(id)
	if d.is_empty():
		return ""
	return "US$ %.2f" % float(d.get("precio_usd", 0.0))

## Los permanentes en el orden en que se muestran.
static func permanentes() -> Array:
	var ids: Array = CATALOGO.keys()
	ids.sort_custom(func(a, b): return int(CATALOGO[a]["orden"]) < int(CATALOGO[b]["orden"]))
	return ids

static func packs_monedas() -> Array:
	var ids: Array = MONEDAS.keys()
	ids.sort_custom(func(a, b): return int(MONEDAS[a]["orden"]) < int(MONEDAS[b]["orden"]))
	return ids
