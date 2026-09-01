class_name MysteryBug
extends Insect

## Insecto incógnito. Su progreso de revelación se guarda en
## GameManager.mystery_progress (por índice), NO en esta instancia,
## porque el mismo incógnito reaparece durante 9 niveles seguidos
## (ver LevelManager.has_mystery_bug) y debe recordar cuánto llevaba.

const REVEAL_MAX := 100.0
const EDGE_MARGIN := 48.0

const MYSTERY_DATABASE := {
	# Capítulo 1 — El Huerto de Sofía
	1: {"name": "Hormiga Ladrona de Diamantes", "type": "hormiga_ladrona", "speed": 100.0, "points": 100, "coin_reward": 150, "sprite": "res://assets/sprites/insects/hormiga_ladrona.png"},
	2: {"name": "Abejorro Piñata", "type": "abejorro_pinata", "speed": 150.0, "points": 150, "coin_reward": 220, "sprite": "res://assets/sprites/insects/abejorro_pinata.png"},
	3: {"name": "Mantis Cronómetro", "type": "mantis_cronometro", "speed": 120.0, "points": 120, "coin_reward": 180, "sprite": "res://assets/sprites/insects/mantis_cronometro.png"},
	4: {"name": "Escarabajo Radiactivo", "type": "escarabajo_radiactivo", "speed": 140.0, "points": 140, "coin_reward": 200, "sprite": "res://assets/sprites/insects/escarabajo_radiactivo.png"},
	5: {"name": "Lombriz Gigante", "type": "lombriz_gigante", "speed": 60.0, "points": 130, "coin_reward": 190, "sprite": "res://assets/sprites/insects/lombriz_gigante.png"},
	6: {"name": "Mutagénesis Voladora", "type": "mutante_volador", "speed": 180.0, "points": 160, "coin_reward": 240, "sprite": "res://assets/sprites/insects/mutante_volador.png"},
	7: {"name": "Centella Blindada", "type": "centella_blindada", "speed": 110.0, "points": 170, "coin_reward": 250, "sprite": "res://assets/sprites/insects/centella_blindada.png"},
	8: {"name": "Rayo Insecto", "type": "rayo_insecto", "speed": 250.0, "points": 200, "coin_reward": 300, "sprite": "res://assets/sprites/insects/rayo_insecto.png"},
	9: {"name": "Coraza Antigua", "type": "coraza_antigua", "speed": 90.0, "points": 180, "coin_reward": 270, "sprite": "res://assets/sprites/insects/coraza_antigua.png"},
	10: {"name": "Reina Primordial", "type": "reina_primordial", "speed": 130.0, "points": 300, "coin_reward": 500, "sprite": "res://assets/sprites/insects/reina_primordial.png"},
	# Capítulo 2 — El Invernadero
	11: {"name": "Pulgón de Cristal", "type": "pulgon_cristal", "speed": 95.0, "points": 155, "coin_reward": 235, "sprite": "res://assets/sprites/insects/pulgon_cristal.png"},
	12: {"name": "Araña Roja del Riego", "type": "arana_roja_riego", "speed": 105.0, "points": 163, "coin_reward": 247, "sprite": "res://assets/sprites/insects/arana_roja_riego.png"},
	13: {"name": "Mosca Blanca del Vapor", "type": "mosca_blanca_vapor", "speed": 190.0, "points": 171, "coin_reward": 259, "sprite": "res://assets/sprites/insects/mosca_blanca_vapor.png"},
	14: {"name": "Trips Plateado", "type": "trips_plateado", "speed": 170.0, "points": 179, "coin_reward": 271, "sprite": "res://assets/sprites/insects/trips_plateado.png"},
	15: {"name": "Cochinilla de Algodón", "type": "cochinilla_algodon", "speed": 80.0, "points": 187, "coin_reward": 283, "sprite": "res://assets/sprites/insects/cochinilla_algodon.png"},
	16: {"name": "Minador de Hojas", "type": "minador_hoja", "speed": 70.0, "points": 195, "coin_reward": 295, "sprite": "res://assets/sprites/insects/minador_hoja.png"},
	17: {"name": "Caracol de Maceta", "type": "caracol_maceta", "speed": 55.0, "points": 203, "coin_reward": 307, "sprite": "res://assets/sprites/insects/caracol_maceta.png"},
	18: {"name": "Grillo Topo Verde", "type": "grillo_topo_verde", "speed": 110.0, "points": 211, "coin_reward": 319, "sprite": "res://assets/sprites/insects/grillo_topo_verde.png"},
	19: {"name": "Escarabajo Pulga", "type": "escarabajo_pulga", "speed": 200.0, "points": 219, "coin_reward": 331, "sprite": "res://assets/sprites/insects/escarabajo_pulga.png"},
	20: {"name": "Avispa Polinizadora", "type": "avispa_polinizadora", "speed": 175.0, "points": 227, "coin_reward": 343, "sprite": "res://assets/sprites/insects/avispa_polinizadora.png"},
	# Capítulo 3 — La Cueva Subterránea
	21: {"name": "Ciempiés de Fósforo", "type": "ciempies_fosforo", "speed": 100.0, "points": 210, "coin_reward": 320, "sprite": "res://assets/sprites/insects/ciempies_fosforo.png"},
	22: {"name": "Araña Lámpara", "type": "arana_lampara", "speed": 90.0, "points": 218, "coin_reward": 332, "sprite": "res://assets/sprites/insects/arana_lampara.png"},
	23: {"name": "Grillo Ciego", "type": "grillo_ciego", "speed": 160.0, "points": 226, "coin_reward": 344, "sprite": "res://assets/sprites/insects/grillo_ciego.png"},
	24: {"name": "Escarabajo Estalactita", "type": "escarabajo_estalactita", "speed": 75.0, "points": 234, "coin_reward": 356, "sprite": "res://assets/sprites/insects/escarabajo_estalactita.png"},
	25: {"name": "Colémbolo Saltarín", "type": "colembolo_saltarin", "speed": 185.0, "points": 242, "coin_reward": 368, "sprite": "res://assets/sprites/insects/colembolo_saltarin.png"},
	26: {"name": "Opilión Zanco", "type": "opilion_zanco", "speed": 130.0, "points": 250, "coin_reward": 380, "sprite": "res://assets/sprites/insects/opilion_zanco.png"},
	27: {"name": "Cucaracha Murciélago", "type": "cucaracha_murcielago", "speed": 175.0, "points": 258, "coin_reward": 392, "sprite": "res://assets/sprites/insects/cucaracha_murcielago.png"},
	28: {"name": "Gusano de Luz", "type": "gusano_luz", "speed": 85.0, "points": 266, "coin_reward": 404, "sprite": "res://assets/sprites/insects/gusano_luz.png"},
	29: {"name": "Escorpión de Pozo", "type": "escorpion_pozo", "speed": 105.0, "points": 274, "coin_reward": 416, "sprite": "res://assets/sprites/insects/escorpion_pozo.png"},
	30: {"name": "Polilla de Cristal", "type": "polilla_cristal", "speed": 165.0, "points": 282, "coin_reward": 428, "sprite": "res://assets/sprites/insects/polilla_cristal.png"},
	# Capítulo 4 — El Cultivo Radiactivo
	31: {"name": "Escarabajo de Uranio", "type": "escarabajo_uranio", "speed": 85.0, "points": 265, "coin_reward": 405, "sprite": "res://assets/sprites/insects/escarabajo_uranio.png"},
	32: {"name": "Mosca Geiger", "type": "mosca_geiger", "speed": 180.0, "points": 273, "coin_reward": 417, "sprite": "res://assets/sprites/insects/mosca_geiger.png"},
	33: {"name": "Hormiga Isótopo", "type": "hormiga_isotopo", "speed": 115.0, "points": 281, "coin_reward": 429, "sprite": "res://assets/sprites/insects/hormiga_isotopo.png"},
	34: {"name": "Gusano Neón", "type": "gusano_neon", "speed": 70.0, "points": 289, "coin_reward": 441, "sprite": "res://assets/sprites/insects/gusano_neon.png"},
	35: {"name": "Chinche de Plutonio", "type": "chinche_plutonio", "speed": 95.0, "points": 297, "coin_reward": 453, "sprite": "res://assets/sprites/insects/chinche_plutonio.png"},
	36: {"name": "Libélula Reactor", "type": "libelula_reactor", "speed": 195.0, "points": 305, "coin_reward": 465, "sprite": "res://assets/sprites/insects/libelula_reactor.png"},
	37: {"name": "Avispa Cesio", "type": "avispa_cesio", "speed": 185.0, "points": 313, "coin_reward": 477, "sprite": "res://assets/sprites/insects/avispa_cesio.png"},
	38: {"name": "Oruga Fluorescente", "type": "oruga_fluorescente", "speed": 80.0, "points": 321, "coin_reward": 489, "sprite": "res://assets/sprites/insects/oruga_fluorescente.png"},
	39: {"name": "Escarabajo Barril", "type": "escarabajo_barril", "speed": 65.0, "points": 329, "coin_reward": 501, "sprite": "res://assets/sprites/insects/escarabajo_barril.png"},
	40: {"name": "Mosquito Radón", "type": "mosquito_radon", "speed": 205.0, "points": 337, "coin_reward": 513, "sprite": "res://assets/sprites/insects/mosquito_radon.png"},
	# Capítulo 5 — El Pantano
	41: {"name": "Mosquito de Cieno", "type": "mosquito_cieno", "speed": 190.0, "points": 320, "coin_reward": 490, "sprite": "res://assets/sprites/insects/mosquito_cieno.png"},
	42: {"name": "Sanguijuela Saltarina", "type": "sanguijuela_saltarina", "speed": 90.0, "points": 328, "coin_reward": 502, "sprite": "res://assets/sprites/insects/sanguijuela_saltarina.png"},
	43: {"name": "Libélula de Juncos", "type": "libelula_juncos", "speed": 200.0, "points": 336, "coin_reward": 514, "sprite": "res://assets/sprites/insects/libelula_juncos.png"},
	44: {"name": "Escarabajo Buzo", "type": "escarabajo_buzo", "speed": 110.0, "points": 344, "coin_reward": 526, "sprite": "res://assets/sprites/insects/escarabajo_buzo.png"},
	45: {"name": "Araña Pescadora", "type": "arana_pescadora", "speed": 120.0, "points": 352, "coin_reward": 538, "sprite": "res://assets/sprites/insects/arana_pescadora.png"},
	46: {"name": "Tábano de Barro", "type": "tabano_barro", "speed": 165.0, "points": 360, "coin_reward": 550, "sprite": "res://assets/sprites/insects/tabano_barro.png"},
	47: {"name": "Caracol de Manglar", "type": "caracol_manglar", "speed": 60.0, "points": 368, "coin_reward": 562, "sprite": "res://assets/sprites/insects/caracol_manglar.png"},
	48: {"name": "Zapatero de Agua", "type": "zapatero_agua", "speed": 180.0, "points": 376, "coin_reward": 574, "sprite": "res://assets/sprites/insects/zapatero_agua.png"},
	49: {"name": "Larva de Pantano", "type": "larva_pantano", "speed": 70.0, "points": 384, "coin_reward": 586, "sprite": "res://assets/sprites/insects/larva_pantano.png"},
	50: {"name": "Luciérnaga de Niebla", "type": "luciernaga_niebla", "speed": 150.0, "points": 392, "coin_reward": 598, "sprite": "res://assets/sprites/insects/luciernaga_niebla.png"},
	# Capítulo 6 — Laboratorio Mutante
	51: {"name": "Quimera de Seis Patas", "type": "quimera_seis_patas", "speed": 125.0, "points": 375, "coin_reward": 575, "sprite": "res://assets/sprites/insects/quimera_seis_patas.png"},
	52: {"name": "Clon Defectuoso", "type": "clon_defectuoso", "speed": 95.0, "points": 383, "coin_reward": 587, "sprite": "res://assets/sprites/insects/clon_defectuoso.png"},
	53: {"name": "Hormiga Probeta", "type": "hormiga_probeta", "speed": 105.0, "points": 391, "coin_reward": 599, "sprite": "res://assets/sprites/insects/hormiga_probeta.png"},
	54: {"name": "Escarabajo Bisturí", "type": "escarabajo_bisturi", "speed": 135.0, "points": 399, "coin_reward": 611, "sprite": "res://assets/sprites/insects/escarabajo_bisturi.png"},
	55: {"name": "Mosca de Dos Cabezas", "type": "mosca_dos_cabezas", "speed": 185.0, "points": 407, "coin_reward": 623, "sprite": "res://assets/sprites/insects/mosca_dos_cabezas.png"},
	56: {"name": "Mantis Injerto", "type": "mantis_injerto", "speed": 140.0, "points": 415, "coin_reward": 635, "sprite": "res://assets/sprites/insects/mantis_injerto.png"},
	57: {"name": "Gusano ADN", "type": "gusano_adn", "speed": 80.0, "points": 423, "coin_reward": 647, "sprite": "res://assets/sprites/insects/gusano_adn.png"},
	58: {"name": "Avispa Jeringa", "type": "avispa_jeringa", "speed": 190.0, "points": 431, "coin_reward": 659, "sprite": "res://assets/sprites/insects/avispa_jeringa.png"},
	59: {"name": "Cucaracha Espejo", "type": "cucaracha_espejo", "speed": 175.0, "points": 439, "coin_reward": 671, "sprite": "res://assets/sprites/insects/cucaracha_espejo.png"},
	60: {"name": "Larva de Incubadora", "type": "larva_incubadora", "speed": 65.0, "points": 447, "coin_reward": 683, "sprite": "res://assets/sprites/insects/larva_incubadora.png"},
	# Capítulo 7 — Fábrica de Cascos
	61: {"name": "Escarabajo Yunque", "type": "escarabajo_yunque", "speed": 75.0, "points": 430, "coin_reward": 660, "sprite": "res://assets/sprites/insects/escarabajo_yunque.png"},
	62: {"name": "Hormiga Remache", "type": "hormiga_remache", "speed": 115.0, "points": 438, "coin_reward": 672, "sprite": "res://assets/sprites/insects/hormiga_remache.png"},
	63: {"name": "Tornillo Viviente", "type": "tornillo_viviente", "speed": 90.0, "points": 446, "coin_reward": 684, "sprite": "res://assets/sprites/insects/tornillo_viviente.png"},
	64: {"name": "Mantis Soldadora", "type": "mantis_soldadora", "speed": 130.0, "points": 454, "coin_reward": 696, "sprite": "res://assets/sprites/insects/mantis_soldadora.png"},
	65: {"name": "Escarabajo Engranaje", "type": "escarabajo_engranaje", "speed": 85.0, "points": 462, "coin_reward": 708, "sprite": "res://assets/sprites/insects/escarabajo_engranaje.png"},
	66: {"name": "Avispa Taladro", "type": "avispa_taladro", "speed": 180.0, "points": 470, "coin_reward": 720, "sprite": "res://assets/sprites/insects/avispa_taladro.png"},
	67: {"name": "Cucaracha de Chapa", "type": "cucaracha_chapa", "speed": 105.0, "points": 478, "coin_reward": 732, "sprite": "res://assets/sprites/insects/cucaracha_chapa.png"},
	68: {"name": "Grillo Resorte", "type": "grillo_resorte", "speed": 195.0, "points": 486, "coin_reward": 744, "sprite": "res://assets/sprites/insects/grillo_resorte.png"},
	69: {"name": "Escarabajo Prensa", "type": "escarabajo_prensa", "speed": 60.0, "points": 494, "coin_reward": 756, "sprite": "res://assets/sprites/insects/escarabajo_prensa.png"},
	70: {"name": "Mosca Chispa", "type": "mosca_chispa", "speed": 200.0, "points": 502, "coin_reward": 768, "sprite": "res://assets/sprites/insects/mosca_chispa.png"},
	# Capítulo 8 — Red de Túneles Express
	71: {"name": "Hormiga Correo", "type": "hormiga_correo", "speed": 135.0, "points": 485, "coin_reward": 745, "sprite": "res://assets/sprites/insects/hormiga_correo.png"},
	72: {"name": "Escarabajo Vagón", "type": "escarabajo_vagon", "speed": 110.0, "points": 493, "coin_reward": 757, "sprite": "res://assets/sprites/insects/escarabajo_vagon.png"},
	73: {"name": "Cucaracha Turbo", "type": "cucaracha_turbo", "speed": 215.0, "points": 501, "coin_reward": 769, "sprite": "res://assets/sprites/insects/cucaracha_turbo.png"},
	74: {"name": "Gusano Taladro", "type": "gusano_taladro", "speed": 80.0, "points": 509, "coin_reward": 781, "sprite": "res://assets/sprites/insects/gusano_taladro.png"},
	75: {"name": "Mantis Semáforo", "type": "mantis_semaforo", "speed": 125.0, "points": 517, "coin_reward": 793, "sprite": "res://assets/sprites/insects/mantis_semaforo.png"},
	76: {"name": "Avispa Mensajera", "type": "avispa_mensajera", "speed": 205.0, "points": 525, "coin_reward": 805, "sprite": "res://assets/sprites/insects/avispa_mensajera.png"},
	77: {"name": "Grillo de Riel", "type": "grillo_riel", "speed": 190.0, "points": 533, "coin_reward": 817, "sprite": "res://assets/sprites/insects/grillo_riel.png"},
	78: {"name": "Escarabajo Furgón", "type": "escarabajo_furgon", "speed": 75.0, "points": 541, "coin_reward": 829, "sprite": "res://assets/sprites/insects/escarabajo_furgon.png"},
	79: {"name": "Mosca Exprés", "type": "mosca_expres", "speed": 235.0, "points": 549, "coin_reward": 841, "sprite": "res://assets/sprites/insects/mosca_expres.png"},
	80: {"name": "Hormiga de Carga", "type": "hormiga_carga", "speed": 90.0, "points": 557, "coin_reward": 853, "sprite": "res://assets/sprites/insects/hormiga_carga.png"},
	# Capítulo 9 — El Búnker Enemigo
	81: {"name": "Escarabajo de Búnker", "type": "escarabajo_bunker", "speed": 70.0, "points": 540, "coin_reward": 830, "sprite": "res://assets/sprites/insects/escarabajo_bunker.png"},
	82: {"name": "Hormiga Centinela", "type": "hormiga_centinela", "speed": 120.0, "points": 548, "coin_reward": 842, "sprite": "res://assets/sprites/insects/hormiga_centinela.png"},
	83: {"name": "Mantis Francotiradora", "type": "mantis_francotiradora", "speed": 100.0, "points": 556, "coin_reward": 854, "sprite": "res://assets/sprites/insects/mantis_francotiradora.png"},
	84: {"name": "Avispa Granada", "type": "avispa_granada", "speed": 185.0, "points": 564, "coin_reward": 866, "sprite": "res://assets/sprites/insects/avispa_granada.png"},
	85: {"name": "Cucaracha Radar", "type": "cucaracha_radar", "speed": 95.0, "points": 572, "coin_reward": 878, "sprite": "res://assets/sprites/insects/cucaracha_radar.png"},
	86: {"name": "Escarabajo Torreta", "type": "escarabajo_torreta", "speed": 80.0, "points": 580, "coin_reward": 890, "sprite": "res://assets/sprites/insects/escarabajo_torreta.png"},
	87: {"name": "Grillo Alarma", "type": "grillo_alarma", "speed": 145.0, "points": 588, "coin_reward": 902, "sprite": "res://assets/sprites/insects/grillo_alarma.png"},
	88: {"name": "Gusano Mina", "type": "gusano_mina", "speed": 60.0, "points": 596, "coin_reward": 914, "sprite": "res://assets/sprites/insects/gusano_mina.png"},
	89: {"name": "Mosca Dron", "type": "mosca_dron", "speed": 200.0, "points": 604, "coin_reward": 926, "sprite": "res://assets/sprites/insects/mosca_dron.png"},
	90: {"name": "Escorpión Guardia", "type": "escorpion_guardia", "speed": 90.0, "points": 612, "coin_reward": 938, "sprite": "res://assets/sprites/insects/escorpion_guardia.png"},
	# Capítulo 10 — El Núcleo Reina
	91: {"name": "Cortesano Dorado", "type": "cortesano_dorado", "speed": 130.0, "points": 595, "coin_reward": 915, "sprite": "res://assets/sprites/insects/cortesano_dorado.png"},
	92: {"name": "Guardia Real", "type": "guardia_real", "speed": 110.0, "points": 603, "coin_reward": 927, "sprite": "res://assets/sprites/insects/guardia_real.png"},
	93: {"name": "Nodriza de Larvas", "type": "nodriza_larvas", "speed": 85.0, "points": 611, "coin_reward": 939, "sprite": "res://assets/sprites/insects/nodriza_larvas.png"},
	94: {"name": "Heraldo de la Reina", "type": "heraldo_reina", "speed": 160.0, "points": 619, "coin_reward": 951, "sprite": "res://assets/sprites/insects/heraldo_reina.png"},
	95: {"name": "Tejedor de Panal", "type": "tejedor_panal", "speed": 105.0, "points": 627, "coin_reward": 963, "sprite": "res://assets/sprites/insects/tejedor_panal.png"},
	96: {"name": "Sacerdote de Ámbar", "type": "sacerdote_ambar", "speed": 90.0, "points": 635, "coin_reward": 975, "sprite": "res://assets/sprites/insects/sacerdote_ambar.png"},
	97: {"name": "Verdugo de Quitina", "type": "verdugo_quitina", "speed": 75.0, "points": 643, "coin_reward": 987, "sprite": "res://assets/sprites/insects/verdugo_quitina.png"},
	98: {"name": "Arquitecto del Nido", "type": "arquitecto_nido", "speed": 150.0, "points": 651, "coin_reward": 999, "sprite": "res://assets/sprites/insects/arquitecto_nido.png"},
	99: {"name": "Príncipe Alado", "type": "principe_alado", "speed": 195.0, "points": 659, "coin_reward": 1011, "sprite": "res://assets/sprites/insects/principe_alado.png"},
	100: {"name": "Eco Primordial", "type": "eco_primordial", "speed": 140.0, "points": 667, "coin_reward": 1023, "sprite": "res://assets/sprites/insects/eco_primordial.png"},
}

