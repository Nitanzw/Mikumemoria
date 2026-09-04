extends Node

## TIENDA Y PUBLICIDAD de la versión gratis (autoload "Store").
##
## Guarda aparte del progreso, en su propio archivo, y a propósito: si
## algún día se agrega un "borrar partida", lo COMPRADO no se borra. Un
## jugador que paga y pierde lo que pagó no vuelve a pagar nunca.
##
## Este script no sabe nada de AdMob ni de Google Play: sólo dice CUÁNDO
## corresponde un anuncio o una compra y qué se da a cambio. Mostrar el
## anuncio y cobrar es trabajo de AdsService y BillingService, que hoy
## son simulaciones (ver el LEEME de scripts/services/).

signal purchases_changed
signal daily_changed

const SAVE_PATH := "user://tienda_premium.json"

## --- Estado comprado ---
var owned: Array = []

## --- Regalo diario ---
## Día (unix / 86400) del último regalo agarrado, y racha de días
## seguidos. La racha se corta si se salta un día entero.
var daily_last_day: int = 0
var daily_streak: int = 0

## --- Anuncios ---
## Cuántos anuncios con premio se vieron hoy, para no dejar que alguien
## se haga el juego entero mirando publicidad (y para no quemar el
## inventario, que baja lo que paga la red).
var rewarded_day: int = 0
var rewarded_today: int = 0
const REWARDED_MAX_PER_DAY := 12
const REWARDED_COINS := 150

## Niveles terminados desde el último anuncio de pantalla completa.
var levels_since_interstitial: int = 0
const INTERSTITIAL_EVERY := 3

## Escalera del regalo diario. Siete días y vuelve a empezar, con el
## séptimo bien arriba: es el que hace que alguien abra el juego un
## martes que no tenía ganas.
const DAILY_REWARDS := [
	{"monedas": 150},
	{"monedas": 250},
	{"monedas": 400},
	{"vidas": 3},
	{"monedas": 700},
	{"monedas": 1000},
	{"monedas": 2000, "vidas": 3},
]

func _ready() -> void:
	load_store()

# --- Compras ---

func has(id: String) -> bool:
	return id in owned

func no_ads() -> bool:
	return has(IapData.SIN_ANUNCIOS)

## Multiplicador de velocidad de TODOS los enemigos. El Reloj de la
## Abuela los deja a la mitad, para siempre y en los dos modos.
func speed_mult() -> float:
	return IapData.RELOJ_SPEED_MULT if has(IapData.RELOJ_ABUELA) else 1.0

func has_legendary() -> bool:
	return has(IapData.ARMA_LEGENDARIA)

## Entrega lo comprado. La llama BillingService cuando la compra se
## confirma, y también al restaurar compras al reinstalar.
func grant(id: String) -> void:
	var datos := IapData.datos(id)
	if datos.is_empty():
		return

	if IapData.es_permanente(id):
		if not has(id):
			owned.append(id)
		# Un pack entrega también lo que lleva adentro, así el resto del
		# juego pregunta por la cosa y no por el pack.
		for incluido in datos.get("incluye", []):
			if not has(incluido):
				owned.append(incluido)

	# El arma de pago se entrega puesta: comprarla y tener que ir a la
	# tienda a equiparla es la clase de fricción que genera reembolsos.
	if has(IapData.ARMA_LEGENDARIA) and GameManager.get_weapon_level(IapData.ARMA_LEGENDARIA_ID) == 0:
		GameManager.grant_weapon(IapData.ARMA_LEGENDARIA_ID)

	var monedas: int = int(datos.get("regalo_monedas", 0)) + int(datos.get("monedas", 0))
	if monedas > 0:
		GameManager.add_coins_and_save(monedas)

	save_store()
	purchases_changed.emit()

# --- Anuncios ---

func _hoy() -> int:
	return int(Time.get_unix_time_from_system() / 86400)

## Los anuncios de pantalla completa se muestran ENTRE niveles, nunca
## durante uno, nunca después de perder una vida y nunca en una pelea de
## jefe. Es política de Google, pero antes que eso es sentido común: el
## anuncio que aparece justo cuando perdiste es el que hace que
## desinstalen el juego.
func should_show_interstitial() -> bool:
	if no_ads():
		return false
	return levels_since_interstitial >= INTERSTITIAL_EVERY

func note_level_finished() -> void:
	levels_since_interstitial += 1

func note_interstitial_shown() -> void:
	levels_since_interstitial = 0

## Los anuncios CON PREMIO no se sacan nunca, ni siquiera al que pagó por
## sacar la publicidad: son opcionales y el jugador los busca él. Al que
## pagó se le ofrecen igual, porque le siguen sirviendo.
func rewarded_left() -> int:
	if rewarded_day != _hoy():
		return REWARDED_MAX_PER_DAY
	return maxi(REWARDED_MAX_PER_DAY - rewarded_today, 0)

func can_watch_rewarded() -> bool:
	return rewarded_left() > 0

func note_rewarded_watched() -> void:
	var hoy := _hoy()
	if rewarded_day != hoy:
		rewarded_day = hoy
		rewarded_today = 0
	rewarded_today += 1
	save_store()

# --- Regalo diario ---

## Qué día de la racha toca hoy (1..7). Si pasó más de un día sin abrir
## el juego la racha vuelve a empezar.
func daily_day() -> int:
	var hoy := _hoy()
	if daily_last_day == 0 or hoy - daily_last_day > 1:
		return 1
	return (daily_streak % DAILY_REWARDS.size()) + 1

func daily_available() -> bool:
	return daily_last_day != _hoy()

func daily_reward() -> Dictionary:
	return DAILY_REWARDS[daily_day() - 1]

## Entrega el regalo del día. `doble` es para el anuncio que lo duplica.
func claim_daily(doble: bool = false) -> Dictionary:
	if not daily_available():
		return {}
	var premio := daily_reward().duplicate()
	var hoy := _hoy()
	daily_streak = 0 if (daily_last_day == 0 or hoy - daily_last_day > 1) else daily_streak
	daily_streak += 1
	daily_last_day = hoy

	if doble:
		premio["monedas"] = int(premio.get("monedas", 0)) * 2
		premio["vidas"] = int(premio.get("vidas", 0)) * 2

	if int(premio.get("monedas", 0)) > 0:
		GameManager.add_coins_and_save(int(premio["monedas"]))
	if int(premio.get("vidas", 0)) > 0:
		GameManager.add_lives(int(premio["vidas"]))

	save_store()
	daily_changed.emit()
	return premio

# --- Persistencia ---

func save_store() -> void:
	var datos := {
		"owned": owned,
		"daily_last_day": daily_last_day,
		"daily_streak": daily_streak,
		"rewarded_day": rewarded_day,
		"rewarded_today": rewarded_today,
	}
	var archivo := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if archivo:
		archivo.store_string(JSON.stringify(datos))
		archivo.close()

func load_store() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var archivo := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not archivo:
		return
	var parsed = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	owned = parsed.get("owned", [])
	daily_last_day = int(parsed.get("daily_last_day", 0))
	daily_streak = int(parsed.get("daily_streak", 0))
	rewarded_day = int(parsed.get("rewarded_day", 0))
	rewarded_today = int(parsed.get("rewarded_today", 0))
