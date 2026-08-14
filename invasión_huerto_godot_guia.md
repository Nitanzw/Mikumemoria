# 🎮 ¡Invasión en el Huerto! - Guía Completa Godot

**Documento de referencia para desarrollar el juego en Godot 4.x**

---

## 📑 Tabla de Contenidos

1. [Estructura del Proyecto](#estructura-del-proyecto)
2. [Scripts Base](#scripts-base)
3. [Sistemas Clave](#sistemas-clave)
4. [Configuración Recomendada](#configuración-recomendada)
5. [Checklist de Implementación](#checklist-de-implementación)
6. [Notas y Consideraciones](#notas-y-consideraciones)

---

## 📁 Estructura del Proyecto

```
invasión_huerto/
│
├── scenes/
│   ├── main_game.tscn              ← Escena principal del nivel
│   ├── insect.tscn                 ← Prefab de insecto común
│   ├── mystery_bug.tscn            ← Prefab de insecto incógnito
│   │
│   ├── ui/
│   │   ├── hud.tscn                ← Puntuación, nivel, combo, tiempo
│   │   ├── mystery_reveal.tscn     ← Animación de revelación
│   │   ├── level_complete.tscn     ← Pantalla de fin de nivel
│   │   ├── unlock_notification.tscn ← Notificación de desbloqueo
│   │   └── game_over.tscn          ← Pantalla de game over
│   │
│   ├── menu/
│   │   ├── main_menu.tscn          ← Menú principal
│   │   ├── shop.tscn               ← Tienda de armas
│   │   ├── skill_tree.tscn         ← Árbol de habilidades
│   │   └── settings.tscn           ← Configuración
│   │
│   ├── effects/
│   │   ├── hit_effect.tscn         ← Efecto visual de golpe
│   │   ├── reveal_spark.tscn       ← Partículas de revelación
│   │   └── explosion.tscn          ← Explosión de insecto
│   │
│   └── chapters/
│       ├── chapter_1_huerto.tscn   ← Fondo capítulo 1
│       ├── chapter_2_invernadero.tscn
│       └── ... (más capítulos)
│
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd         ← SINGLETON: Control central
│   │   ├── audio_manager.gd        ← SINGLETON: Sonidos
│   │   ├── save_manager.gd         ← SINGLETON: Guardado
│   │   └── event_manager.gd        ← SINGLETON: Sistema de eventos
│   │
│   ├── core/
│   │   ├── level_manager.gd        ← Configuración de niveles
│   │   ├── player.gd               ← Control de Don Beto
│   │   ├── insect.gd               ← Lógica de insectos
│   │   ├── mystery_bug.gd          ← Lógica de incógnito
│   │   └── weapon.gd               ← Sistema de armas
│   │
│   ├── ui/
│   │   ├── hud.gd                  ← Interfaz de juego
│   │   ├── shop_ui.gd              ← UI de tienda
│   │   ├── skill_tree_ui.gd        ← UI de árbol
│   │   └── level_complete_ui.gd    ← UI de fin de nivel
│   │
│   └── systems/
│       ├── skill_system.gd         ← Sistema de habilidades
│       ├── weapon_system.gd        ← Sistema de armas
│       └── combo_system.gd         ← Sistema de combos
│
├── assets/
│   ├── sprites/
│   │   ├── insects/
│   │   │   ├── hormiga_obrera.png
│   │   │   ├── cucaracha_electrica.png
│   │   │   ├── escarabajo_blindado.png
│   │   │   ├── mosca_pesada.png
│   │   │   ├── grillo_saltarin.png
│   │   │   ├── cucaracha_dorada.png
│   │   │   ├── abejorro_pinata.png
│   │   │   ├── hormiga_ladrona.png
│   │   │   ├── mantis_cronometro.png
│   │   │   └── mystery_bug_silueta.png
│   │   │
│   │   ├── weapons/
│   │   │   ├── zapato_viejo.png
│   │   │   ├── chancla_goma.png
│   │   │   ├── matamoscas.png
│   │   │   ├── sarten.png
│   │   │   └── pala_electrificada.png
│   │   │
│   │   ├── character/
│   │   │   └── don_beto.png
│   │   │
│   │   └── backgrounds/
│   │       ├── chapter_1_huerto.png
│   │       ├── chapter_2_invernadero.png
│   │       ├── chapter_3_cueva.png
│   │       └── ... (más fondos)
│   │
│   ├── sounds/
│   │   ├── sfx/
│   │   │   ├── hit_hormiga.ogg
│   │   │   ├── hit_cucaracha.ogg
│   │   │   ├── taunt.ogg
│   │   │   ├── mystery_revealed.ogg
│   │   │   ├── level_complete.ogg
│   │   │   └── unlock.ogg
│   │   │
│   │   └── music/
│   │       ├── menu_theme.ogg
│   │       ├── level_theme_1.ogg
│   │       └── boss_theme.ogg
│   │
│   └── fonts/
│       ├── titulo.ttf
│       └── interfaz.ttf
│
└── project.godot                   ← Configuración del proyecto

```

---

## 🔧 Scripts Base

### 1. **GameManager.gd** (AUTOLOAD/SINGLETON)

```gdscript
extends Node

# ================================================================
# GAME MANAGER - Control Central del Juego
# ================================================================
# Debe agregarse como Autoload en Proyecto → Configuración de Proyecto
# → Autoload (nombre: GameManager)

class_name GameManager

# Progreso del jugador
var current_level: int = 1
var current_chapter: int = 1
var player_coins: int = 0
var player_score: int = 0
var combo_hits: int = 0
var combo_max: int = 0

# Estado de desbloqueos
var unlocked_insects: Array = []  # Índices 1-100 de insectos desbloqueados
var unlocked_weapons: Array = ["zapato_viejo"]
var skill_tree: Dictionary = {}

# Referencias
@onready var level_manager = LevelManager.new()
@onready var save_manager = SaveManager.new()
@onready var skill_system = SkillSystem.new()

# Señales
signal level_started(level: int)
signal level_completed(level: int)
signal insect_unlocked(index: int, name: String)
signal score_changed(new_score: int)
signal coins_changed(new_coins: int)

func _ready():
	print("[GameManager] Inicializando...")
	load_game_data()

func load_game_data():
	"""Carga progreso guardado o crea nuevo juego"""
	var data = save_manager.load_save()
	if data:
		print("[GameManager] Progreso cargado: Nivel %d" % data.current_level)
		current_level = data.get("current_level", 1)
		player_coins = data.get("coins", 0)
		unlocked_insects = data.get("unlocked_insects", [])
		unlocked_weapons = data.get("unlocked_weapons", ["zapato_viejo"])
		skill_tree = data.get("skill_tree", {})
	else:
		print("[GameManager] Nuevo juego")
		reset_game()

func reset_game():
	"""Resetea el juego al estado inicial"""
	current_level = 1
	player_coins = 0
	player_score = 0
	combo_hits = 0
	unlocked_insects = []
	unlocked_weapons = ["zapato_viejo"]

func start_level(level: int):
	"""Inicia un nivel específico"""
	current_level = level
	current_chapter = ((level - 1) / 100) + 1
	player_score = 0
	combo_hits = 0
	combo_max = 0
	
	print("[GameManager] Iniciando Nivel %d (Capítulo %d)" % [level, current_chapter])
	
	var level_config = level_manager.get_level_config(level)
	emit_signal("level_started", level)

func on_insect_hit(insect: Insect):
	"""Llamado cuando se golpea un insecto"""
	player_score += insect.points
	combo_hits += 1
	
	if combo_hits > combo_max:
		combo_max = combo_hits
	
	emit_signal("score_changed", player_score)
	AudioManager.play_sfx("hit_" + insect.insect_type)

func on_insect_missed():
	"""Llamado cuando fallas un golpe"""
	combo_hits = 0
	AudioManager.play_sfx("taunt")

func on_level_complete():
	"""Llamado al completar un nivel"""
	var reward = calculate_level_reward()
	add_coins(reward)
	
	save_manager.save_game({
		"current_level": current_level + 1,
		"coins": player_coins,
		"unlocked_insects": unlocked_insects,
		"unlocked_weapons": unlocked_weapons,
		"skill_tree": skill_tree
	})
	
	emit_signal("level_completed", current_level)

func calculate_level_reward() -> int:
	"""Calcula recompensa del nivel"""
	var base = 50
	var level_bonus = current_level * 2
	var combo_bonus = combo_max * 5
	return base + level_bonus + combo_bonus

func add_coins(amount: int):
	"""Suma monedas"""
	player_coins += amount
	emit_signal("coins_changed", player_coins)

func unlock_insect(index: int, insect_data: Dictionary):
	"""Desbloquea un nuevo insecto"""
	if index not in unlocked_insects:
		unlocked_insects.append(index)
		emit_signal("insect_unlocked", index, insect_data.name)
		print("[GameManager] Insecto desbloqueado: %s" % insect_data.name)

func has_unlocked_insect(index: int) -> bool:
	"""Verifica si un insecto está desbloqueado"""
	return index in unlocked_insects

func get_unlocked_insect_count() -> int:
	"""Retorna cantidad de insectos desbloqueados"""
	return unlocked_insects.size()

```

---

### 2. **SaveManager.gd** (AUTOLOAD)

```gdscript
extends Node

# ================================================================
# SAVE MANAGER - Persistencia de Datos
# ================================================================

class_name SaveManager

const SAVE_PATH = "user://invasión_huerto_save.json"

func save_game(data: Dictionary):
	"""Guarda el progreso del jugador"""
	var save_data = {
		"current_level": data.current_level,
		"coins": data.coins,
		"unlocked_insects": data.unlocked_insects,
		"unlocked_weapons": data.unlocked_weapons,
		"skill_tree": data.skill_tree,
		"timestamp": Time.get_ticks_msec()
	}
	
	var json_string = JSON.stringify(save_data)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		print("[SaveManager] Juego guardado en: %s" % SAVE_PATH)
	else:
		print("[SaveManager] Error al guardar: No se pudo abrir archivo")

func load_save() -> Dictionary:
	"""Carga el progreso guardado"""
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No hay archivo guardado")
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		print("[SaveManager] Error al leer archivo de guardado")
		return {}
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		print("[SaveManager] Guardado cargado exitosamente")
		return json.data
	else:
		print("[SaveManager] Error al parsear JSON")
		return {}

func clear_save():
	"""Borra el archivo de guardado (para nueva partida)"""
	if FileAccess.file_exists(SAVE_PATH):
		var error = DirAccess.remove_absolute(SAVE_PATH)
		if error == OK:
			print("[SaveManager] Archivo de guardado eliminado")

```

---

### 3. **AudioManager.gd** (AUTOLOAD)

```gdscript
extends Node

# ================================================================
# AUDIO MANAGER - Control de Sonidos
# ================================================================

class_name AudioManager

var sfx_players: Dictionary = {}
var current_music: AudioStreamPlayer

func _ready():
	print("[AudioManager] Inicializando...")
	setup_sfx_players()

func setup_sfx_players():
	"""Crea múltiples players de SFX para evitar solapamientos"""
	for i in range(5):
		var player = AudioStreamPlayer.new()
		add_child(player)
		sfx_players["player_%d" % i] = player

func play_sfx(sfx_name: String):
	"""Reproduce un efecto de sonido"""
	var path = "res://assets/sounds/sfx/%s.ogg" % sfx_name
	
	if ResourceLoader.exists(path):
		var audio = load(path)
		var available_player = get_available_sfx_player()
		
		if available_player:
			available_player.stream = audio
			available_player.play()
		else:
			print("[AudioManager] No hay players disponibles para: %s" % sfx_name)
	else:
		print("[AudioManager] Sonido no encontrado: %s" % sfx_name)

func get_available_sfx_player() -> AudioStreamPlayer:
	"""Busca un player disponible"""
	for player in sfx_players.values():
		if not player.playing:
			return player
	return null

func play_music(music_name: String, fade_in: float = 0.0):
	"""Reproduce música de fondo"""
	var path = "res://assets/sounds/music/%s.ogg" % music_name
	
	if not ResourceLoader.exists(path):
		print("[AudioManager] Música no encontrada: %s" % music_name)
		return
	
	if current_music and current_music.playing:
		if fade_in > 0:
			var tween = create_tween()
			tween.tween_property(current_music, "volume_db", -80, fade_in)
			await tween.finished
		current_music.stop()
	
	current_music = AudioStreamPlayer.new()
	current_music.bus = &"Music"
	add_child(current_music)
	
	current_music.stream = load(path)
	current_music.play()

func stop_music(fade_out: float = 0.0):
	"""Detiene la música actual"""
	if current_music and current_music.playing:
		if fade_out > 0:
			var tween = create_tween()
			tween.tween_property(current_music, "volume_db", -80, fade_out)
			await tween.finished
		current_music.stop()

```

---

### 4. **LevelManager.gd**

```gdscript
extends Node

# ================================================================
# LEVEL MANAGER - Configuración de Niveles
# ================================================================

class_name LevelManager

# Configuración por capítulo
var chapter_configs = {
	1: {
		"name": "El Huerto de Tomates",
		"enemy_speed_mult": 1.0,
		"spawn_rate": 2.0,
		"background": "res://assets/sprites/backgrounds/chapter_1_huerto.png"
	},
	2: {
		"name": "El Invernadero",
		"enemy_speed_mult": 1.2,
		"spawn_rate": 2.5,
		"background": "res://assets/sprites/backgrounds/chapter_2_invernadero.png"
	},
	3: {
		"name": "La Cueva Subterránea",
		"enemy_speed_mult": 1.4,
		"spawn_rate": 3.0,
		"background": "res://assets/sprites/backgrounds/chapter_3_cueva.png"
	},
	4: {
		"name": "El Cultivo Radiactivo",
		"enemy_speed_mult": 2.0,
		"spawn_rate": 3.5,
		"background": "res://assets/sprites/backgrounds/chapter_4_radiactivo.png"
	},
	5: {
		"name": "El Pantano",
		"enemy_speed_mult": 1.3,
		"spawn_rate": 3.0,
		"background": "res://assets/sprites/backgrounds/chapter_5_pantano.png"
	},
	6: {
		"name": "Laboratorio Mutante",
		"enemy_speed_mult": 1.5,
		"spawn_rate": 4.0,
		"background": "res://assets/sprites/backgrounds/chapter_6_lab.png"
	},
	7: {
		"name": "Fábrica de Cascos",
		"enemy_speed_mult": 1.6,
		"spawn_rate": 4.5,
		"background": "res://assets/sprites/backgrounds/chapter_7_fabrica.png"
	},
	8: {
		"name": "Red de Túneles Express",
		"enemy_speed_mult": 2.5,
		"spawn_rate": 5.0,
		"background": "res://assets/sprites/backgrounds/chapter_8_tuneles.png"
	},
	9: {
		"name": "El Búnker Enemigo",
		"enemy_speed_mult": 1.8,
		"spawn_rate": 4.0,
		"background": "res://assets/sprites/backgrounds/chapter_9_bunker.png"
	},
	10: {
		"name": "El Núcleo Reina",
		"enemy_speed_mult": 2.0,
		"spawn_rate": 5.5,
		"background": "res://assets/sprites/backgrounds/chapter_10_nucleo.png"
	}
}

# Tipos de enemigos por nivel
var enemy_unlock_tiers = {
	1: ["hormiga_obrera"],
	20: ["hormiga_obrera", "cucaracha_electrica"],
	50: ["hormiga_obrera", "cucaracha_electrica", "escarabajo_blindado"],
	100: ["hormiga_obrera", "cucaracha_electrica", "escarabajo_blindado", "mosca_pesada"],
	150: ["hormiga_obrera", "cucaracha_electrica", "escarabajo_blindado", "mosca_pesada", "grillo_saltarin"]
}

func get_level_config(level: int) -> Dictionary:
	"""Retorna configuración para un nivel específico"""
	var chapter = ((level - 1) / 100) + 1
	var chapter_config = chapter_configs.get(chapter, {})
	
	return {
		"level": level,
		"chapter": chapter,
		"chapter_name": chapter_config.get("name", "Desconocido"),
		"background": chapter_config.get("background", ""),
		"spawn_rate": chapter_config.get("spawn_rate", 2.0),
		"enemy_speed_mult": chapter_config.get("enemy_speed_mult", 1.0),
		"time_limit": 60,
		"enemy_types": get_available_enemies(level),
		"has_mystery_bug": should_have_mystery_bug(level)
	}

func should_have_mystery_bug(level: int) -> bool:
	"""Determina si este nivel tiene un insecto incógnito"""
	# Cada 10 niveles menos nivel 10, 20, 30, etc.
	return (level % 10) != 0

func get_mystery_bug_index(level: int) -> int:
	"""Retorna el índice del insecto incógnito para este nivel"""
	# Nivel 1-9: ninguno
	# Nivel 10-19: índice 1
	# Nivel 20-29: índice 2
	# etc.
	return level / 10

func get_available_enemies(level: int) -> Array:
	"""Retorna tipos de enemigos disponibles para este nivel"""
	var available = []
	
	for tier_level in enemy_unlock_tiers.keys():
		if level >= tier_level:
			available = enemy_unlock_tiers[tier_level]
	
	return available

func get_chapter_name(chapter: int) -> String:
	"""Retorna nombre del capítulo"""
	return chapter_configs.get(chapter, {}).get("name", "Desconocido")

```

---

### 5. **Insect.gd**

```gdscript
extends CharacterBody2D

# ================================================================
# INSECT - Lógica de Insectos Comunes
# ================================================================

class_name Insect

# Propiedades exportables
@export var insect_type: String = "hormiga_obrera"
@export var speed: float = 100.0
@export var health: int = 1
@export var points: int = 50
@export var coin_reward: int = 50

# Referencias
@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer
@onready var collision = $CollisionShape2D

# Estado interno
var direction: Vector2 = Vector2.RIGHT
var current_health: int
var is_dead: bool = false
var can_be_hit: bool = true
var base_speed: float

# Burla (taunt)
var is_taunting: bool = false
var taunt_timer: float = 0.0

func _ready():
	current_health = health
	base_speed = speed
	add_to_group("insects")
	initialize_by_type()

func initialize_by_type():
	"""Inicializa el insecto según su tipo"""
	match insect_type:
		"hormiga_obrera":
			speed = 100.0
			health = 1
			points = 50
			coin_reward = 50
		
		"cucaracha_electrica":
			speed = 200.0
			health = 1
			points = 75
			coin_reward = 75
		
		"escarabajo_blindado":
			speed = 50.0
			health = 3
			points = 150
			coin_reward = 150
		
		"mosca_pesada":
			speed = 150.0
			health = 1
			points = 100
			coin_reward = 100
		
		"grillo_saltarin":
			speed = 120.0
			health = 1
			points = 80
			coin_reward = 80
	
	current_health = health
	base_speed = speed

func _physics_process(delta):
	if is_dead or is_taunting:
		return
	
	velocity = direction * speed
	move_and_slide()
	
	# Si salió de pantalla, eliminar
	if global_position.x > get_viewport_rect().size.x + 100 or \
	   global_position.x < -100 or \
	   global_position.y > get_viewport_rect().size.y + 100 or \
	   global_position.y < -100:
		queue_free()

func _process(delta):
	"""Actualiza el timer de taunt"""
	if is_taunting and taunt_timer > 0:
		taunt_timer -= delta
		if taunt_timer <= 0:
			is_taunting = false
			speed = base_speed

func take_damage(damage: int = 1):
	"""Recibe daño"""
	if not can_be_hit or is_dead:
		return
	
	current_health -= damage
	
	if current_health <= 0:
		die()
	else:
		play_hit_animation()
		GameManager.on_insect_hit(self)

func die():
	"""Muere e invoca recompensa"""
	is_dead = true
	can_be_hit = false
	
	play_death_animation()
	GameManager.add_coins(coin_reward)
	GameManager.on_insect_hit(self)

func play_hit_animation():
	"""Animación de impacto"""
	if animation_player and animation_player.has_animation("hit"):
		animation_player.play("hit")
	
	# Flash visual
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)

func play_death_animation():
	"""Animación de muerte"""
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

func taunt():
	"""Se burla y corre más rápido"""
	if is_taunting or is_dead:
		return
	
	is_taunting = true
	taunt_timer = 1.0
	speed = base_speed * 2.0  # Doble velocidad
	
	if animation_player and animation_player.has_animation("taunt"):
		animation_player.play("taunt")
	
	GameManager.on_insect_missed()

func randomize_direction():
	"""Cambia dirección aleatoriamente"""
	direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

```

---

### 6. **MysteryBug.gd**

```gdscript
extends Insect

# ================================================================
# MYSTERY BUG - Insecto Incógnito
# ================================================================

class_name MysteryBug

# Sistema de revelación
var reveal_progress: float = 0.0
var reveal_max: float = 100.0  # Golpes necesarios
var is_revealed: bool = false
var mystery_index: int = 0

# Referencias UI
@onready var reveal_bar = $RevealBar
@onready var mystery_sprite = $MysterySprite
@onready var progress_label = $ProgressLabel

# Datos del insecto a revelar
var insect_data: Dictionary = {}
var insect_prefab_path: String = ""

func _ready():
	# No llamar a super()._ready(), hacer setup manual
	current_health = 1
	health = 1
	is_dead = false
	base_speed = 80.0
	speed = 80.0
	add_to_group("insects")
	
	setup_mystery_bug()
	show_mystery_sprite()

func setup_mystery_bug():
	"""Configura el insecto incógnito"""
	var current_level = GameManager.current_level
	mystery_index = current_level / 10
	
	print("[MysteryBug] Configurando incógnito #%d para nivel %d" % [mystery_index, current_level])
	
	insect_data = load_insect_data(mystery_index)
	
	if insect_data.is_empty():
		print("[MysteryBug] Error: No hay datos para índice %d" % mystery_index)
		queue_free()
		return

func load_insect_data(index: int) -> Dictionary:
	"""Carga datos del insecto que se revelará"""
	# Base de datos de insectos incógnito
	var insects_database = {
		1: {"name": "Hormiga Ladrona de Diamantes", "type": "hormiga_ladrona", "speed": 100, "points": 100},
		2: {"name": "Abejorro Piñata", "type": "abejorro_pinata", "speed": 150, "points": 150},
		3: {"name": "Mantis Cronómetro", "type": "mantis_cronometro", "speed": 120, "points": 120},
		4: {"name": "Escarabajo Radiactivo", "type": "escarabajo_radiactivo", "speed": 140, "points": 140},
		5: {"name": "Lombriz Gigante", "type": "lombriz_gigante", "speed": 60, "points": 130},
		6: {"name": "Mutagénesis Voladora", "type": "mutante_volador", "speed": 180, "points": 160},
		7: {"name": "Centella Blindada", "type": "centella_blindada", "speed": 110, "points": 170},
		8: {"name": "Rayo Insecto", "type": "rayo_insecto", "speed": 250, "points": 200},
		9: {"name": "Coraza Antigua", "type": "coraza_antigua", "speed": 90, "points": 180},
		10: {"name": "Reina Primordial", "type": "reina_primordial", "speed": 130, "points": 300}
	}
	
	return insects_database.get(index, {})

func show_mystery_sprite():
	"""Muestra silueta borrosa"""
	if mystery_sprite:
		mystery_sprite.modulate.a = 1.0
	if sprite:
		sprite.modulate.a = 0.0
	if progress_label:
		progress_label.text = "???"

func take_damage(damage: int = 1):
	"""Recibe golpe y avanza revelación"""
	if is_dead:
		return
	
	reveal_progress += damage
	update_reveal_bar()
	play_reveal_effect()
	
	GameManager.on_insect_hit(self)
	
	if reveal_progress >= reveal_max:
		reveal_insect()
	else:
		play_hit_animation()

func update_reveal_bar():
	"""Actualiza barra de revelación"""
	var percentage = (reveal_progress / reveal_max) * 100
	
	if reveal_bar:
		reveal_bar.value = percentage
	
	if progress_label:
		progress_label.text = "%d%%" % int(percentage)
	
	# Fade gradual de silueta a sprite real
	var fade = clamp(percentage / 100.0, 0.0, 1.0)
	
	if mystery_sprite:
		mystery_sprite.modulate.a = 1.0 - fade
	if sprite:
		sprite.modulate.a = fade

func reveal_insect():
	"""Revela completamente el insecto"""
	if is_revealed:
		return
	
	is_revealed = true
	print("[MysteryBug] ¡REVELADO! %s" % insect_data.name)
	
	play_revelation_animation()
	AudioManager.play_sfx("mystery_revealed")
	show_unlock_notification()
	
	# Agregar a pool normal
	GameManager.unlock_insect(mystery_index, insect_data)
	
	await get_tree().create_timer(1.5).timeout
	queue_free()

func play_reveal_effect():
	"""Efecto de partículas al golpear"""
	# Crear efecto visual simple (puedes mejorar con partículas reales)
	var flash = Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	flash.color = Color.YELLOW
	flash.global_position = global_position
	get_tree().root.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	await tween.finished
	flash.queue_free()

func play_revelation_animation():
	"""Animación épica de revelación"""
	var tween = create_tween()
	
	# Flash blanco
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# Zoom
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

func show_unlock_notification():
	"""Muestra notificación de desbloqueo"""
	print("[GameManager] ¡NUEVO INSECTO DESBLOQUEADO: %s!" % insect_data.name)
	# Aquí cargar escena de notificación desde scenes/ui/unlock_notification.tscn

```

---

### 7. **Player.gd**

```gdscript
extends Node2D

# ================================================================
# PLAYER - Control de Don Beto
# ================================================================

class_name Player

# Arma actual
var current_weapon: String = "zapato_viejo"
var weapon_damage: int = 1
var weapon_area_radius: float = 50.0

# Estadísticas
var total_hits: int = 0
var total_misses: int = 0
var accuracy: float = 0.0

func _input(event: InputEvent):
	if event is InputEventScreenTouch and event.pressed:
		handle_tap(event.position)

func handle_tap(tap_position: Vector2):
	"""Maneja tap en pantalla"""
	
	# Reproducir animación de golpe
	play_hit_animation(tap_position)
	
	# Detectar insectos en área
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = weapon_area_radius
	query.shape = circle_shape
	query.transform = Transform2D.IDENTITY.translated(tap_position)
	
	var results = space_state.intersect_shape(query)
	
	if results.is_empty():
		# Falló
		total_misses += 1
		trigger_nearby_taunts(tap_position)
	else:
		# Golpea insectos
		for result in results:
			var insect = result.collider
			if insect.is_in_group("insects"):
				insect.take_damage(weapon_damage)
				total_hits += 1
	
	update_accuracy()

func play_hit_animation(position: Vector2):
	"""Anima el golpe en pantalla"""
	# Crear efecto visual simple
	var circle = Circle2D.new()
	circle.position = position
	circle.radius = weapon_area_radius
	circle.color = Color.WHITE
	circle.width = 3
	get_tree().root.add_child(circle)
	
	var tween = create_tween()
	tween.tween_property(circle, "radius", weapon_area_radius * 2, 0.2)
	tween.tween_property(circle, "modulate:a", 0.0, 0.2)
	await tween.finished
	circle.queue_free()

func trigger_nearby_taunts(tap_position: Vector2):
	"""Activa burla de insectos cercanos"""
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 300.0  # Área más grande para burla
	query.shape = circle_shape
	query.transform = Transform2D.IDENTITY.translated(tap_position)
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var insect = result.collider
		if insect.is_in_group("insects") and not insect.is_dead:
			insect.taunt()

func update_accuracy():
	"""Actualiza porcentaje de precisión"""
	var total = total_hits + total_misses
	if total > 0:
		accuracy = (float(total_hits) / total) * 100

func equip_weapon(weapon_name: String):
	"""Equipa una nueva arma"""
	current_weapon = weapon_name
	
	match weapon_name:
		"zapato_viejo":
			weapon_damage = 1
			weapon_area_radius = 50.0
		
		"chancla_goma":
			weapon_damage = 1
			weapon_area_radius = 60.0
		
		"matamoscas_metalico":
			weapon_damage = 1
			weapon_area_radius = 80.0
		
		"sarten_hierro":
			weapon_damage = 2
			weapon_area_radius = 70.0
		
		"pala_electrificada":
			weapon_damage = 1
			weapon_area_radius = 90.0
	
	print("[Player] Equipo cambiano a: %s (Daño: %d, Radio: %.0f)" % [weapon_name, weapon_damage, weapon_area_radius])

```

---

## 📊 Sistemas Clave

### Sistema de Incógnito (Mystery Bug)

**Mecánica Principal:**
- Cada 10 niveles aparece un insecto misterio
- 100 insectos incógnito total (niveles 1-1000)
- Progresa con golpes
- Se revela completamente al alcanzar 100 puntos de revelación

**Progresión:**
```
Nivel 1-9:    Sin misterio
Nivel 10-19:  ??? Misterio #1 (se revela progresivamente)
Nivel 20:     Misterio #1 desbloqueado, entra en rotación normal
Nivel 20-29:  ??? Misterio #2 (nuevo ciclo)
Nivel 30:     Misterio #2 desbloqueado
...
Nivel 990-999: ??? Misterio #100
Nivel 1000:   Misterio #100 desbloqueado + FIN
```

**Impacto en Gameplay:**
- +50% monedas al golpear incógnito
- Sonido y visual distinto de golpes normales
- Notificación épica al desbloquear
- Incentiva seguir jugando para "ver qué viene"

---

### Sistema de Combo

```gdscript
# En GameManager
var combo_hits: int = 0         # Golpes consecutivos
var combo_max: int = 0          # Máximo del nivel

# Se incrementa cada vez que golpeas un insecto
# Se resetea cuando fallas un golpe (taunt)

# Recompensa:
# - Puntos base * (1 + combo_multiplier)
# - Dinero bonus al fin de nivel basado en combo_max
```

---

### Sistema de Progreso (1000 Niveles)

```gdscript
# Estructura
current_level: int     # 1-1000
current_chapter: int   # 1-10 (cada 100 niveles)

# Progresión automática
# Nivel 1-100:   Capítulo 1 (El Huerto)
# Nivel 101-200: Capítulo 2 (Invernadero)
# ... etc
# Nivel 901-1000: Capítulo 10 (Núcleo Reina)
```

---

## ⚙️ Configuración Recomendada

### Project.godot (Ajustes Importantes)

```ini
[application]
config/name="Invasión en el Huerto!"
config/version="0.1.0"
run/main_scene="res://scenes/main_game.tscn"

[autoload]
GameManager="res://scripts/autoload/game_manager.gd"
SaveManager="res://scripts/autoload/save_manager.gd"
AudioManager="res://scripts/autoload/audio_manager.gd"

[display]
window/size/viewport_width=540
window/size/viewport_height=960
window/handheld_match_viewport=true
window/size/mode=2

[rendering]
textures/canvas_textures/default_texture_filter=1
textures/vram_compression/import_etc2_astc=true

[physics]
default_gravity=0  # Sin gravedad (2D plano)
```

---

### Audio Bus Setup

Crear 2 buses en AudioBusLayout:
1. **Master** (principal)
2. **SFX** (efectos)
3. **Music** (música)

---

## ✅ Checklist de Implementación

### Fase 1: Setup Básico ⭐ (PRIORITARIO)
- [ ] Crear proyecto Godot 4.x
- [ ] Importar estructura de carpetas
- [ ] Crear GameManager como autoload
- [ ] Crear SaveManager
- [ ] Crear AudioManager
- [ ] Setupear project.godot

### Fase 2: Mecánicas Principales
- [ ] Implementar Player (manejo de taps)
- [ ] Implementar Insect base
- [ ] Implementar MysteryBug
- [ ] Crear main_game.tscn
- [ ] Spawner de insectos

### Fase 3: UI y Feedback
- [ ] HUD (puntuación, nivel, combo)
- [ ] Barra de revelación de incógnito
- [ ] Notificación de desbloqueo
- [ ] Pantalla de fin de nivel

### Fase 4: Contenido
- [ ] 9 capítulos con fondos
- [ ] Sprites de 10+ insectos
- [ ] Sprites de armas
- [ ] Sonidos (golpes, burla, revelación)

### Fase 5: Sistema de Progresión
- [ ] Tienda de armas
- [ ] Árbol de habilidades (3 ramas)
- [ ] Guardado/carga

### Fase 6: Polish
- [ ] Animaciones
- [ ] Partículas
- [ ] Música
- [ ] Efectos visuales

---

## 📝 Notas y Consideraciones

### Performance
- Usar object pooling para insectos (evita crear/destruir constantemente)
- Limitar cantidad simultánea de insectos en pantalla (~20 máximo)
- Usar atlases de texturas para sprites

### Accesibilidad
- Tamaño mínimo de área de golpe: 70px (toque cómodo)
- Contraste alto en UI
- Modo alto contraste para insectos

### Monetización
- Modelo: Pago único (sin ads, sin IAP)
- Considerar precio competitivo ($0.99-$2.99 USD)
- Incluir versión lite/demo gratuita

### Testing
- Probar cada 100 niveles
- Validar curva de dificultad
- Asegurar que combo system es justo
- Verificar que incógnitos se desbloquean correctamente

### Futuro
- Leaderboards online
- Challenges semanales
- Modo multijugador (pantalla compartida)
- Cosmetics desbloqueables

---

## 🔗 Rutas de Assets Esperadas

```
res://assets/sprites/insects/
  ├── hormiga_obrera.png
  ├── cucaracha_electrica.png
  ├── escarabajo_blindado.png
  ├── mosca_pesada.png
  ├── grillo_saltarin.png
  ├── hormiga_ladrona.png
  ├── abejorro_pinata.png
  ├── mantis_cronometro.png
  └── mystery_bug_silueta.png

res://assets/sprites/weapons/
  ├── zapato_viejo.png
  ├── chancla_goma.png
  ├── matamoscas_metalico.png
  ├── sarten_hierro.png
  └── pala_electrificada.png

res://assets/sounds/sfx/
  ├── hit_hormiga.ogg
  ├── hit_cucaracha.ogg
  ├── taunt.ogg
  ├── mystery_revealed.ogg
  └── level_complete.ogg

res://assets/sounds/music/
  ├── menu_theme.ogg
  ├── level_theme_1.ogg
  └── boss_theme.ogg
```

---

**Fin del documento**

Generado: Agosto 2026
Version: 1.0
