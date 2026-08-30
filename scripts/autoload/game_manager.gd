extends Node

## GAME MANAGER - Control central del juego (autoload "GameManager").
## Sin class_name: coincidiría con el nombre del autoload y Godot
## rechaza esa combinación al compilar ("class already exists as
## autoload"). Se accede siempre como el singleton global GameManager.

# --- Progreso del jugador ---
var current_level: int = 1
var current_chapter: int = 1
## Nivel más alto desbloqueado. Se separa de current_level para poder
## rejugar uno viejo sin perder el avance (ver el selector de niveles).
var max_level_unlocked: int = 1
var player_coins: int = 0
var player_score: int = 0
var combo_hits: int = 0
var combo_max: int = 0
## Fallos que todavía te perdonan las Botas de Goma en este nivel.
var _combo_forgives_left: int = 0

# --- Desbloqueos ---
var unlocked_insects: Array = []          # índices de insectos incógnito revelados
var unlocked_weapons: Array = ["zapato_viejo"]
var equipped_weapon: String = "zapato_viejo"
var skill_tree: Dictionary = {}
## Objetos pasivos comprados: {id: nivel}. Ver ItemSystem.
var items: Dictionary = {}
## Cuando se entra a la tienda desde el resumen de un nivel, el botón
## "Volver" tiene que devolverte AL JUEGO y no al menú principal. No se
## guarda en el archivo: es estado de navegación de esta sesión.
var return_to_game_after_shop: bool = false
## Vista elegida en la tienda: true = cuadrícula, false = lista. Se guarda
## para no tener que volver a cambiarla cada vez que se entra.
var shop_grid_view: bool = true

# Progreso de revelación de cada incógnito (índice -> puntos acumulados).
# Persiste entre niveles porque un mismo incógnito aparece durante los
# 9 niveles previos a cada múltiplo de 10 (ver LevelManager.has_mystery_bug).
var mystery_progress: Dictionary = {}

# --- Vidas ---
# Solo se gastan al perder una pelea de jefe. Regeneran solas con el paso
# del tiempo real (no del tiempo de juego): se guarda el timestamp Unix
# de la última regeneración y al cargar se calcula cuántas corresponden,
# así también suma el tiempo con el juego cerrado.
const MAX_LIVES := 3

## Umbrales de los mini tutoriales por hito.
const TUTORIAL_SHOP_COINS := 200
const TUTORIAL_ITEMS_COINS := 400
const TUTORIAL_COMBO_HITS := 5
const LIFE_REGEN_SECONDS := 600  # 10 minutos por vida
const REFILL_LIVES_COST := 150   # recargar todas pagando monedas

var player_lives: int = MAX_LIVES
var lives_timestamp: int = 0     # Unix time de la última vez que se contaron

# --- Historia / narrativa ---
var story_seen: bool = false
var seen_chapter_intros: Array = []   # capítulos (int) cuya intro ya se mostró
## Escalones de dificultad (int) cuyo aviso ya se mostró. Se guarda para
## que rejugar el nivel 10 no repita el mismo cartel cada vez.
var seen_difficulty_tiers: Array = []
## Mini tutoriales por hito ya mostrados, e historias ya contadas.
var seen_tutorials: Array = []
var seen_story_beats: Array = []
var force_show_story: bool = false    # flag transitorio (no se guarda), para "ver de nuevo" desde el menú
## Capítulo que el mapa de mundos pasa al selector de niveles. Transitorio.
var selected_chapter: int = 1

# --- Helpers internos (no son autoload, son instancias propias) ---
var level_manager := LevelManager.new()
var skill_system := SkillSystem.new()

# --- Señales ---
signal level_started(level: int)
signal level_completed(level: int)
signal insect_unlocked(index: int, insect_name: String)
signal score_changed(new_score: int)
signal coins_changed(new_coins: int)
signal combo_forgiven(forgives_left: int)
signal combo_changed(combo: int)
signal lives_changed(lives: int)

func _ready() -> void:
	print("[GameManager] Inicializando...")
	load_game_data()

