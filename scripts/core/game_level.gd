extends Node2D

## Controlador de la escena de juego: fondo, spawner de insectos, HUD
## y pantalla de fin de nivel. Espera que GameManager.current_level ya
## esté configurado (start_level) antes de entrar a esta escena.

const InsectScene := preload("res://scenes/insect.tscn")
const MysteryBugScene := preload("res://scenes/mystery_bug.tscn")
const DialogueBoxScene := preload("res://scenes/ui/dialogue_box.tscn")
const BossScene := preload("res://scenes/boss.tscn")
const BossProjectileScene := preload("res://scenes/effects/boss_projectile.tscn")

## Antes eran 9 con un spawn cada 2s: la pantalla quedaba casi vacía y
## había que esperar. Con la mitad de los bichos pegados al borde (ver el
## arreglo en insect.gd) quedaban dos o tres realmente jugables.
const MAX_INSECTS_ON_SCREEN := 14
## Bichos ya presentes al arrancar, para no empezar mirando un huerto vacío.
const INITIAL_INSECTS := 4
const SPAWN_MARGIN := 60.0

## Vida de Sofía en las peleas de jefe. Se muestra como barra propia y,
## al llegar a 0, se pierde una de las 3 vidas del sistema global.
## Vida de Sofía en las peleas de jefe, en la misma escala que la del
## jefe: se muestra como número abajo, así que 1000 se lee mejor que 5.
## Los daños salen de la config del jefe (BossData.BASE_DAMAGE = 200 son
## cinco golpes, exactamente lo que aguantaba con 5 corazones).
const PLAYER_MAX_HP := 1000
## Cuando un minion invocado llega hasta Sofía, le saca esto.
## Los refuerzos y los escupitajos pegan menos que el jefe en persona.
const MINION_DAMAGE_FACTOR := 0.5
const PROJECTILE_DAMAGE_FACTOR := 0.75
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
@onready var player: Player = $Player
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
## Máximo real de la pelea: PLAYER_MAX_HP más la vida del botiquín.
var player_max_hp: int = PLAYER_MAX_HP
## Golpes recibidos en la pelea, para el bloqueo del Delantal Reforzado.
var _hits_taken: int = 0
## Minions prendidos a Sofía -> segundos que faltan para el próximo
## mordisco. Se limpia al morir el minion o al terminar la pelea.
var _biting: Dictionary = {}
## Usos de cámara lenta que quedan en este nivel, y si está activa ahora.
var _slowmo_active: bool = false
var _flames_active: bool = false
var _projectiles: Array = []
var _boss_minions: Array = []

