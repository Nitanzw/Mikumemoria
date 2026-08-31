class_name Boss
extends CharacterBody2D

## Jefe de nivel. A diferencia de un insecto común no muere de un golpe:
## tiene barra de vida y un ciclo de habilidades que lo hacen distinto de
## "un bicho con mucha vida".
##
## Cómo hace daño a Sofía: con `dash` (se tira encima) y con `spit`
## (proyectiles). Los minions invocados también pegan si llegan abajo,
## pero eso lo maneja la escena de pelea, no el jefe.

signal health_changed(current: int, maximum: int)
signal shield_changed(active: bool)
signal died
signal wants_summon(count: int)
signal wants_projectile(from: Vector2)
signal hit_player(damage: int)
signal stole_coins(amount: int)
signal ability_announced(text: String)

const EDGE_MARGIN := 90.0
const TOP_MARGIN := 220.0     # no baja de acá salvo cuando carga
## Hasta dónde puede bajar un jefe. Sofía está más abajo todavía: la
## franja de abajo queda libre para que siempre se la pueda ver.
const ARENA_BOTTOM_MARGIN := 300.0
## Medio alto aproximado del jefe ya escalado (1.7x sobre 128px).
const BOSS_HALF_HEIGHT := 55.0
const SWOOP_PERIOD := 3.4

const BOB_SPEED := 1.8
const BOB_PIXELS := 12.0

const SHIELD_HITS := 4        # golpes para romper el escudo de `shield`
const SHIELD_RECOVER_TIME := 2.5
const BURROW_TIME := 2.2
const DASH_WINDUP := 0.7
const SUMMON_WINDUP := 0.6
const SPIT_WINDUP := 0.5
## Cuánto queda frenado el jefe después de que le cortás un ataque.
const STUN_SECONDS := 1.4
## Factor entre los números de BossData y los que se muestran. El daño
## que entra se multiplica por lo mismo, así los golpes-para-matar quedan
## exactamente igual que antes del cambio de escala.
const HP_SCALE := 100

## Escala del sprite del jefe. Las hojas de caminata pasaron de 128 a
## 256px por cuadro (mismo dibujo, más resolución: se re-partió la hoja
## cruda de 1024 que quedó cacheada), así que la escala baja a la mitad
## para que el jefe se vea del mismo tamaño que antes. Las demás escalas
## se expresan como múltiplos de ésta y no como números sueltos, que es
## lo que hizo falta tocar en seis lugares esta vez.
const BASE_SCALE := Vector2(0.85, 0.85)
const BURROW_SCALE := BASE_SCALE * 0.18
const DASH_SCALE := BASE_SCALE * 1.18
const ENRAGE_SCALE := BASE_SCALE * 1.41
const DASH_SPEED := 900.0
const HEAL_IDLE_TIME := 5.0   # sin recibir golpes durante esto -> se cura
const HEAL_AMOUNT := 2
const ENRAGE_THRESHOLD := 0.3
## Cuánto se acelera el jefe al entrar en cada fase nueva.
const PHASE_SPEED_STEP := 1.18
const PHASE_ANNOUNCE := [
	"",
	"¡Se puso serio!",
	"¡Última fase! Está desesperado",
]
const STEAL_AMOUNT := 25

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var config: Dictionary = {}
var max_health: int = 20
var current_health: int = 20
var base_speed: float = 120.0
var speed: float = 120.0

var is_dead: bool = false
var is_decoy: bool = false        # las copias de `split` mueren de un golpe

# Estados que bloquean el daño
var shield_active: bool = false
var shield_hits_left: int = 0
var is_burrowed: bool = false
var minions_alive: int = 0        # mientras haya, el jefe está escudado

var is_enraged: bool = false
## Daño que este jefe le hace a Sofía. Sale de la config, que lo escala
## con el escalón de dificultad y la vuelta al roster.
var player_damage: int = BossData.BASE_DAMAGE
var _direction := Vector2.RIGHT
var _bob_phase: float = 0.0
var _ability_timer: float = 0.0

