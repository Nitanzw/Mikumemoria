extends Node2D

## Controlador de la escena de juego: fondo, spawner de insectos, HUD
## y pantalla de fin de nivel. Espera que GameManager.current_level ya
## esté configurado (start_level) antes de entrar a esta escena.

const InsectScene := preload("res://scenes/insect.tscn")
const MysteryBugScene := preload("res://scenes/mystery_bug.tscn")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const BossScene := preload("res://scenes/boss.tscn")
const BossProjectileScene := preload("res://scenes/effects/boss_projectile.tscn")

const MAX_INSECTS_ON_SCREEN := 9
const SPAWN_MARGIN := 60.0

## Vida de Sofía en las peleas de jefe. Se muestra como barra propia y,
## al llegar a 0, se pierde una de las 3 vidas del sistema global.
const PLAYER_MAX_HP := 5
## Cuando un minion invocado llega hasta Sofía, le saca esto.
const MINION_CONTACT_DAMAGE := 1
const MINION_SPEED_MULT := 2.0
const MINION_CYCLE_SPEED := 1.1
## Cada cuánto muerde un minion que ya se te prendió encima.
const BITE_INTERVAL := 1.1

## Música. TRACK_STEP es primo respecto de la cantidad de pistas para que
## la rotación no quede emparejada con los niveles de jefe (cada 5).
const MUSIC_TRACK_COUNT := 14
const TRACK_STEP := 5
const BOSS_TRACK := "boss_theme"
const BOSS_FALLBACK_TRACK := 8
const MUSIC_FADE := 1.2
## Radio alrededor de Sofía donde un proyectil o minion cuenta como golpe.
const PLAYER_HURT_RADIUS := 85.0

@onready var background: Sprite2D = $Background
@onready var insect_container: Node2D = $InsectContainer
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud = $HUD
@onready var level_complete_ui = $LevelComplete
@onready var sofia_sprite: Sprite2D = $Player/SofiaSprite

var level_config: Dictionary = {}
var time_remaining: float = 30.0
var level_ended: bool = false
var gameplay_started: bool = false
var _entry_chapter: int = 1

# --- Estado de pelea de jefe ---
var is_boss_level: bool = false
var boss: Boss = null
var boss_config: Dictionary = {}
var player_hp: int = PLAYER_MAX_HP
## Máximo real de la pelea: PLAYER_MAX_HP más los corazones del botiquín.
var player_max_hp: int = PLAYER_MAX_HP
## Golpes recibidos en la pelea, para el bloqueo del Delantal Reforzado.
var _hits_taken: int = 0
## Minions prendidos a Sofía -> segundos que faltan para el próximo
## mordisco. Se limpia al morir el minion o al terminar la pelea.
var _biting: Dictionary = {}
var _projectiles: Array = []
var _boss_minions: Array = []

func _ready() -> void:
	GameManager.start_level(GameManager.current_level)
	level_config = GameManager.get_current_level_config()
	_entry_chapter = GameManager.current_chapter

	_play_chapter_music()
	_setup_background()

	time_remaining = float(level_config.get("time_limit", 30))
	hud.set_level_label(GameManager.current_level, level_config.get("chapter_name", ""))
	hud.set_time(time_remaining)
	hud.set_score(0)
	hud.set_coins(GameManager.player_coins)
	hud.set_combo(0)

	GameManager.score_changed.connect(hud.set_score)
	GameManager.coins_changed.connect(hud.set_coins)
	GameManager.combo_changed.connect(hud.set_combo)

	level_complete_ui.next_level_pressed.connect(_on_next_level_pressed)
	level_complete_ui.menu_pressed.connect(_on_menu_pressed)
	level_complete_ui.retry_pressed.connect(_on_retry_pressed)

	spawn_timer.wait_time = level_config.get("spawn_rate", 2.0)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	is_boss_level = bool(level_config.get("is_boss", false))
	if is_boss_level:
		var boss_id: int = int(level_config.get("boss_id", 1))
		var cycle: int = GameManager.level_manager.get_boss_cycle(GameManager.current_level)
		var tier: int = GameManager.level_manager.get_difficulty_tier(GameManager.current_level)
		boss_config = BossData.get_boss_config(boss_id, cycle, tier)
		hud.setup_boss_bars(GameManager.get_boss_max_hp(PLAYER_MAX_HP), str(boss_config.get("name", "Jefe")))

	_maybe_show_intros()

func _process(delta: float) -> void:
	if level_ended or not gameplay_started:
		return

	time_remaining -= delta
	hud.set_time(max(time_remaining, 0.0))

	if is_boss_level:
		_process_boss_fight(delta)

	if time_remaining <= 0.0:
		if is_boss_level:
			# Se acabó el tiempo con el jefe vivo: se pierde una vida.
			_lose_boss_fight("Se acabó el tiempo")
		else:
			_end_level()