func _ready() -> void:
	GameManager.start_level(GameManager.current_level)
	level_config = GameManager.get_current_level_config()
	_entry_chapter = GameManager.current_chapter

	# Tiene que quedar seteado ANTES de _setup_background(): esa función
	# usa is_boss_level para decidir a qué altura va Sofía, y si se asigna
	# después (como estaba) la posiciona siempre como en un nivel normal y
	# en las peleas queda tapada por el panel de vidas de abajo.
	is_boss_level = bool(level_config.get("is_boss", false))

	_play_chapter_music()
	_setup_background()
	_setup_borde_extremo()

	# Reloj de Arena: segundos extra de nivel. En las peleas de jefe
	# también suman, que es donde más se agradecen.
	time_remaining = float(level_config.get("time_limit", 30)) + ItemSystem.get_bonus_seconds(GameManager.items)
	_sortear_elites()
	# Hoy cada nivel recarga la escena y el Player nace limpio, así que
	# esto no cambia nada. Va igual porque el cartel del resumen ahora
	# depende de que los fallos sean DE ESTE nivel: si algún día se deja
	# de recargar, el dato se volvería acumulado sin que nadie lo note.
	if player:
		player.reset_stats()
	hud.set_level_label(GameManager.current_level, level_config.get("chapter_name", ""))
	hud.set_time(time_remaining)
	hud.set_score(0)
	hud.set_coins(GameManager.player_coins)
	hud.set_combo(0)

	GameManager.score_changed.connect(hud.set_score)
	GameManager.coins_changed.connect(hud.set_coins)
	GameManager.combo_changed.connect(hud.set_combo)

	hud.setup_powers(ItemSystem.get_owned_powers(GameManager.items))
	hud.refresh_power_affordability(GameManager.player_coins)
	hud.power_pressed.connect(_on_power_pressed)
	GameManager.coins_changed.connect(hud.refresh_power_affordability)
	if player:
		player.crit_landed.connect(_on_crit_landed)

	level_complete_ui.next_level_pressed.connect(_on_next_level_pressed)
	level_complete_ui.menu_pressed.connect(_on_menu_pressed)
	level_complete_ui.retry_pressed.connect(_on_retry_pressed)
	level_complete_ui.shop_pressed.connect(_on_shop_pressed)

	spawn_timer.wait_time = level_config.get("spawn_rate", 2.0)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	if is_boss_level:
		var boss_id: int = int(level_config.get("boss_id", 1))
		var cycle: int = GameManager.level_manager.get_boss_cycle(GameManager.current_level)
		var tier: int = GameManager.level_manager.get_difficulty_tier(GameManager.current_level)
		boss_config = BossData.get_boss_config(boss_id, cycle, tier, bool(level_config.get("hardcore", false)))
		hud.setup_boss_bars(GameManager.get_boss_max_hp(PLAYER_MAX_HP), str(boss_config.get("name", "Jefe")))

	_maybe_show_intros()

## Marco rojo palpitante en el Modo Extremo. Se agrega solo si el modo
## está activo, así el nivel normal no paga ni el _process de más.
func _setup_borde_extremo() -> void:
	if not bool(level_config.get("hardcore", false)):
		return
	var borde: CanvasLayer = load("res://scripts/ui/hardcore_border.gd").new()
	borde.name = "BordeExtremo"
	add_child(borde)

func _process(delta: float) -> void:
	if level_ended or not gameplay_started:
		return

	# delta viene escalado por Engine.time_scale, así que en cámara lenta
	# el reloj del nivel también se frenaría y el objeto haría dos cosas a
	# la vez (frenar bichos Y dar tiempo). Se lo devuelve a tiempo real
	# para que la cámara lenta sirva solo para apuntar mejor.
	time_remaining -= delta / maxf(Engine.time_scale, 0.01)
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

## Mini tutorial por HITO. Reemplaza al tutorial viejo, que soltaba las
## cinco reglas del juego de una antes del primer nivel y después no
## explicaba nada más — ni la tienda, ni los objetos, ni los poderes.
## Ahora cada consejo aparece cuando hace falta.
func _maybe_show_tutorial() -> void:
	var pending: String = GameManager.get_pending_tutorial()
	if pending == "":
		_maybe_show_story_beat()
		return

	GameManager.mark_tutorial_shown(pending)
	var lines: Array = StoryData.get_tutorial(pending)
	if lines.is_empty():
		_maybe_show_story_beat()
		return
	_show_dialogue(lines, _maybe_show_story_beat)

## Un pedacito de historia cada varios niveles. Cortos a propósito: la
## intro larga del arranque se partió en estos.
func _maybe_show_story_beat() -> void:
	var level: int = GameManager.current_level
	if GameManager.has_seen_story_beat(level):
		_maybe_warn_difficulty()
		return

	var lines: Array = StoryData.get_story_beat(level)
	if lines.is_empty():
		_maybe_warn_difficulty()
		return

	GameManager.mark_story_beat_seen(level)
	_show_dialogue(lines, _maybe_warn_difficulty)