## Movimiento y patrón: el jefe recorre su lista de ataques EN ORDEN y en
## bucle, en vez de sortear uno al azar. Así se puede aprender la pelea,
## que es lo que la hace divertida en vez de ruidosa.
var _movement: String = "patrol"
var _pattern: Array = []
var _pattern_index: int = 0
var _phase: int = 0
var _move_phase: float = 0.0      # reloj propio del movimiento
var _move_timer: float = 0.0      # para los movimientos por ráfagas
var _time_since_hit: float = 0.0
var _dashing: bool = false
## Mientras prepara un ataque, un golpe se lo anula (ver _telegraph).
var _charging: bool = false
var _charge_cancelled: bool = false
var _dash_target := Vector2.ZERO
var _player_position := Vector2.ZERO

func setup(boss_config: Dictionary) -> void:
	config = boss_config
	# La vida se guarda en escala GRANDE (2000 en vez de 20) para que el
	# número que se muestra abajo se lea como el de un juego de peleas.
	# BossData sigue teniendo números chicos y legibles para tunear.
	max_health = int(config.get("health", 20)) * HP_SCALE
	current_health = max_health
	player_damage = int(config.get("damage", BossData.BASE_DAMAGE))
	base_speed = float(config.get("speed", 120.0))
	speed = base_speed

	var path: String = config.get("sprite", "")
	if sprite and path != "":
		_apply_boss_frames(path)

	# El jefe se ve claramente más grande que un insecto normal.
	if sprite:
		sprite.scale = BASE_SCALE

	_movement = str(config.get("movement", "patrol"))
	_pattern = config.get("pattern", []).duplicate()
	_pattern_index = 0
	_phase = 0

	# El primer ataque sale rápido: si el jefe tarda en hacer algo, los
	# primeros segundos se sienten vacíos.
	_ability_timer = randf_range(1.0, 1.8)
	health_changed.emit(current_health, max_health)

func set_player_position(pos: Vector2) -> void:
	_player_position = pos

func _ready() -> void:
	add_to_group("bosses")
	_direction = Vector2(randf_range(-1.0, 1.0), 0.0).normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT

func _process(delta: float) -> void:
	if is_dead or not sprite:
		return
	_bob_phase += delta * BOB_SPEED
	sprite.position.y = sin(_bob_phase) * BOB_PIXELS
	# Mientras no puede recibir daño se muestra semitransparente y
	# parpadeando, para que se entienda que pegarle ahí no sirve.
	var invulnerable := _is_invulnerable()
	var target_alpha: float = 0.45 if invulnerable else 1.0
	sprite.modulate.a = lerpf(sprite.modulate.a, target_alpha, delta * 6.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_time_since_hit += delta

	if is_burrowed:
		return

	if _dashing:
		_process_dash(delta)
	else:
		_process_patrol(delta)

	_process_abilities(delta)

## Despacha al movimiento del jefe. Cada uno mueve el jefe de forma
## distinta; todos respetan los márgenes de pantalla y ninguno baja más
## allá de la zona de Sofía (eso lo hace solo el dash).
func _process_patrol(delta: float) -> void:
	_move_phase += delta
	var view := get_viewport_rect().size

	match _movement:
		"zigzag": _move_zigzag(delta, view)
		"swoop": _move_swoop(delta, view)
		"strafe": _move_strafe(delta, view)
		"blink": _move_blink(delta, view)
		"orbit": _move_orbit(delta, view)
		"pendulum": _move_pendulum(delta, view)
		"erratic": _move_erratic(delta, view)
		"advance": _move_advance(delta, view)
		_: _move_side_to_side(delta, view)

	_clamp_to_arena(view)

## Los límites se aplican una vez, al final, para no repetirlos en cada
## movimiento (y para que ninguno se pueda escapar de la pantalla).
func _clamp_to_arena(view: Vector2) -> void:
	global_position.x = clampf(global_position.x, EDGE_MARGIN, view.x - EDGE_MARGIN)
	# El techo es la barra del HUD, no una fracción de TOP_MARGIN: con
	# TOP_MARGIN * 0.45 daba 99px, o sea ARRIBA de la barra, y los jefes
	# que suben (swoop, zigzag, blink) quedaban atrapados abajo del marco
	# donde no se los ve ni se les puede pegar.
	global_position.y = clampf(global_position.y, _ceiling(), view.y - ARENA_BOTTOM_MARGIN)

## Altura mínima a la que puede llegar el jefe: justo debajo de la barra
## del HUD, más su medio alto para que no se le corte la cabeza.

## Los jefes reusan el dibujo de un insecto. Antes cargaban su PNG fijo de
## 128px y a escala grande se veía pixelado; ahora usan el ciclo de
## caminata de ese mismo bicho, que existe en 256px. De paso el jefe deja
## de ser una imagen quieta deslizándose por la pantalla.
func _apply_boss_frames(sprite_path: String) -> void:
	var type_name := sprite_path.get_file().get_basename()
	var textures: Array[Texture2D] = []
	for i in range(Insect.WALK_FRAME_COUNT):
		var frame_path := "res://assets/sprites/insects/%s_walk_%d.png" % [type_name, i]
		if ResourceLoader.exists(frame_path):
			textures.append(load(frame_path))

	# Sin ciclo, se cae al PNG fijo metido en un SpriteFrames de un cuadro,
	# para que el nodo siga siendo el mismo tipo pase lo que pase.
	if textures.is_empty() and ResourceLoader.exists(sprite_path):
		textures.append(load(sprite_path))
	if textures.is_empty():
		return

	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	# Más lento que un insecto común: un jefe grande moviéndose rápido se
	# lee como nervioso, no como pesado.
	frames.set_animation_speed("walk", 6.0)
	for texture in textures:
		frames.add_frame("walk", texture)
	sprite.sprite_frames = frames
	sprite.play("walk")

func _ceiling() -> float:
	return Insect.PLAY_TOP_INSET + BOSS_HALF_HEIGHT

func _move_side_to_side(delta: float, view: Vector2) -> void:
	global_position.x += _direction.x * speed * delta
	if global_position.x <= EDGE_MARGIN:
		_direction.x = 1.0
	elif global_position.x >= view.x - EDGE_MARGIN:
		_direction.x = -1.0
	global_position.y = lerpf(global_position.y, TOP_MARGIN, delta * 2.0)

## Cruza en diagonal y rebota contra los cuatro bordes de su franja.
func _move_zigzag(delta: float, view: Vector2) -> void:
	if _direction.y == 0.0:
		_direction.y = 1.0
	global_position += Vector2(_direction.x, _direction.y * 0.55) * speed * delta
	if global_position.x <= EDGE_MARGIN or global_position.x >= view.x - EDGE_MARGIN:
		_direction.x = -_direction.x
	if global_position.y <= _ceiling() or global_position.y >= TOP_MARGIN * 1.9:
		_direction.y = -_direction.y

## Baja en picada hacia Sofía y vuelve arriba. No la toca: el daño por
## contacto es del dash, esto es presión y esquive.
func _move_swoop(delta: float, view: Vector2) -> void:
	var t := fmod(_move_phase, SWOOP_PERIOD) / SWOOP_PERIOD
	var depth: float = sin(t * TAU) # baja y sube
	global_position.x += _direction.x * speed * 0.7 * delta
	if global_position.x <= EDGE_MARGIN or global_position.x >= view.x - EDGE_MARGIN:
		_direction.x = -_direction.x
	var low := view.y - ARENA_BOTTOM_MARGIN - 60.0
	global_position.y = lerpf(TOP_MARGIN, low, maxf(depth, 0.0))

## Ráfagas laterales rápidas con pausas: se queda quieto, apunta, y
## cruza medio ancho de pantalla de golpe.
func _move_strafe(delta: float, view: Vector2) -> void:
	_move_timer -= delta
	if _move_timer <= 0.0:
		_move_timer = randf_range(0.7, 1.2)
		_direction.x = -_direction.x if randf() < 0.7 else _direction.x
	var burst: float = 2.4 if _move_timer > 0.45 else 0.15
	global_position.x += _direction.x * speed * burst * delta
	if global_position.x <= EDGE_MARGIN or global_position.x >= view.x - EDGE_MARGIN:
		_direction.x = -_direction.x
	global_position.y = lerpf(global_position.y, TOP_MARGIN, delta * 2.0)

## Se desvanece y reaparece en otro lado. Distinto de `burrow`: acá no
## queda invulnerable, solo cuesta seguirlo.
func _move_blink(delta: float, view: Vector2) -> void:
	_move_timer -= delta
	if _move_timer <= 0.0:
		_move_timer = randf_range(1.4, 2.3)
		var destination := randf_range(EDGE_MARGIN, view.x - EDGE_MARGIN)
		# Salta lejos, no dos pasos al costado.
		if absf(destination - global_position.x) < view.x * 0.3:
			destination = view.x - destination
		global_position.x = destination
		global_position.y = randf_range(TOP_MARGIN * 0.7, TOP_MARGIN * 1.6)
		if sprite:
			sprite.modulate.a = 0.15
	global_position.y = lerpf(global_position.y, TOP_MARGIN, delta * 1.2)

## Gira en círculo alrededor del centro de la arena.
func _move_orbit(delta: float, view: Vector2) -> void:
	var radius: float = minf(view.x * 0.33, 190.0)
	var angular := speed / maxf(radius, 1.0)
	var angle := _move_phase * angular
	global_position.x = view.x / 2.0 + cos(angle) * radius
	global_position.y = TOP_MARGIN + sin(angle) * radius * 0.5

## Péndulo: rápido en el medio, frena en las puntas. Se lee como que
## "toma impulso", y da una ventana para pegarle en los extremos.
func _move_pendulum(delta: float, view: Vector2) -> void:
	var span := (view.x - EDGE_MARGIN * 2.0) / 2.0
	var angular := speed / maxf(span, 1.0)
	global_position.x = view.x / 2.0 + sin(_move_phase * angular) * span
	global_position.y = lerpf(global_position.y, TOP_MARGIN, delta * 2.0)

## Cambia de rumbo de golpe. Impredecible a propósito: al Rayo Insecto y
## a la Mutagénesis les toca ser difíciles de seguir.
func _move_erratic(delta: float, view: Vector2) -> void:
	_move_timer -= delta
	if _move_timer <= 0.0:
		_move_timer = randf_range(0.35, 0.8)
		_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)).normalized()
		if _direction == Vector2.ZERO:
			_direction = Vector2.RIGHT
	global_position += _direction * speed * delta
	if global_position.x <= EDGE_MARGIN or global_position.x >= view.x - EDGE_MARGIN:
		_direction.x = -_direction.x
	if global_position.y <= _ceiling() or global_position.y >= TOP_MARGIN * 2.0:
		_direction.y = -_direction.y