func load_game_data() -> void:
	var data := SaveManager.load_save()
	if not data.is_empty():
		print("[GameManager] Progreso cargado: nivel %d" % int(data.get("current_level", 1)))
		current_level = int(data.get("current_level", 1))
		player_coins = int(data.get("coins", 0))
		unlocked_insects = data.get("unlocked_insects", [])
		unlocked_weapons = data.get("unlocked_weapons", ["zapato_viejo"])
		equipped_weapon = data.get("equipped_weapon", "zapato_viejo")
		skill_tree = data.get("skill_tree", {})
		items = data.get("items", {})
		shop_grid_view = bool(data.get("shop_grid_view", true))
		mystery_progress = data.get("mystery_progress", {})
		story_seen = bool(data.get("story_seen", false))
		seen_chapter_intros = data.get("seen_chapter_intros", [])
		seen_difficulty_tiers = data.get("seen_difficulty_tiers", [])
		seen_tutorials = data.get("seen_tutorials", [])
		seen_story_beats = data.get("seen_story_beats", [])
		max_level_unlocked = int(data.get("max_level_unlocked", current_level))
		player_lives = int(data.get("player_lives", MAX_LIVES))
		lives_timestamp = int(data.get("lives_timestamp", Time.get_unix_time_from_system()))
		_regenerate_lives()
	else:
		print("[GameManager] Nuevo juego")
		reset_game()

func reset_game() -> void:
	current_level = 1
	current_chapter = 1
	player_coins = 0
	player_score = 0
	combo_hits = 0
	combo_max = 0
	unlocked_insects = []
	unlocked_weapons = ["zapato_viejo"]
	equipped_weapon = "zapato_viejo"
	skill_tree = {}
	items = {}
	mystery_progress = {}
	story_seen = false
	seen_chapter_intros = []
	seen_difficulty_tiers = []
	seen_tutorials = []
	seen_story_beats = []
	max_level_unlocked = 1
	player_lives = MAX_LIVES
	lives_timestamp = Time.get_unix_time_from_system()

func start_level(level: int) -> void:
	current_level = level
	current_chapter = level_manager.get_chapter_for_level(level)
	player_score = 0
	combo_hits = 0
	combo_max = 0
	_combo_forgives_left = ItemSystem.get_combo_forgives(items)

	print("[GameManager] Iniciando nivel %d (capítulo %d)" % [level, current_chapter])
	level_started.emit(level)

func get_current_level_config() -> Dictionary:
	return level_manager.get_level_config(current_level)

func on_insect_hit(insect: Insect) -> void:
	var multiplier := ComboSystem.get_multiplier(combo_hits)
	player_score += int(round(insect.points * multiplier))
	combo_hits += 1
	combo_max = max(combo_max, combo_hits)

	score_changed.emit(player_score)
	combo_changed.emit(combo_hits)
	AudioManager.play_sfx("hit_" + insect.insect_type)

func on_insect_missed() -> void:
	# Botas de Goma: los primeros fallos del nivel no cortan el combo.
	# El contador se reinicia por nivel (ver reset_level_stats), así el
	# perdón no se gasta para siempre en el primer error.
	if _combo_forgives_left > 0:
		_combo_forgives_left -= 1
		combo_forgiven.emit(_combo_forgives_left)
		AudioManager.play_sfx("taunt")
		return

	combo_hits = 0
	combo_changed.emit(combo_hits)
	AudioManager.play_sfx("taunt")

func on_level_complete() -> int:
	var finished_level := current_level
	var reward := calculate_level_reward()
	add_coins(reward)

	# Al rejugar un nivel viejo no se pisa el avance: solo se empuja el
	# tope si el que se acaba de ganar era el más alto alcanzado.
	max_level_unlocked = max(max_level_unlocked, min(finished_level + 1, level_manager.MAX_LEVEL))
	current_level = min(finished_level + 1, level_manager.MAX_LEVEL)
	current_chapter = level_manager.get_chapter_for_level(current_level)

	SaveManager.save_game(_build_save_dict())

	level_completed.emit(finished_level)
	return reward

func calculate_level_reward() -> int:
	var base := 50
	var level_bonus := current_level * 2
	var combo_bonus := ComboSystem.get_combo_bonus_coins(combo_max)
	var total := base + level_bonus + combo_bonus
	var multiplier := skill_system.get_coin_multiplier(skill_tree) * ItemSystem.get_coin_bonus(items)
	return int(round(total * multiplier))

func add_coins(amount: int) -> void:
	player_coins += amount
	coins_changed.emit(player_coins)

func unlock_insect(index: int, insect_data: Dictionary) -> void:
	if index not in unlocked_insects:
		unlocked_insects.append(index)
		insect_unlocked.emit(index, insect_data.get("name", "???"))
		print("[GameManager] Insecto desbloqueado: %s" % insect_data.get("name", "???"))

func has_unlocked_insect(index: int) -> bool:
	return index in unlocked_insects

func get_unlocked_insect_count() -> int:
	return unlocked_insects.size()

# --- Progreso de incógnitos (persiste entre niveles) ---
# Se guarda con clave String a propósito: JSON solo admite claves string,
# así que tras un save/load un Dictionary con claves int quedaría con
# claves string y las búsquedas por int fallarían silenciosamente.

func get_mystery_progress(index: int) -> float:
	return float(mystery_progress.get(str(index), 0.0))