func _maybe_show_intros() -> void:
	# Encadena: intro de capítulo (primera vez que se entra a ese
	# capítulo) -> tutorial (solo nivel 1, primera vez) -> arranca el
	# nivel. El tiempo del nivel no corre mientras se muestra un diálogo.
	var chapter: int = GameManager.current_chapter
	if not GameManager.has_seen_chapter_intro(chapter):
		var lines: Array = StoryData.get_chapter_intro(chapter)
		GameManager.mark_chapter_intro_seen(chapter)
		if not lines.is_empty():
			_show_dialogue(lines, _maybe_show_tutorial)
			return
	_maybe_show_tutorial()

func _maybe_show_tutorial() -> void:
	if GameManager.current_level == 1 and not GameManager.tutorial_seen:
		GameManager.mark_tutorial_seen()
		_show_dialogue(StoryData.TUTORIAL, _maybe_warn_difficulty)
		return
	_maybe_warn_difficulty()

## Cada 10 niveles, Sofía avisa que los bichos se pusieron más duros y que
## conviene ir a mejorar. Se muestra una sola vez por escalón: rejugar el
## nivel 10 no repite el cartel.
func _maybe_warn_difficulty() -> void:
	var level: int = GameManager.current_level
	if not GameManager.level_manager.is_difficulty_step(level):
		_start_gameplay()
		return

	var tier: int = GameManager.level_manager.get_difficulty_tier(level)
	if GameManager.has_seen_difficulty_warning(tier):
		_start_gameplay()
		return

	GameManager.mark_difficulty_warning_seen(tier)
	var lines: Array = StoryData.get_difficulty_warning(tier)
	if lines.is_empty():
		_start_gameplay()
		return
	_show_dialogue(lines, _start_gameplay)

func _show_dialogue(lines: Array, on_finished: Callable) -> void:
	var box := DialogueBoxScene.instantiate()
	add_child(box)
	box.finished.connect(on_finished)
	box.show_dialogue(lines)

func _start_gameplay() -> void:
	if level_ended:
		return
	gameplay_started = true

	if is_boss_level:
		# En la pelea de jefe el spawner normal no corre: los únicos
		# insectos que aparecen son los que invoca el jefe.
		_spawn_boss()
		return

	spawn_timer.start()

	if level_config.get("has_mystery_bug", false) and not GameManager.has_unlocked_insect(level_config.get("mystery_index", 0)):
		await get_tree().create_timer(1.0).timeout
		if not level_ended:
			_spawn_mystery_bug()

# --- Pelea de jefe ---

func _spawn_boss() -> void:
	player_max_hp = GameManager.get_boss_max_hp(PLAYER_MAX_HP)
	player_hp = player_max_hp
	_hits_taken = 0
	hud.set_player_hp(player_hp, player_max_hp)

	boss = BossScene.instantiate() as Boss
	insect_container.add_child(boss)
	boss.global_position = Vector2(get_viewport_rect().size.x / 2.0, 200.0)
	boss.setup(boss_config)

	boss.health_changed.connect(hud.set_boss_hp)
	boss.shield_changed.connect(hud.set_boss_shield)
	boss.ability_announced.connect(hud.announce)
	boss.died.connect(_on_boss_died)
	boss.wants_summon.connect(_on_boss_wants_summon)
	boss.wants_projectile.connect(_on_boss_wants_projectile)
	boss.hit_player.connect(_damage_player)
	boss.stole_coins.connect(_on_boss_stole_coins)

	hud.announce(str(boss_config.get("taunt", "")))

func _process_boss_fight(delta: float) -> void:
	if not is_instance_valid(boss):
		return

	var player_pos := _player_position()
	boss.set_player_position(player_pos)

	# Proyectiles que llegan a Sofía
	for projectile in _projectiles.duplicate():
		if not is_instance_valid(projectile):
			_projectiles.erase(projectile)
			continue
		if projectile.distance_to_point(player_pos) < PLAYER_HURT_RADIUS:
			projectile.pop()
			_projectiles.erase(projectile)
			_damage_player(1)

	# Minions que llegan hasta Sofía. Antes tocaban, hacían 1 de daño y
	# desaparecían solos: no había nada que reaccionar, el daño ya estaba
	# hecho. Ahora se le PRENDEN y siguen mordiendo cada BITE_INTERVAL
	# hasta que los aplastes, así que sacártelos rápido importa.
	for minion in _boss_minions.duplicate():
		if not is_instance_valid(minion):
			_boss_minions.erase(minion)
			_biting.erase(minion)
			if is_instance_valid(boss):
				boss.on_minion_died()
			continue

		var latched: bool = minion in _biting
		if not latched and minion.global_position.distance_to(player_pos) < PLAYER_HURT_RADIUS:
			latched = true
			_biting[minion] = 0.0     # el primer mordisco es inmediato
			minion.speed = 0.0        # se queda encima de ella
			hud.announce("¡Se te prendió uno! Aplastalo")

		if latched:
			# Se lo mantiene pegado a Sofía para que se vea qué hay que tocar.
			minion.global_position = minion.global_position.lerp(player_pos, delta * 8.0)
			_biting[minion] -= delta
			if _biting[minion] <= 0.0:
				_biting[minion] = BITE_INTERVAL
				_damage_player(MINION_CONTACT_DAMAGE)