## Baja de a poco hacia Sofía mientras patrulla. Mete presión de tiempo:
## cuanto más tardás en bajarle la vida, más cerca lo tenés.
func _move_advance(delta: float, view: Vector2) -> void:
	global_position.x += _direction.x * speed * delta
	if global_position.x <= EDGE_MARGIN or global_position.x >= view.x - EDGE_MARGIN:
		_direction.x = -_direction.x
	var floor_y := view.y - ARENA_BOTTOM_MARGIN
	var progress := 1.0 - float(current_health) / float(maxi(max_health, 1))
	global_position.y = lerpf(global_position.y, lerpf(TOP_MARGIN, floor_y, progress), delta * 0.6)

func _process_dash(delta: float) -> void:
	var to_target := _dash_target - global_position
	if to_target.length() < 30.0:
		_end_dash()
		return
	global_position += to_target.normalized() * DASH_SPEED * delta
	# Si alcanza a Sofía, le saca una vida.
	if global_position.distance_to(_player_position) < 90.0:
		hit_player.emit(player_damage)
		if BossData.has_ability(config, "steal"):
			stole_coins.emit(STEAL_AMOUNT)
		_end_dash()

func _end_dash() -> void:
	_dashing = false
	speed = base_speed * (1.5 if is_enraged else 1.0)

# --- Habilidades ---

func _process_abilities(delta: float) -> void:
	_update_phase()

	_ability_timer -= delta
	if _ability_timer > 0.0:
		return

	var cooldown: Vector2 = BossData.PHASE_COOLDOWNS[mini(_phase, BossData.PHASE_COOLDOWNS.size() - 1)]
	_ability_timer = randf_range(cooldown.x, cooldown.y)
	_use_next_ability()

	# `heal` no entra en el patrón: se dispara sola si lo dejás tranquilo.
	if BossData.has_ability(config, "heal") and _time_since_hit > HEAL_IDLE_TIME:
		_heal()