@onready var reveal_bar: ProgressBar = $RevealBar
@onready var mystery_sprite: Sprite2D = $MysterySprite
@onready var progress_label: Label = $ProgressLabel

var mystery_index: int = 0
var insect_data: Dictionary = {}
var is_revealed: bool = false

func _ready() -> void:
	add_to_group("insects")
	insect_type = "mystery"
	is_dead = false
	can_be_hit = true
	base_speed = 90.0
	speed = base_speed
	current_health = 1
	health = 1

	mystery_index = GameManager.get_current_level_config().get("mystery_index", 0)
	insect_data = MYSTERY_DATABASE.get(mystery_index, {})

	if insect_data.is_empty():
		push_warning("[MysteryBug] Sin datos para índice %d" % mystery_index)
		queue_free()
		return

	points = 20
	coin_reward = 0  # las monedas grandes se entregan solo al revelar

	# Mismo camino que Insect: si están los <tipo>_walk_N.png, el incógnito
	# camina animado igual que los comunes; si no, queda el sprite fijo.
	# Antes acá se forzaba el sprite fijo, así que los 10 incógnitos nunca
	# animaban por más que existiera su ciclo.
	if sprite:
		_apply_sprite_data(sprite, insect_data, String(insect_data.get("type", "")))
	if mystery_sprite:
		mystery_sprite.texture = load("res://assets/sprites/insects/mystery_bug_silueta.png")

	randomize_direction()
	_show_mystery_sprite()
	_update_reveal_visuals()

