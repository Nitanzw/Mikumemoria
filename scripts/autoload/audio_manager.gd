extends Node

## AUDIO MANAGER - Control de sonidos (autoload "AudioManager").

const SFX_PLAYER_COUNT := 6
const SFX_DIR := "res://assets/sounds/sfx/"
const MUSIC_DIR := "res://assets/sounds/music/"

# Se prueban en este orden de "mejor a peor" fuente: .ogg para assets
# definitivos (bancos como Kenney/freesound), .mp3 para lo que genera
# tools/generate_music_suno.py, y .wav como placeholder sintetizado de
# último recurso. Así no hace falta tocar código al reemplazar assets:
# alcanza con soltar el archivo con el mismo nombre.
const AUDIO_EXTENSIONS := ["ogg", "mp3", "wav"]

var sfx_players: Array[AudioStreamPlayer] = []
var current_music: AudioStreamPlayer
var sfx_cache: Dictionary = {}
## Nombres que tienen varias tomas (`splat_1`, `splat_2`, ...). Se resuelve
## una sola vez por nombre y queda cacheado.
var sfx_variants: Dictionary = {}

func _ready() -> void:
	print("[AudioManager] Inicializando...")
	_setup_sfx_players()

func _setup_sfx_players() -> void:
	for i in range(SFX_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		sfx_players.append(player)

func _resolve_path(dir: String, base_name: String) -> String:
	for ext in AUDIO_EXTENSIONS:
		var path := "%s%s.%s" % [dir, base_name, ext]
		if ResourceLoader.exists(path):
			return path
	return ""

## Cuántas tomas alternativas se buscan como máximo por nombre.
const MAX_SFX_VARIANTS := 6

## Devuelve el nombre a reproducir. Si hay tomas numeradas se elige una al
## azar: un sonido de aplastar que suena idéntico veinte veces por nivel
## se vuelve insoportable, y alternar dos tomas ya rompe la repetición.
func _pick_variant(sfx_name: String) -> String:
	if not sfx_variants.has(sfx_name):
		var found: Array[String] = []
		for i in range(1, MAX_SFX_VARIANTS + 1):
			var candidate := "%s_%d" % [sfx_name, i]
			if _resolve_path(SFX_DIR, candidate) != "":
				found.append(candidate)
		sfx_variants[sfx_name] = found
	var variants: Array = sfx_variants[sfx_name]
	if variants.is_empty():
		return sfx_name
	return str(variants[randi() % variants.size()])

func play_sfx(sfx_name: String) -> void:
	sfx_name = _pick_variant(sfx_name)
	if not sfx_cache.has(sfx_name):
		var path := _resolve_path(SFX_DIR, sfx_name)
		if path == "":
			print("[AudioManager] Sonido no encontrado: %s" % sfx_name)
			return
		sfx_cache[sfx_name] = load(path)

	var available_player := _get_available_sfx_player()
	if available_player:
		available_player.stream = sfx_cache[sfx_name]
		available_player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	# Todos ocupados: reutiliza el primero para no perder el golpe.
	return sfx_players[0] if not sfx_players.is_empty() else null

func has_music(music_name: String) -> bool:
	return _resolve_path(MUSIC_DIR, music_name) != ""

func play_music(music_name: String, fade_in: float = 0.0, loop: bool = true) -> void:
	var path := _resolve_path(MUSIC_DIR, music_name)
	if path == "":
		print("[AudioManager] Música no encontrada: %s" % music_name)
		return

	if current_music and current_music.playing:
		if fade_in > 0.0:
			var out_tween := create_tween()
			out_tween.tween_property(current_music, "volume_db", -80.0, fade_in)
			await out_tween.finished
		current_music.stop()
		current_music.queue_free()

	current_music = AudioStreamPlayer.new()
	current_music.bus = &"Music"
	add_child(current_music)
	current_music.stream = load(path)
	current_music.volume_db = 0.0

	if loop:
		# Bucle manejado por código: no depende de que el recurso de audio
		# tenga metadata de loop configurada en su importación.
		current_music.finished.connect(current_music.play)

	current_music.play()

func stop_music(fade_out: float = 0.0) -> void:
	if current_music and current_music.playing:
		if current_music.finished.is_connected(current_music.play):
			current_music.finished.disconnect(current_music.play)
		if fade_out > 0.0:
			var tween := create_tween()
			tween.tween_property(current_music, "volume_db", -80.0, fade_out)
			await tween.finished
		current_music.stop()