## Fases por vida. Al entrar en una nueva, el jefe lo anuncia y desde ahí
## ataca más seguido (PHASE_COOLDOWNS) y suma la habilidad que le toque.
func _update_phase() -> void:
	var ratio := float(current_health) / float(maxi(max_health, 1))
	var new_phase := 0
	if ratio <= BossData.PHASE_3_HP:
		new_phase = 2
	elif ratio <= BossData.PHASE_2_HP:
		new_phase = 1
	if new_phase <= _phase:
		return

	_phase = new_phase
	var unlocks: Array = config.get("phase_unlocks", [])
	var unlocked: String = str(unlocks[_phase]) if _phase < unlocks.size() else ""
	if unlocked != "" and not (unlocked in _pattern):
		_pattern.append(unlocked)

	# Entrar en fase acelera un poco al jefe: se nota que se puso serio.
	base_speed *= PHASE_SPEED_STEP
	if not _dashing:
		speed = base_speed * (1.5 if is_enraged else 1.0)

	# El ataque siguiente sale casi enseguida, para que el cambio se sienta.
	_ability_timer = minf(_ability_timer, 0.6)
	ability_announced.emit(PHASE_ANNOUNCE[mini(_phase, PHASE_ANNOUNCE.size() - 1)])

## Ejecuta el siguiente ataque del patrón, en orden y en bucle. Si el que
## toca no se puede usar ahora (ya hay minions, ya hay escudo), avanza al
## siguiente en vez de perder el turno.
func _use_next_ability() -> void:
	if _pattern.is_empty():
		return
	for _i in range(_pattern.size()):
		var ability: String = str(_pattern[_pattern_index])
		_pattern_index = (_pattern_index + 1) % _pattern.size()
		if _can_use(ability):
			_perform(ability)
			return

func _can_use(ability: String) -> bool:
	match ability:
		"summon":
			return minions_alive == 0
		"shield":
			return not shield_active
		"enrage":
			return not is_enraged
		"burrow":
			return not is_burrowed
		"dash":
			return not _dashing
		_:
			return true

func _perform(ability: String) -> void:
	match ability:
		"summon": _summon()
		"shield": _raise_shield()
		"burrow": _burrow()
		"dash": _start_dash()
		"spit": _spit()
		"haste": _haste()
		"split": _split()
		"heal": _heal()
		"enrage": _enrage()

func _summon() -> void:
	ability_announced.emit("¡Está llamando refuerzos! Pegale para cortarlo")
	if not await _telegraph(SUMMON_WINDUP):
		return

	# Más refuerzos a medida que avanza la pelea: en la última fase la
	# pantalla se llena y hay que limpiar rápido.
	var count: int = 3 + _phase
	if is_enraged:
		count += 1
	minions_alive = count
	shield_changed.emit(true)
	ability_announced.emit("¡Invoca refuerzos! No podés tocarlo hasta limpiarlos")
	wants_summon.emit(count)

## La escena de pelea avisa cuando muere un minion.
func on_minion_died() -> void:
	minions_alive = maxi(minions_alive - 1, 0)
	if minions_alive == 0:
		shield_changed.emit(false)
		ability_announced.emit("¡Quedó sin guardia! Pegale ahora")

func _raise_shield() -> void:
	shield_active = true
	shield_hits_left = SHIELD_HITS
	shield_changed.emit(true)
	ability_announced.emit("¡Escudo! Golpes seguidos para romperlo")

func _burrow() -> void:
	is_burrowed = true
	ability_announced.emit("¡Se enterró!")
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.3)
	await get_tree().create_timer(BURROW_TIME).timeout
	if is_dead:
		return
	# Reaparece en otro lado
	var view := get_viewport_rect().size
	global_position.x = randf_range(EDGE_MARGIN, view.x - EDGE_MARGIN)
	is_burrowed = false
	var out := create_tween()
	out.tween_property(sprite, "scale", Vector2(1.7, 1.7), 0.3)

func _start_dash() -> void:
	ability_announced.emit("¡Se prepara para embestir! Pegale para frenarlo")
	# Aviso previo: se agranda un toque antes de salir disparado, para que
	# el golpe sea esquivable y no se sienta injusto.
	var tween := create_tween()
	tween.tween_property(sprite, "scale", DASH_SCALE, DASH_WINDUP * 0.5)
	tween.tween_property(sprite, "scale", BASE_SCALE, DASH_WINDUP * 0.5)

	if not await _telegraph(DASH_WINDUP):
		return
	_dash_target = _player_position
	_dashing = true