func add_mystery_progress(index: int, amount: float) -> float:
	var new_value: float = get_mystery_progress(index) + amount
	mystery_progress[str(index)] = new_value
	return new_value

# --- Historia / narrativa ---

func mark_story_seen() -> void:
	story_seen = true
	SaveManager.save_game(_build_save_dict())

func has_seen_chapter_intro(chapter: int) -> bool:
	return chapter in seen_chapter_intros

func mark_chapter_intro_seen(chapter: int) -> void:
	if chapter not in seen_chapter_intros:
		seen_chapter_intros.append(chapter)
		SaveManager.save_game(_build_save_dict())

func has_seen_difficulty_warning(tier: int) -> bool:
	return tier in seen_difficulty_tiers

func mark_difficulty_warning_seen(tier: int) -> void:
	if tier not in seen_difficulty_tiers:
		seen_difficulty_tiers.append(tier)
		SaveManager.save_game(_build_save_dict())

func set_shop_grid_view(grid: bool) -> void:
	shop_grid_view = grid
	SaveManager.save_game(_build_save_dict())

## Cuál es el próximo mini tutorial que corresponde mostrar, según el
## estado real del jugador. Devuelve "" si no toca ninguno.
##
## El orden importa: se devuelve el PRIMERO que aplique, así nunca se
## encadenan dos tutoriales seguidos en el mismo nivel.
func get_pending_tutorial() -> String:
	# Jefe: antes de entrar al primero. Es el que más se necesita, porque
	# la pelea funciona distinto a un nivel normal.
	if level_manager.is_boss_level(current_level) and not _seen("jefe"):
		return "jefe"

	# Poderes: apenas comprás uno, para que sepas que el botón existe y
	# que cada uso cuesta monedas.
	if not _seen("poderes") and not ItemSystem.get_owned_powers(items).is_empty():
		return "poderes"

	# Objetos pasivos: cuando ya tenés plata para el más barato y todavía
	# no compraste ninguno.
	if not _seen("objetos") and items.is_empty() and player_coins >= TUTORIAL_ITEMS_COINS:
		return "objetos"

	# Tienda: cuando te alcanza para la primera arma.
	if not _seen("tienda") and unlocked_weapons.size() <= 1 and player_coins >= TUTORIAL_SHOP_COINS:
		return "tienda"

	# Vidas: la primera vez que perdés una.
	if not _seen("vidas") and player_lives < MAX_LIVES:
		return "vidas"

	# Combo: la primera vez que encadenaste unos cuantos.
	if not _seen("combo") and combo_max >= TUTORIAL_COMBO_HITS:
		return "combo"

	return ""

func _seen(tutorial_id: String) -> bool:
	return tutorial_id in seen_tutorials

func mark_tutorial_shown(tutorial_id: String) -> void:
	if tutorial_id not in seen_tutorials:
		seen_tutorials.append(tutorial_id)
		SaveManager.save_game(_build_save_dict())

func has_seen_story_beat(level: int) -> bool:
	return level in seen_story_beats

func mark_story_beat_seen(level: int) -> void:
	if level not in seen_story_beats:
		seen_story_beats.append(level)
		SaveManager.save_game(_build_save_dict())

func _build_save_dict() -> Dictionary:
	return {
		"current_level": current_level,
		"coins": player_coins,
		"unlocked_insects": unlocked_insects,
		"unlocked_weapons": unlocked_weapons,
		"equipped_weapon": equipped_weapon,
		"skill_tree": skill_tree,
		"items": items,
		"shop_grid_view": shop_grid_view,
		"mystery_progress": mystery_progress,
		"story_seen": story_seen,
		"seen_chapter_intros": seen_chapter_intros,
		"seen_difficulty_tiers": seen_difficulty_tiers,
		"seen_tutorials": seen_tutorials,
		"seen_story_beats": seen_story_beats,
		"max_level_unlocked": max_level_unlocked,
		"player_lives": player_lives,
		"lives_timestamp": lives_timestamp,
	}

# --- Vidas ---

## Suma las vidas que correspondan por el tiempo transcurrido desde la
## última cuenta. Se llama al cargar y cada vez que alguien consulta.
func _regenerate_lives() -> void:
	if player_lives >= MAX_LIVES:
		lives_timestamp = int(Time.get_unix_time_from_system())
		return
	var now := int(Time.get_unix_time_from_system())
	var elapsed: int = maxi(now - lives_timestamp, 0)
	var earned: int = int(elapsed / LIFE_REGEN_SECONDS)
	if earned <= 0:
		return
	player_lives = mini(player_lives + earned, MAX_LIVES)
	# Solo consume el tiempo que se usó, no el sobrante: si faltaban 2
	# minutos para la próxima vida, esos 2 minutos siguen contando.
	lives_timestamp += earned * LIFE_REGEN_SECONDS
	if player_lives >= MAX_LIVES:
		lives_timestamp = now
	lives_changed.emit(player_lives)