func _process(delta: float) -> void:
	super._process(delta)
	if mystery_sprite and sprite:
		mystery_sprite.rotation = sprite.rotation
		mystery_sprite.position.y = sprite.position.y

func _physics_process(delta: float) -> void:
	if is_dead or is_revealed:
		return

	if is_taunting:
		taunt_timer -= delta
		if taunt_timer <= 0.0:
			is_taunting = false
			speed = base_speed
	else:
		wander_timer -= delta
		if wander_timer <= 0.0:
			randomize_direction()
			wander_timer = randf_range(1.0, 2.0)

	velocity = direction * speed
	move_and_slide()
	_bounce_off_edges()

func _bounce_off_edges() -> void:
	var viewport_size := get_viewport_rect().size

	if global_position.x < EDGE_MARGIN or global_position.x > viewport_size.x - EDGE_MARGIN:
		direction.x *= -1.0
	if global_position.y < EDGE_MARGIN or global_position.y > viewport_size.y - EDGE_MARGIN:
		direction.y *= -1.0

	global_position.x = clamp(global_position.x, EDGE_MARGIN, viewport_size.x - EDGE_MARGIN)
	global_position.y = clamp(global_position.y, EDGE_MARGIN, viewport_size.y - EDGE_MARGIN)

func _show_mystery_sprite() -> void:
	if mystery_sprite:
		mystery_sprite.modulate.a = 1.0
	if sprite:
		sprite.modulate.a = 0.0
	if progress_label:
		progress_label.text = "???"