## Ventana en la que el ataque se puede ANULAR pegándole al jefe.
##
## Antes los ataques salían sí o sí una vez empezados: solo quedaba
## esquivar. Ahora se puede interrumpir, que es lo que hace que valga la
## pena mirar lo que hace el jefe en vez de tapear al vacío.
##
## Devuelve false si el ataque quedó anulado (o el jefe murió / se
## enterró), y el llamador tiene que abandonar.
func _telegraph(seconds: float) -> bool:
	_charging = true
	_charge_cancelled = false
	await get_tree().create_timer(seconds).timeout
	_charging = false

	if _charge_cancelled:
		_charge_cancelled = false
		# Queda aturdido un momento: es la recompensa por anticiparlo.
		ability_announced.emit("¡Le cortaste el ataque!")
		_ability_timer = maxf(_ability_timer, STUN_SECONDS)
		_flash(Color(1.6, 1.6, 0.6))
		if sprite:
			sprite.scale = BASE_SCALE
		return false

	return not (is_dead or is_burrowed)

func _spit() -> void:
	ability_announced.emit("¡Va a escupir!")
	if not await _telegraph(SPIT_WINDUP):
		return

	ability_announced.emit("¡Escupe!")
	wants_projectile.emit(global_position)

func _haste() -> void:
	ability_announced.emit("¡Se acelera!")
	speed = base_speed * 2.0
	await get_tree().create_timer(3.0).timeout
	if not is_dead and not _dashing:
		speed = base_speed * (1.5 if is_enraged else 1.0)

func _split() -> void:
	ability_announced.emit("¡Se dividió! Solo una es la real")
	wants_summon.emit(0)  # 0 = la escena entiende que son copias, no minions

func _heal() -> void:
	if current_health >= max_health:
		return
	current_health = mini(current_health + HEAL_AMOUNT, max_health)
	health_changed.emit(current_health, max_health)
	ability_announced.emit("¡Se está curando! No le des respiro")
	_time_since_hit = 0.0

# --- Daño ---

## No recibe daño mientras esté enterrado o protegido (por minions o por
## escudo). Es lo que hace que las habilidades importen.
func _is_invulnerable() -> bool:
	return is_burrowed or minions_alive > 0 or shield_active

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	if is_decoy:
		# Las copias de `split` se disipan de un solo golpe.
		queue_free()
		return

	_time_since_hit = 0.0

	# Un golpe mientras prepara un ataque lo anula. Se chequea ANTES que
	# el escudo y los minions a propósito: si no, un jefe escudado nunca
	# podría ser interrumpido y la mecánica no existiría justo cuando más
	# se necesita.
	if _charging:
		_charge_cancelled = true

	if is_burrowed:
		return

	if minions_alive > 0:
		_flash(Color(0.6, 0.6, 1.0))
		ability_announced.emit("¡Limpiá los refuerzos primero!")
		return

	if shield_active:
		shield_hits_left -= 1
		_flash(Color(0.5, 0.8, 1.0))
		if shield_hits_left <= 0:
			shield_active = false
			shield_changed.emit(false)
			ability_announced.emit("¡Escudo roto!")
		return

	# El llamador (Player, la tormenta, el lanzallamas) trabaja en la
	# escala chica de los insectos comunes; acá se convierte una sola vez.
	current_health = maxi(current_health - amount * HP_SCALE, 0)
	health_changed.emit(current_health, max_health)
	_flash(Color(2.0, 1.4, 1.4))

	if not is_enraged and BossData.has_ability(config, "enrage") \
			and float(current_health) / float(max_health) <= ENRAGE_THRESHOLD:
		_enrage()

	if current_health <= 0:
		die()

func _enrage() -> void:
	# Ahora el enrage puede venir del patrón además de por vida baja, así
	# que se protege de entrar dos veces (duplicaría la velocidad).
	if is_enraged:
		return
	is_enraged = true
	speed = base_speed * 1.5
	ability_announced.emit("¡Se enfureció!")
	if sprite:
		sprite.modulate = Color(1.4, 0.8, 0.8)

func _flash(color: Color) -> void:
	if not sprite:
		return
	var original := sprite.modulate
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", color, 0.05)
	tween.tween_property(sprite, "modulate", original, 0.12)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	died.emit()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", ENRAGE_SCALE, 0.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "rotation", 1.2, 0.5)
	await get_tree().create_timer(0.6).timeout
	queue_free()

## Recuadro donde se puede tocar al jefe (lo usa la escena para saber si
## un tap le pegó, sin depender de física).
func get_hit_radius() -> float:
	return 95.0