func _player_position() -> Vector2:
	if sofia_sprite:
		return sofia_sprite.global_position
	var view := get_viewport_rect().size
	return Vector2(view.x / 2.0, view.y - 60.0)

func _on_boss_wants_summon(count: int) -> void:
	if count <= 0:
		_spawn_boss_decoys()
		return
	# Los minions iban a 1.1x y llegaban tardísimo: daban tiempo de sobra
	# para limpiarlos sin despeinarse, que era buena parte de por qué la
	# pelea se sentía fácil. Ahora van rápido de verdad, y más todavía en
	# las vueltas siguientes al roster de jefes.
	var cycle: int = GameManager.level_manager.get_boss_cycle(GameManager.current_level)
	var minion_speed: float = MINION_SPEED_MULT * pow(MINION_CYCLE_SPEED, cycle)
	minion_speed *= ItemSystem.get_minion_slow(GameManager.items)
	for i in range(count):
		var types: Array = BossData.SUMMON_POOL
		var minion := InsectScene.instantiate() as Insect
		minion.insect_type = types[randi() % types.size()]
		minion.speed_mult = minion_speed
		insect_container.add_child(minion)
		var view := get_viewport_rect().size
		minion.global_position = boss.global_position + Vector2(randf_range(-120.0, 120.0), randf_range(20.0, 90.0))
		# Los minions van derecho hacia Sofía: son una amenaza, no adorno.
		minion.direction = (_player_position() - minion.global_position).normalized()
		_boss_minions.append(minion)

## Copias de `split`: mismo sprite, mueren de un golpe, y confunden cuál
## es el jefe real.
func _spawn_boss_decoys() -> void:
	if not is_instance_valid(boss):
		return
	var view := get_viewport_rect().size
	for i in range(2):
		var decoy := BossScene.instantiate() as Boss
		insect_container.add_child(decoy)
		decoy.global_position = Vector2(randf_range(120.0, view.x - 120.0), boss.global_position.y + randf_range(-40.0, 40.0))
		decoy.setup(boss_config)
		decoy.is_decoy = true

func _on_boss_wants_projectile(from: Vector2) -> void:
	var projectile := BossProjectileScene.instantiate()
	add_child(projectile)
	projectile.launch(from, _player_position())
	_projectiles.append(projectile)

func _on_boss_stole_coins(amount: int) -> void:
	GameManager.add_coins(-mini(amount, GameManager.player_coins))
	hud.announce("¡Te robó %d monedas!" % amount)

func _damage_player(amount: int) -> void:
	if level_ended:
		return

	# Delantal Reforzado: bloquea uno de cada N golpes. Se cuentan los
	# golpes recibidos, no se tira al azar, para que el jugador pueda
	# confiar en cuándo le toca aguantar uno.
	var block_every := ItemSystem.get_block_every(GameManager.items)
	_hits_taken += 1
	if block_every > 0 and _hits_taken % block_every == 0:
		hud.announce("¡El delantal te salvó!")
		hud.flash_damage()
		return

	player_hp = maxi(player_hp - amount, 0)
	hud.set_player_hp(player_hp, player_max_hp)
	hud.flash_damage()
	AudioManager.play_sfx("taunt")

	if player_hp <= 0:
		_lose_boss_fight("Sofía no aguantó")

func _on_boss_died() -> void:
	if level_ended:
		return
	hud.announce("¡Lo venciste!")
	_end_level()

func _lose_boss_fight(reason: String) -> void:
	if level_ended:
		return
	level_ended = true
	spawn_timer.stop()
	_biting.clear()
	for child in insect_container.get_children():
		child.queue_free()

	var lives_left := GameManager.on_level_failed()
	level_complete_ui.show_defeat(reason, lives_left)

func _play_chapter_music() -> void:
	AudioManager.play_music(_pick_track(), MUSIC_FADE)