func get_lives() -> int:
	_regenerate_lives()
	return player_lives

func has_lives() -> bool:
	return get_lives() > 0

## Segundos que faltan para la próxima vida, o 0 si están llenas.
func seconds_until_next_life() -> int:
	_regenerate_lives()
	if player_lives >= MAX_LIVES:
		return 0
	var now := int(Time.get_unix_time_from_system())
	var elapsed: int = maxi(now - lives_timestamp, 0)
	return maxi(LIFE_REGEN_SECONDS - elapsed, 0)

func lose_life() -> int:
	_regenerate_lives()
	if player_lives == MAX_LIVES:
		# Recién ahora empieza a correr el reloj de regeneración.
		lives_timestamp = int(Time.get_unix_time_from_system())
	player_lives = maxi(player_lives - 1, 0)
	lives_changed.emit(player_lives)
	SaveManager.save_game(_build_save_dict())
	return player_lives

## Recarga todas las vidas pagando monedas. Devuelve false si no alcanza
## o si ya estaban llenas.
func refill_lives_with_coins() -> bool:
	_regenerate_lives()
	if player_lives >= MAX_LIVES:
		return false
	if player_coins < REFILL_LIVES_COST:
		return false
	player_coins -= REFILL_LIVES_COST
	player_lives = MAX_LIVES
	lives_timestamp = int(Time.get_unix_time_from_system())
	coins_changed.emit(player_coins)
	lives_changed.emit(player_lives)
	SaveManager.save_game(_build_save_dict())
	return true

## Se llama al perder una pelea de jefe. No toca el progreso de niveles.
func on_level_failed() -> int:
	return lose_life()

# --- Consultas de nivel ---

func is_level_unlocked(level: int) -> bool:
	return level <= max_level_unlocked

func is_boss_level(level: int) -> bool:
	return level_manager.is_boss_level(level)

## Capítulo más alto al que se puede entrar. Se calcula del tope
## desbloqueado y NO de current_chapter, porque al rejugar un nivel viejo
## current_chapter retrocede y si no se bloquearían capítulos ya ganados.
func get_max_chapter_unlocked() -> int:
	return level_manager.get_chapter_for_level(max_level_unlocked)

# --- Armas ---

func get_weapon_damage() -> int:
	var base_damage := int(WeaponSystem.get_weapon_data(equipped_weapon).get("damage", 1))
	var scaled := base_damage * skill_system.get_damage_multiplier(skill_tree)
	# Los guantes suman daño PLANO y se aplican después del multiplicador
	# del árbol: si se sumaran antes, la rama Fuerza los escalaría y dos
	# mejoras baratas se volverían enormes juntas.
	return int(round(scaled)) + ItemSystem.get_bonus_damage(items)

func get_weapon_radius() -> float:
	var base_radius := float(WeaponSystem.get_weapon_data(equipped_weapon).get("radius", 50.0))
	return base_radius + skill_system.get_radius_bonus(skill_tree) + ItemSystem.get_bonus_radius(items)

## Compra (o sube un nivel de) un objeto pasivo. Devuelve si se pudo.
func purchase_item(item_id: String) -> bool:
	var cost := ItemSystem.get_cost(items, item_id)
	if cost < 0 or player_coins < cost:
		return false
	player_coins -= cost
	items[item_id] = ItemSystem.get_level(items, item_id) + 1
	coins_changed.emit(player_coins)
	SaveManager.save_game(_build_save_dict())
	return true

## Corazones en las peleas de jefe: los base más los del botiquín.
func get_boss_max_hp(base_hp: int) -> int:
	return base_hp + ItemSystem.get_bonus_hearts(items)

func purchase_weapon(weapon_name: String) -> bool:
	if weapon_name in unlocked_weapons:
		return false
	var price := WeaponSystem.get_price(weapon_name)
	if player_coins < price:
		return false
	player_coins -= price
	unlocked_weapons.append(weapon_name)
	coins_changed.emit(player_coins)
	return true

func equip_weapon(weapon_name: String) -> bool:
	if weapon_name not in unlocked_weapons:
		return false
	equipped_weapon = weapon_name
	return true

# --- Habilidades ---

func purchase_skill(branch: String) -> bool:
	if not skill_system.can_purchase(skill_tree, branch, player_coins):
		return false
	var cost := skill_system.get_cost_for_next_tier(skill_tree, branch)
	player_coins -= cost
	skill_tree = skill_system.purchase(skill_tree, branch)
	coins_changed.emit(player_coins)
	return true