## Cada 10 niveles, Sofía avisa que los bichos se pusieron más duros y que
## conviene ir a mejorar. Se muestra una sola vez por escalón: rejugar el
## nivel 10 no repite el cartel.
func _maybe_warn_difficulty() -> void:
	var level: int = GameManager.current_level
	if not GameManager.level_manager.is_difficulty_step(level):
		_start_gameplay()
		return

	var tier: int = GameManager.level_manager.get_difficulty_tier(level)
	# El aviso se recuerda por modo: el extremo arranca en el escalón 12,
	# y si compartiera la marca con el normal se comerían los avisos el
	# uno al otro (verías el del 12 en extremo y ya no te aparecería al
	# llegar al nivel 120 normal). El signo alcanza para separarlos sin
	# agregar otro campo al guardado.
	var clave: int = -tier if GameManager.hardcore else tier
	if GameManager.has_seen_difficulty_warning(clave):
		_start_gameplay()
		return

	GameManager.mark_difficulty_warning_seen(clave)
	var lines: Array = StoryData.get_difficulty_warning(tier)
	if lines.is_empty():
		_start_gameplay()
		return
	_show_dialogue(lines, _start_gameplay)

func _show_dialogue(lines: Array, on_finished: Callable, continuara: int = 0) -> void:
	var box := DialogueBoxScene.instantiate()
	add_child(box)
	box.finished.connect(on_finished)
	box.show_dialogue(lines, continuara)

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
	_spawn_initial_insects()

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
	# Debajo de la barra del HUD; si no, aparece medio tapado el primer frame.
	boss.global_position = Vector2(get_viewport_rect().size.x / 2.0, 250.0)

	# Las señales van ANTES de setup(): setup() emite health_changed con la
	# vida inicial, y conectando después ese primer aviso se perdía. Con
	# la barra vieja no se notaba (arrancaba llena por defecto), pero
	# ahora el número está a la vista y el jefe decía "0 / 0" hasta que
	# le pegabas por primera vez.
	boss.health_changed.connect(hud.set_boss_hp)
	boss.shield_changed.connect(hud.set_boss_shield)
	boss.ability_announced.connect(hud.announce)
	boss.died.connect(_on_boss_died)
	boss.wants_summon.connect(_on_boss_wants_summon)
	boss.wants_projectile.connect(_on_boss_wants_projectile)
	boss.hit_player.connect(_damage_player)
	boss.stole_coins.connect(_on_boss_stole_coins)

	boss.setup(boss_config)

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
			_damage_player(_scaled_damage(PROJECTILE_DAMAGE_FACTOR))

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
				_damage_player(_scaled_damage(MINION_DAMAGE_FACTOR))

## Daño de una fuente secundaria (refuerzo, escupitajo) como fracción del
## daño del jefe de este nivel, así todo escala junto con la dificultad.
func _scaled_damage(factor: float) -> int:
	var base: int = int(boss_config.get("damage", BossData.BASE_DAMAGE)) if boss_config else BossData.BASE_DAMAGE
	return maxi(int(round(base * factor)), 1)

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
	# Los minions también entran en el x2.5 del modo extremo: el pedido
	# fue "lo mismo para los minions".
	var minion_vida: float = float(level_config.get("enemy_health_mult", 1.0))
	minion_speed *= minion_vida
	for i in range(count):
		var types: Array = BossData.SUMMON_POOL
		var minion := InsectScene.instantiate() as Insect
		minion.insect_type = types[randi() % types.size()]
		minion.speed_mult = minion_speed
		minion.health_mult = minion_vida
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
	Engine.time_scale = 1.0
	spawn_timer.stop()
	_biting.clear()
	for child in insect_container.get_children():
		child.queue_free()

	var lives_left := GameManager.on_level_failed()
	level_complete_ui.show_defeat(reason, lives_left)

# --- Poderes activos ---
#
# Cada uso se paga en monedas. El cobro se hace ACÁ, en un solo lugar, y
# recién después se ejecuta el efecto: así ningún poder puede dispararse
# gratis si mañana se agrega otro.