func take_damage(damage: int = 1) -> void:
	if is_dead or is_revealed:
		return

	var progress := GameManager.add_mystery_progress(mystery_index, float(damage))
	_update_reveal_visuals()
	_play_reveal_flash()

	GameManager.on_insect_hit(self)

	if progress >= REVEAL_MAX:
		reveal_insect()
	else:
		play_hit_animation()

func _update_reveal_visuals() -> void:
	var progress := GameManager.get_mystery_progress(mystery_index)
	var percentage: float = clamp((progress / REVEAL_MAX) * 100.0, 0.0, 100.0)

	if reveal_bar:
		reveal_bar.value = percentage
	if progress_label:
		progress_label.text = "%d%%" % int(percentage)

	var fade: float = percentage / 100.0
	if mystery_sprite:
		mystery_sprite.modulate.a = 1.0 - fade
	if sprite:
		sprite.modulate.a = fade

func reveal_insect() -> void:
	if is_revealed:
		return

	is_revealed = true
	print("[MysteryBug] ¡Revelado! %s" % insect_data.get("name", "???"))

	_play_revelation_animation()
	AudioManager.play_sfx("mystery_revealed")

	GameManager.unlock_insect(mystery_index, insect_data)
	GameManager.add_coins(int(insect_data.get("coin_reward", 0)))

	await get_tree().create_timer(1.2).timeout
	queue_free()

func _play_reveal_flash() -> void:
	if not sprite and not mystery_sprite:
		return
	# Aplica el flash al sprite más visible en este momento (según cuánto
	# se haya revelado), si no el jugador podría no ver feedback del golpe.
	var target: CanvasItem = sprite if sprite and sprite.modulate.a >= 0.5 else mystery_sprite
	if not target:
		target = sprite if sprite else mystery_sprite
	var original_modulate := target.modulate
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(2.0, 2.0, 1.2, original_modulate.a), 0.05)
	tween.tween_property(target, "modulate", original_modulate, 0.08)

func _play_revelation_animation() -> void:
	if not sprite:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
