extends Node

## GAME MANAGER - Control central del juego (autoload "GameManager").
## Sin class_name: coincidiría con el nombre del autoload y Godot
## rechaza esa combinación al compilar ("class already exists as
## autoload"). Se accede siempre como el singleton global GameManager.

# --- Progreso del jugador ---
var current_level: int = 1
var current_chapter: int = 1
var player_coins: int = 0
var player_score: int = 0
var combo_hits: int = 0
var combo_max: int = 0

# --- Desbloqueos ---
var unlocked_insects: Array = []          # índices de insectos incógnito revelados
var unlocked_weapons: Array = ["zapato_viejo"]
var equipped_weapon: String = "zapato_viejo"
var skill_tree: Dictionary = {}

# Progreso de revelación de cada incógnito (índice -> puntos acumulados).
# Persiste entre niveles porque un mismo incógnito aparece durante los
# 9 niveles previos a cada múltiplo de 10 (ver LevelManager.has_mystery_bug).
var mystery_progress: Dictionary = {}

# --- Historia / narrativa ---
var story_seen: bool = false
var tutorial_seen: bool = false
var seen_chapter_intros: Array = []   # capítulos (int) cuya intro ya se mostró
var force_show_story: bool = false    # flag transitorio (no se guarda), para "ver de nuevo" desde el menú

# --- Helpers internos (no son autoload, son instancias propias) ---
var level_manager := LevelManager.new()
var skill_system := SkillSystem.new()

# --- Señales ---
signal level_started(level: int)
signal level_completed(level: int)
signal insect_unlocked(index: int, insect_name: String)
signal score_changed(new_score: int)
signal coins_changed(new_coins: int)
signal combo_changed(combo: int)

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
		mystery_progress = data.get("mystery_progress", {})
		story_seen = bool(data.get("story_seen", false))
		tutorial_seen = bool(data.get("tutorial_seen", false))
		seen_chapter_intros = data.get("seen_chapter_intros", [])
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
	mystery_progress = {}
	story_seen = false
	tutorial_seen = false
	seen_chapter_intros = []

func start_level(level: int) -> void:
	current_level = level
	current_chapter = level_manager.get_chapter_for_level(level)
	player_score = 0
	combo_hits = 0
	combo_max = 0

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
	combo_hits = 0
	combo_changed.emit(combo_hits)
	AudioManager.play_sfx("taunt")

func on_level_complete() -> int:
	var finished_level := current_level
	var reward := calculate_level_reward()
	add_coins(reward)

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
	return int(round(total * skill_system.get_coin_multiplier(skill_tree)))

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

func mark_tutorial_seen() -> void:
	tutorial_seen = true
	SaveManager.save_game(_build_save_dict())

func has_seen_chapter_intro(chapter: int) -> bool:
	return chapter in seen_chapter_intros

func mark_chapter_intro_seen(chapter: int) -> void:
	if chapter not in seen_chapter_intros:
		seen_chapter_intros.append(chapter)
		SaveManager.save_game(_build_save_dict())

func _build_save_dict() -> Dictionary:
	return {
		"current_level": current_level,
		"coins": player_coins,
		"unlocked_insects": unlocked_insects,
		"unlocked_weapons": unlocked_weapons,
		"equipped_weapon": equipped_weapon,
		"skill_tree": skill_tree,
		"mystery_progress": mystery_progress,
		"story_seen": story_seen,
		"tutorial_seen": tutorial_seen,
		"seen_chapter_intros": seen_chapter_intros,
	}

# --- Armas ---

func get_weapon_damage() -> int:
	var base_damage := int(WeaponSystem.get_weapon_data(equipped_weapon).get("damage", 1))
	return int(round(base_damage * skill_system.get_damage_multiplier(skill_tree)))

func get_weapon_radius() -> float:
	var base_radius := float(WeaponSystem.get_weapon_data(equipped_weapon).get("radius", 50.0))
	return base_radius + skill_system.get_radius_bonus(skill_tree)

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