## Engine.time_scale es GLOBAL y sobrevive al cambio de escena: si se sale
## del nivel con la cámara lenta activa (perdiendo, o tocando el menú),
## todo el juego queda en cámara lenta para siempre. Se restaura acá, que
## corre pase lo que pase al salir de la escena.
func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _on_power_pressed(power_id: String) -> void:
	if level_ended:
		return
	var cost := ItemSystem.get_power_use_cost(power_id)
	if GameManager.player_coins < cost:
		hud.announce("No te alcanzan las monedas")
		return

	var level := ItemSystem.get_level(GameManager.items, power_id)
	match power_id:
		"reloj_bolsillo":
			if _slowmo_active:
				return
			_use_slowmo(level)
		"campo_expansivo":
			_use_field(level)
		"tormenta_rayos":
			_use_storm(level)
		"lanzallamas":
			if _flames_active:
				return
			_use_flames(level)
		_:
			return

	GameManager.add_coins(-cost)

## Frena el juego un rato tocando Engine.time_scale, que afecta a TODO:
## insectos, jefe, minions y proyectiles se frenan juntos. El reloj del
## nivel se compensa aparte (ver _process).
func _use_slowmo(level: int) -> void:
	_slowmo_active = true
	hud.announce("Todo en cámara lenta")
	Engine.time_scale = ItemSystem.SLOWMO_SCALE

	# El timer corre en tiempo de juego (ya frenado), así que la espera se
	# acorta en la misma proporción para que dure los segundos REALES que
	# promete el objeto. Cada nivel del objeto suma un segundo.
	var seconds := (ItemSystem.SLOWMO_SECONDS + level - 1) * ItemSystem.SLOWMO_SCALE
	await get_tree().create_timer(seconds).timeout
	Engine.time_scale = 1.0
	_slowmo_active = false

## El próximo golpe abarca muchísimo más. No pega solo: hay que apuntar
## igual, que es lo que lo diferencia de la tormenta.
func _use_field(level: int) -> void:
	if not player:
		return
	player.next_hit_radius_mult = ItemSystem.FIELD_RADIUS_MULT + (level - 1) * 0.8
	hud.announce("¡Campo cargado! El próximo golpe es enorme")

## Un rayo a cada insecto de la pantalla. Al jefe también, salvo que esté
## protegido — ahí su propia lógica de invulnerabilidad lo frena.
func _use_storm(level: int) -> void:
	var damage := ItemSystem.STORM_DAMAGE_PER_LEVEL * level
	var count := 0
	for node in insect_container.get_children():
		if node is Insect and not node.is_dead:
			node.take_damage(damage)
			count += 1
		elif node is Boss:
			node.take_damage(damage, true)
	hud.announce("¡Tormenta! %d insectos alcanzados" % count)
	AudioManager.play_sfx("unlock")

## Quema todo lo que esté cerca de Sofía durante unos segundos, por
## tandas. A diferencia de la tormenta, hay que aguantar a que haga
## efecto y solo alcanza a lo que se acerque.
func _use_flames(level: int) -> void:
	_flames_active = true
	hud.announce("¡Fuego! Que se acerquen si quieren")
	var radius := ItemSystem.FLAME_RADIUS + (level - 1) * 40.0
	var ticks := int(ItemSystem.FLAME_SECONDS / ItemSystem.FLAME_TICK)
	for _i in range(ticks):
		if level_ended:
			break
		var origin := _player_position()
		for node in insect_container.get_children():
			if node is Insect and not node.is_dead and node.global_position.distance_to(origin) <= radius:
				node.take_damage(ItemSystem.FLAME_DAMAGE)
			elif node is Boss and node.global_position.distance_to(origin) <= radius:
				node.take_damage(ItemSystem.FLAME_DAMAGE, true)
		await get_tree().create_timer(ItemSystem.FLAME_TICK).timeout
	_flames_active = false

