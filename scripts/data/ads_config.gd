class_name AdsConfig
extends RefCounted

## LOS NÚMEROS DE ADMOB, todos en un solo lugar.
##
## Hay dos juegos de IDs y un interruptor para elegir cuál se usa:
##
##   USAR_PRUEBA = true   -> los de prueba de Google (los de abajo)
##   USAR_PRUEBA = false  -> los de la cuenta de El Huerto de Sofía
##
## Y esto NO es una comodidad, es lo que evita que te baneen la cuenta:
## tocar tus propios anuncios de producción, aunque sea una vez probando
## en tu celular, es motivo de suspensión de AdMob y de que no te paguen
## lo acumulado. Mientras se prueba, va en `true`. Se pone en `false` una
## sola vez, en el build que se sube a producción.
##
## Los IDs no son secretos: viajan adentro del APK y cualquiera los puede
## leer. Por eso están acá, versionados, y no en una variable de entorno.

## ⚠️ Lo único que hay que tocar para pasar a producción.
const USAR_PRUEBA := true

# --- Cuenta real (El Huerto de Sofía) ---
const APP_ID := "ca-app-pub-2714414375957960~7276707362"
const BANNER := "ca-app-pub-2714414375957960/6949404308"
const INTERSTICIAL := "ca-app-pub-2714414375957960/4711816877"
const RECOMPENSADO := "ca-app-pub-2714414375957960/5444750948"

# --- De prueba, públicos, de Google ---
#
# Estos son los de la página "Sample ad units" de la documentación de
# AdMob. Siempre devuelven un anuncio de mentira, no cuentan como
# impresión y no ensucian las estadísticas. Si alguna vez dejan de
# funcionar, hay que copiarlos de nuevo de ahí.
const APP_ID_PRUEBA := "ca-app-pub-3940256099942544~3347511713"
const BANNER_PRUEBA := "ca-app-pub-3940256099942544/6300978111"
const INTERSTICIAL_PRUEBA := "ca-app-pub-3940256099942544/1033173712"
const RECOMPENSADO_PRUEBA := "ca-app-pub-3940256099942544/5224354917"

static func app_id() -> String:
	return APP_ID_PRUEBA if USAR_PRUEBA else APP_ID

static func banner() -> String:
	return BANNER_PRUEBA if USAR_PRUEBA else BANNER

static func intersticial() -> String:
	return INTERSTICIAL_PRUEBA if USAR_PRUEBA else INTERSTICIAL

static func recompensado() -> String:
	return RECOMPENSADO_PRUEBA if USAR_PRUEBA else RECOMPENSADO

## Para el log del celular: dice qué unidad se pediría y con cuál de los
## dos juegos de IDs. Sirve para confirmar, mirando el logcat, que cada
## anuncio sale en el momento que corresponde y con la unidad correcta.
static func aviso(unidad: String, id: String) -> String:
	return "[Ads] %s -> %s (%s)" % [unidad, id, "PRUEBA" if USAR_PRUEBA else "PRODUCCIÓN"]