## Qué pista suena en este nivel.
##
## Antes se elegía por CAPÍTULO — y un capítulo son 100 niveles, así que
## te comías `level_theme_1` cien veces seguidas mientras las otras nueve
## pistas no sonaban nunca. Ahora rota por nivel.
##
## La rotación no es `nivel % 10`: eso hace que los jefes (múltiplos de 5)
## caigan siempre en las mismas dos pistas. Se usa un paso primo para que
## el ciclo tarde en repetirse y no quede emparejado con nada del juego.
func _pick_track() -> String:
	var level: int = GameManager.current_level

	# Las peleas de jefe tienen su propia pista si existe; si no, se les
	# reserva la más intensa del set en vez de sonar como un nivel normal.
	if is_boss_level:
		if AudioManager.has_music(BOSS_TRACK):
			return BOSS_TRACK
		return "level_theme_%d" % BOSS_FALLBACK_TRACK

	var available: Array = []
	for i in range(1, MUSIC_TRACK_COUNT + 1):
		var name := "level_theme_%d" % i
		if AudioManager.has_music(name):
			available.append(name)
	if available.is_empty():
		return "level_theme_1"

	var index: int = ((level - 1) * TRACK_STEP) % available.size()
	return available[index]

func _setup_background() -> void:
	# Con stretch/aspect="expand" el viewport real es más alto que los
	# 540x960 de diseño (en un celular 19.5:9 son ~540x1170), así que el
	# fondo y Sofía no pueden quedar en coordenadas fijas: se escalan
	# y reubican contra el tamaño real para que no queden huecos ni un
	# Sofía flotando en el medio de la pantalla.
	var path: String = level_config.get("background", "")
	if background and path != "" and ResourceLoader.exists(path):
		background.texture = load(path)

	var view_size := get_viewport_rect().size

	if background and background.texture:
		var tex_size := background.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			# "cover": la escala más grande de las dos, así siempre tapa
			# todo el viewport aunque sobre por un lado.
			var cover: float = maxf(view_size.x / tex_size.x, view_size.y / tex_size.y)
			background.scale = Vector2(cover, cover)
		background.position = view_size / 2.0

	if sofia_sprite:
		sofia_sprite.position = Vector2(view_size.x / 2.0, view_size.y - 60.0)

func _on_spawn_timer_timeout() -> void:
	if level_ended:
		return
	if insect_container.get_child_count() >= MAX_INSECTS_ON_SCREEN:
		return
	_spawn_random_insect()

func _spawn_random_insect() -> void:
	var types: Array = level_config.get("enemy_types", [])
	if types.is_empty():
		types = ["hormiga_obrera"]

	var insect_type: String = types[randi() % types.size()]
	var insect := InsectScene.instantiate() as Insect
	insect.insect_type = insect_type
	insect.speed_mult = level_config.get("enemy_speed_mult", 1.0)
	insect.health_bonus = int(level_config.get("enemy_health_bonus", 0))

	insect_container.add_child(insect)
	var spawn_pos := _random_edge_position()
	insect.global_position = spawn_pos
	insect.direction = (_screen_center() - spawn_pos).normalized()

func _spawn_mystery_bug() -> void:
	var bug := MysteryBugScene.instantiate() as MysteryBug
	insect_container.add_child(bug)
	bug.global_position = _screen_center()

func _random_edge_position() -> Vector2:
	var size := get_viewport_rect().size
	var edge := randi() % 4
	match edge:
		0:
			return Vector2(randf_range(0.0, size.x), -SPAWN_MARGIN)
		1:
			return Vector2(size.x + SPAWN_MARGIN, randf_range(0.0, size.y))
		2:
			return Vector2(randf_range(0.0, size.x), size.y + SPAWN_MARGIN)
		_:
			return Vector2(-SPAWN_MARGIN, randf_range(0.0, size.y))

func _screen_center() -> Vector2:
	return get_viewport_rect().size / 2.0

func _end_level() -> void:
	level_ended = true
	spawn_timer.stop()

	for insect in insect_container.get_children():
		insect.queue_free()

	AudioManager.play_sfx("level_complete")
	var reward := GameManager.on_level_complete()
	level_complete_ui.show_results(GameManager.player_score, GameManager.combo_max, reward, is_boss_level)

func _on_next_level_pressed() -> void:
	if GameManager.current_chapter != _entry_chapter:
		# Cruzó a un capítulo nuevo: mostrar el mapa de mundos en vez de
		# saltar directo al siguiente nivel, para que se vea el avance.
		get_tree().change_scene_to_file("res://scenes/menu/world_map.tscn")
	else:
		get_tree().reload_current_scene()

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