## Aviso de golpe crítico. Va por el HUD y no por un cartel nuevo para no
## sumar más cosas encima de la pantalla.
func _on_crit_landed(_at: Vector2) -> void:
	hud.announce("¡Crítico!")

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
		# Sofía queda OCULTA durante la partida: abajo del todo, recortada
		# por el borde y sin animación, se veía mal y no aportaba nada
		# jugable. El nodo se conserva igual porque marca el punto al que
		# apuntan las embestidas y los escupitajos del jefe, y ese punto
		# tiene que seguir subiendo en las peleas para no caer detrás del
		# panel de vidas de abajo.
		var from_bottom: float = 265.0 if is_boss_level else 60.0
		sofia_sprite.position = Vector2(view_size.x / 2.0, view_size.y - from_bottom)

## Siembra los primeros bichos ya ADENTRO de la pantalla (no en el borde),
## así el nivel arranca con acción a la vista en vez de con el huerto vacío.
func _spawn_initial_insects() -> void:
	var view := get_viewport_rect().size
	for i in range(INITIAL_INSECTS):
		var insect := _spawn_random_insect()
		if not insect:
			continue
		# Debajo del panel del HUD y arriba de Sofía, que es donde se los
		# ve y se los puede tapear cómodo.
		insect.global_position = Vector2(
			randf_range(view.x * 0.15, view.x * 0.85),
			randf_range(view.y * 0.28, view.y * 0.72))
		insect.randomize_direction()

func _on_spawn_timer_timeout() -> void:
	if level_ended:
		return
	if insect_container.get_child_count() >= MAX_INSECTS_ON_SCREEN:
		return
	_spawn_random_insect()

## Cuántos élites por nivel. Pocos y siempre algunos: son el pico de
## tensión del nivel, no la norma.
const ELITES_MIN := 3
const ELITES_MAX := 6

## Índices de aparición que van a salir élite, y el contador que los va
## consumiendo.
var _elite_spawns: Dictionary = {}
var _spawn_index: int = 0

## Reparte los élites entre las apariciones estimadas del nivel.
##
## Se eligen índices y no se tira una moneda por bicho: con una
## probabilidad suelta un nivel puede salir sin ningún élite y el
## siguiente con doce, y el jugador no puede contar con nada.
func _sortear_elites() -> void:
	_elite_spawns.clear()
	_spawn_index = 0
	if is_boss_level:
		return

	var cadencia: float = maxf(float(level_config.get("spawn_rate", 2.0)), 0.1)
	# Los primeros bichos ya están sembrados al arrancar (ver
	# _spawn_initial_insects), así que entran en la cuenta.
	var estimadas: int = INITIAL_INSECTS + int(time_remaining / cadencia)
	var cuantos: int = mini(randi_range(ELITES_MIN, ELITES_MAX), estimadas)
	if cuantos <= 0:
		return

	# El primero no: que el nivel arranque con un élite en pantalla antes
	# de que el jugador se acomode se siente injusto.
	var candidatos: Array[int] = []
	for i in range(1, estimadas):
		candidatos.append(i)
	candidatos.shuffle()
	for i in candidatos.slice(0, cuantos):
		_elite_spawns[i] = true

func _spawn_random_insect() -> Insect:
	var types: Array = level_config.get("enemy_types", [])
	if types.is_empty():
		types = ["hormiga_obrera"]

	var insect_type: String = types[randi() % types.size()]
	var insect := InsectScene.instantiate() as Insect
	insect.insect_type = insect_type
	insect.speed_mult = level_config.get("enemy_speed_mult", 1.0)
	insect.health_bonus = int(level_config.get("enemy_health_bonus", 0))
	insect.health_mult = float(level_config.get("enemy_health_mult", 1.0))
	# El élite se marca ANTES de meterlo al árbol: initialize_by_type corre
	# en _ready y necesita el flag para calcular vida y recompensa.
	insect.is_elite = _spawn_index in _elite_spawns
	_spawn_index += 1

	insect_container.add_child(insect)
	var spawn_pos := _random_edge_position()
	insect.global_position = spawn_pos
	insect.direction = (_screen_center() - spawn_pos).normalized()
	return insect

func _spawn_mystery_bug() -> void:
	var bug := MysteryBugScene.instantiate() as MysteryBug
	insect_container.add_child(bug)
	bug.global_position = _screen_center()

## Punto de aparición, siempre fuera de la pantalla.
##
## El borde de ARRIBA quedó afuera: está detrás de la barra del HUD, así
## que los bichos que entraban por ahí aparecían tapados y había que
## adivinarlos. Entran por los costados o por abajo, y en los costados
## nunca por encima de la barra.
func _random_edge_position() -> Vector2:
	var size := get_viewport_rect().size
	var top := Insect.PLAY_TOP_INSET
	match randi() % 3:
		0:
			return Vector2(size.x + SPAWN_MARGIN, randf_range(top, size.y))
		1:
			return Vector2(randf_range(0.0, size.x), size.y + SPAWN_MARGIN)
		_:
			return Vector2(-SPAWN_MARGIN, randf_range(top, size.y))

func _screen_center() -> Vector2:
	return get_viewport_rect().size / 2.0

func _end_level() -> void:
	level_ended = true
	Engine.time_scale = 1.0
	spawn_timer.stop()

	for insect in insect_container.get_children():
		insect.queue_free()

	AudioManager.play_sfx("level_complete")
	# El nivel que se acaba de terminar, ANTES de que on_level_complete
	# avance el contador.
	var terminado: int = GameManager.current_level
	var reward := GameManager.on_level_complete()
	# Los fallos van aparte del combo: el combo es la racha más larga y no
	# dice nada de cuántas veces se tapeó al aire.
	var fallos: int = player.total_misses if player else -1

	# Si era el último nivel del capítulo, primero el cierre con el
	# "CONTINUARÁ" y recién después el resumen. En ese orden y no al
	# revés: el gancho tiene que ser lo último que pasa antes de que el
	# jugador decida si sigue, no algo que se lee y después se tapa con
	# una pantalla de números.
	var cierre: Array = _cierre_de_capitulo(terminado)
	if not cierre.is_empty():
		var siguiente: int = GameManager.level_manager.get_chapter_for_level(terminado) + 1
		_show_dialogue(cierre, func():
			level_complete_ui.show_results(GameManager.player_score,
				GameManager.combo_max, reward, is_boss_level, fallos),
			siguiente)
		return

	level_complete_ui.show_results(GameManager.player_score, GameManager.combo_max,
		reward, is_boss_level, fallos)

## Las líneas de cierre si `nivel` era el último de su capítulo, o vacío.
##
## Se pide sólo cuando el nivel es múltiplo exacto de los que tiene un
## capítulo: al rejugar un nivel viejo no se repite el cierre, porque el
## jugador ya lo vio y ya sabe qué viene.
func _cierre_de_capitulo(nivel: int) -> Array:
	if nivel <= 0 or nivel % LevelManager.LEVELS_PER_CHAPTER != 0:
		return []
	if nivel < GameManager.max_level_unlocked - 1:
		return []
	return StoryData.get_chapter_outro(GameManager.level_manager.get_chapter_for_level(nivel))

func _on_next_level_pressed() -> void:
	if GameManager.current_chapter != _entry_chapter:
		# Cruzó a un capítulo nuevo: mostrar el mapa de mundos en vez de
		# saltar directo al siguiente nivel, para que se vea el avance.
		get_tree().change_scene_to_file("res://scenes/menu/world_map.tscn")
	else:
		get_tree().reload_current_scene()

func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()

## Abre la tienda dejando marcado que se vuelve al juego, no al menú.
func _on_shop_pressed() -> void:
	GameManager.return_to_game_after_shop = true
	get_tree().change_scene_to_file("res://scenes/menu/shop.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
