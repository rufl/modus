class_name AudioSystem
extends Node

signal music_changed(song_name: String)

## Completes pending initialization; false means teardown or pool-setup failure.
signal pools_ready(success: bool)

const CFG_PATH: String = "res://game/config/gameplay/audio.json5"
const SOUND_GEN_PATH: String = "res://game/core/tools/sound_generator.gd"
const POOL_SIZE_3D: int = 32
const POOL_SIZE_2D: int = 16
const JSON5_LOADER_PATH: String = "res://game/core/json5_loader.gd"
const SoundGeneratorScript = preload("res://game/core/tools/sound_generator.gd")

var sfx_bus: String = "SFX"
var music_bus: String = "Music"
var ambient_bus: String = "Ambient"
var master_volume: float = 0.0
var sfx_volume: float = 0.0
var music_volume: float = -10.0
var ambient_volume: float = -5.0
var base_fire_sound: AudioStream

var _audio_pool_3d: Array[AudioStreamPlayer3D] = []
var _audio_pool_2d: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _playlist: Array[String] = []
var _sound_gen: Script
var _event_config: Dictionary = {}
var _stream_cache: Dictionary = {}
var _generator_map: Dictionary = {}
var _current_song_name: String = ""
var _pool_init_tree: SceneTree
var _active: bool = false
var _initialized: bool = false


func _ready() -> void:
	_active = true
	name = "AudioService"
	_sound_gen = load(SOUND_GEN_PATH)
	_load_config()
	_init_generator_map()
	# Frame callbacks can be disconnected during teardown, unlike suspended coroutines.
	_pool_init_tree = get_tree()
	_pool_init_tree.process_frame.connect(_init_audio_pools, CONNECT_ONE_SHOT)
	_load_user_volume_settings()
	_scan_music_folder()

	# Verify audio system is working
	# Safe access during initialization - GameManager may not be ready yet
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var logger: Node = gm.get_core_system("logger")
	if logger:
		logger.debug(
			(
				"[AudioSystem] Initialized with %d 3D players, %d 2D players"
				% [_audio_pool_3d.size(), _audio_pool_2d.size()]
			),
			"Audio"
		)
		logger.debug(
			(
				"[AudioSystem] SFX bus index: %d, volume: %.1f dB"
				% [AudioServer.get_bus_index(sfx_bus), sfx_volume]
			),
			"Audio"
		)
		logger.debug("[AudioSystem] Generator map has %d entries" % _generator_map.size(), "Audio")

	# Test sound generation
	var test_stream: AudioStream = SoundGeneratorScript.generate_shoot_sound(1.0)
	if test_stream:
		if logger:
			logger.debug("[AudioSystem] Test sound generated successfully", "Audio")
	else:
		push_error("[AudioSystem] FAILED to generate test sound!")

	if logger:
		logger.info("[AudioSystem] Initialized", "Audio")


func _exit_tree() -> void:
	_active = false
	_initialized = false
	if _pool_init_tree:
		if _pool_init_tree.process_frame.is_connected(_init_audio_pools):
			_pool_init_tree.process_frame.disconnect(_init_audio_pools)
		if _pool_init_tree.process_frame.is_connected(_create_audio_pools):
			_pool_init_tree.process_frame.disconnect(_create_audio_pools)
		_pool_init_tree = null
	## === SIGNAL HYGIENE: Cleanup audio resources ===

	# Stop all audio
	if _music_player:
		_music_player.stop()
		_music_player.queue_free()
		_music_player = null

	# Clear audio pools
	for player in _audio_pool_3d:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_audio_pool_3d.clear()

	for player in _audio_pool_2d:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_audio_pool_2d.clear()

	# Clear caches
	_stream_cache.clear()
	_generator_map.clear()
	_event_config.clear()
	_playlist.clear()
	_current_song_name = ""
	pools_ready.emit(false)

	# Safe access during cleanup - GameManager may not be available
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var logger: Node = gm.get_core_system("logger")
	if logger:
		logger.info("[AudioSystem] Cleanup complete", "Audio")


func initialize() -> void:
	if not _active or _initialized:
		return
	if not _music_player:
		if not _pool_init_tree:
			return
		var success: bool = await pools_ready
		if not success or not _active or not _music_player:
			return
	# Multiple readiness waiters must not restart the user's current playback.
	if _initialized:
		return
	_initialized = true

	# Play a test sound to verify audio is working
	var test_stream: AudioStream = SoundGeneratorScript.generate_ui_sound("click")
	if test_stream and not _audio_pool_2d.is_empty():
		play_stream_2d(test_stream, 1.0, 0.0)
		# Safe access - GameManager should be ready by now
		var gm: Node = get_node_or_null("/root/GameManager")
		if not gm:
			return
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info("[AudioSystem] Played test sound on initialize", "Core")

	# Start music if playlist is available
	if not _playlist.is_empty():
		randomize()
		var track: String = _playlist.pick_random()
		var stream: AudioStream = load(track)
		if stream:
			play_music(stream)
			# Safe access - GameManager should be ready by now
			var gm: Node = get_node_or_null("/root/GameManager")
			if not gm:
				return
			var logger: Node = gm.get_core_system("logger")
			if logger:
				logger.info("[AudioSystem] Started music: %s" % track.get_file(), "Core")
		else:
			push_warning("[AudioSystem] Failed to load music track: %s" % track)
	else:
		push_warning("[AudioSystem] No music tracks found in playlist")


# --- Public API ---

## Play a generic audio event by name


func play_event(
	event_name: String,
	pos: Vector3 = Vector3.ZERO,
	is_2d: bool = false,
	volume_override: float = NAN,
	pitch_override: float = NAN
) -> void:
	var stream: AudioStream = _get_event_stream(event_name)
	var config: Dictionary = _event_config.get(event_name, {})
	var base_vol: float = config.get("volume", 0.0)
	var pitch_var: float = config.get("pitch_var", 0.0)
	var pitch: float = pitch_override
	var final_vol: float = volume_override

	if not stream:
		# Only warn for non-fire events (fire events have many variations)
		if not event_name.begins_with("fire_") and not event_name.begins_with("reload_"):
			push_warning("[AudioSystem] No stream found for event: %s" % event_name)
		return
	if is_nan(pitch):
		pitch = 1.0 + randf_range(-pitch_var, pitch_var)
	if is_nan(final_vol):
		final_vol = base_vol
	if is_2d or pos == Vector3.ZERO:
		play_stream_2d(stream, pitch, final_vol)
	else:
		play_stream_3d(stream, pos, pitch, final_vol)


## Get the AudioStream for an event (useful for attaching to AudioStreamPlayers)


func get_event_stream(event_name: String) -> AudioStream:
	return _get_event_stream(event_name)


func play_stream_2d(stream: AudioStream, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream:
		push_warning("[AudioSystem] play_stream_2d called with null stream")
		return
	var player: AudioStreamPlayer = _get_2d_player()
	if not player:
		push_warning("[AudioSystem] No available 2D audio player")
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func play_stream_3d(
	stream: AudioStream, pos: Vector3, pitch: float = 1.0, volume_db: float = 0.0
) -> void:
	if not stream:
		push_warning("[AudioSystem] play_stream_3d called with null stream")
		return
	var player: AudioStreamPlayer3D = _get_3d_player()
	if not player:
		push_warning("[AudioSystem] No available 3D audio player")
		return
	player.stream = stream
	player.global_position = pos
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func play_music(stream: AudioStream) -> void:
	if not _music_player:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()
	_current_song_name = stream.resource_path.get_file().get_basename().replace("_", " ")
	music_changed.emit(_current_song_name)


func get_current_song_name() -> String:
	return _current_song_name


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


## Legacy compatibility wrapper


func play_sound_at(
	event_name: String, pos: Vector3, volume: float = 0.0, pitch: float = 1.0
) -> void:
	play_event(event_name, pos, false, volume, pitch)


func play_sound_3d(
	event_name: String, pos: Vector3, volume: float = 0.0, pitch: float = 1.0
) -> void:
	play_sound_at(event_name, pos, volume, pitch)


func play_sound_2d(event_name: String, volume: float = 0.0, pitch: float = 1.0) -> void:
	play_event(event_name, Vector3.ZERO, true, volume, pitch)


# --- Legacy / Specialized Wrappers (Maintained for API compatibility) ---


func play_jump(pos: Vector3) -> void:
	play_event("jump", pos)


func play_land(pos: Vector3) -> void:
	play_event("land", pos)


func play_footstep(material: String, pos: Vector3, _vol: float = 0.0) -> void:
	play_event("footstep_" + material, pos)


func play_weapon_switch() -> void:
	play_event("weapon_switch", Vector3.ZERO, true)


func play_ui_sound(type: String = "click") -> void:
	play_event("ui_" + type, Vector3.ZERO, true)


func play_pickup_sound(pos: Vector3 = Vector3.ZERO) -> void:
	play_event("pickup", pos)


func play_teleport(pos: Vector3) -> void:
	play_event("teleport", pos)


func play_hero_landing(pos: Vector3) -> void:
	play_event("impact_heavy", pos)


func play_pain_grunt(is_heavy: bool = false) -> void:
	play_event("pain_heavy" if is_heavy else "pain", Vector3.ZERO, true)


func play_synthesized_hit(pos: Vector3) -> void:
	play_event("hit", pos)


func play_synthesized_crit(pos: Vector3) -> void:
	play_event("crit", pos)


func play_player_death(pos: Vector3) -> void:
	play_event("player_death", pos)


func play_enemy_death(pos: Vector3) -> void:
	play_event("enemy_death", pos)


func play_hit_marker(is_crit: bool = false) -> void:
	play_event("crit" if is_crit else "hit", Vector3.ZERO, true)


func play_kill_confirm() -> void:
	play_event("kill_confirm", Vector3.ZERO, true)


func play_weapon_fire(pos: Vector3, weapon_name: String) -> void:
	var event_name: String = "fire_" + weapon_name.to_lower().replace(" ", "_")
	if not _can_generate(event_name):
		event_name = "shoot"
	play_event(event_name, pos)


# --- Volume Setters (Required by OptionsScreen) ---


func set_master_volume(db: float) -> void:
	master_volume = db
	_set_bus_vol("Master", db)
	save_volume_settings()


func set_sfx_volume(db: float) -> void:
	sfx_volume = db
	_set_bus_vol(sfx_bus, db)
	save_volume_settings()


func set_music_volume(db: float) -> void:
	music_volume = db
	_set_bus_vol(music_bus, db)
	save_volume_settings()


func set_ambient_volume(db: float) -> void:
	ambient_volume = db
	_set_bus_vol(ambient_bus, db)
	save_volume_settings()


# --- Internal Setup ---


func _load_config() -> void:
	var loader: GDScript = load(JSON5_LOADER_PATH)
	if loader and loader.file_exists(CFG_PATH):
		var data: Variant = loader.load_file(CFG_PATH)
		if data is Dictionary:
			if data.has("events"):
				_event_config = data.events


func _init_generator_map() -> void:
	if not _sound_gen:
		return
	_generator_map = {
		"jump": func() -> AudioStream: return SoundGeneratorScript.generate_jump_sound(),
		"land": func() -> AudioStream: return SoundGeneratorScript.generate_land_sound(),
		"shoot": func() -> AudioStream: return SoundGeneratorScript.generate_shoot_sound(1.0),
		"reload":
		func() -> AudioStream: return SoundGeneratorScript.generate_reload_sound("pistol"),
		"pickup": func() -> AudioStream: return SoundGeneratorScript.generate_pickup_sound(),
		"weapon_switch":
		func() -> AudioStream: return SoundGeneratorScript.generate_weapon_switch_sound(),
		"teleport": func() -> AudioStream: return SoundGeneratorScript.generate_teleport_sound(),
		"player_death":
		func() -> AudioStream: return SoundGeneratorScript.generate_player_death_sound(),
		"enemy_death":
		func() -> AudioStream: return SoundGeneratorScript.generate_enemy_death_sound(),
		"enemy_death_critical":
		func() -> AudioStream: return SoundGeneratorScript.generate_enemy_death_sound(),
		"hit": func() -> AudioStream: return SoundGeneratorScript.generate_hit_sound(),
		"crit": func() -> AudioStream: return SoundGeneratorScript.generate_crit_sound(),
		"kill_confirm":
		func() -> AudioStream: return SoundGeneratorScript.generate_kill_confirm_sound(),
		"footstep_concrete":
		func() -> AudioStream: return SoundGeneratorScript.generate_footstep_sound("concrete"),
		"footstep_grass":
		func() -> AudioStream: return SoundGeneratorScript.generate_footstep_sound("grass"),
		"footstep_dirt":
		func() -> AudioStream: return SoundGeneratorScript.generate_footstep_sound("dirt"),
		"footstep_wood":
		func() -> AudioStream: return SoundGeneratorScript.generate_footstep_sound("wood"),
		"footstep_metal":
		func() -> AudioStream: return SoundGeneratorScript.generate_footstep_sound("metal"),
		"footstep_jump": func() -> AudioStream: return SoundGeneratorScript.generate_jump_sound(),
		"footstep_landing_light":
		func() -> AudioStream: return SoundGeneratorScript.generate_land_sound(),
		"footstep_landing_medium":
		func() -> AudioStream: return SoundGeneratorScript.generate_land_sound(),
		"footstep_landing_heavy":
		func() -> AudioStream: return SoundGeneratorScript.generate_land_sound(),
		"ui_click": func() -> AudioStream: return SoundGeneratorScript.generate_ui_sound("click"),
		"ui_back": func() -> AudioStream: return SoundGeneratorScript.generate_ui_sound("back"),
		"pain": func() -> AudioStream: return SoundGeneratorScript.generate_vocal_pain_sound(false),
		"pain_heavy":
		func() -> AudioStream: return SoundGeneratorScript.generate_vocal_pain_sound(true),
		"slide_start": func() -> AudioStream: return SoundGeneratorScript.generate_land_sound(),
		"slide_stop": func() -> AudioStream: return SoundGeneratorScript.generate_ui_sound("back"),
	}


func _get_event_stream(event_name: String) -> AudioStream:
	if _stream_cache.has(event_name):
		return _stream_cache[event_name]
	if _generator_map.has(event_name):
		var callable: Callable = _generator_map[event_name]
		var stream: AudioStream = callable.call()
		if stream:
			_stream_cache[event_name] = stream
		return stream
	if event_name.begins_with("fire_"):
		return _get_event_stream("shoot")
	return null


func _can_generate(event_name: String) -> bool:
	return _generator_map.has(event_name) or _stream_cache.has(event_name)


# --- Pooling ---


func _init_audio_pools() -> void:
	if not _active or not _pool_init_tree:
		return
	# Get GameManager once for the entire function
	var gm: Node = get_node_or_null("/root/GameManager")

	# Manually load the audio bus layout to ensure it's available
	var bus_layout_path := "res://game/default_bus_layout.tres"
	if ResourceLoader.exists(bus_layout_path):
		var bus_layout: AudioBusLayout = load(bus_layout_path)
		if bus_layout:
			AudioServer.set_bus_layout(bus_layout)
			# Safe access during initialization
			if gm:
				var logger_service: Node = gm.get_core_system("logger")
				if logger_service:
					logger_service.debug("[AudioSystem] Manually loaded audio bus layout", "Audio")

	# Loading the layout resets bus gains; restore user settings before playback starts.
	_apply_volume_settings()

	# Keep the existing frame boundary, but make the pending work cancellable.
	_pool_init_tree.process_frame.connect(_create_audio_pools, CONNECT_ONE_SHOT)


func _create_audio_pools() -> void:
	_pool_init_tree = null
	if not _active:
		return

	# Verify SFX bus exists
	var sfx_idx: int = AudioServer.get_bus_index(sfx_bus)
	if sfx_idx < 0:
		push_error(
			(
				"[AudioSystem] SFX bus '%s' not found after loading bus layout! " % sfx_bus
				+ "Audio will not work."
			)
		)
		push_error("[AudioSystem] Available buses: %s" % _get_available_buses())
		pools_ready.emit(false)
		return

	for i in POOL_SIZE_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = sfx_bus
		p.name = "Pool3D_%d" % i
		add_child(p)
		_audio_pool_3d.append(p)
	for i in POOL_SIZE_2D:
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		p.name = "Pool2D_%d" % i
		add_child(p)
		_audio_pool_2d.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = music_bus
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.debug(
			"[AudioSystem] Audio pools initialized: %d 3D, %d 2D" % [POOL_SIZE_3D, POOL_SIZE_2D],
			"Audio"
		)
	pools_ready.emit(true)


func _get_available_buses() -> String:
	var buses: Array[String] = []
	for i in range(AudioServer.bus_count):
		buses.append(AudioServer.get_bus_name(i))
	return ", ".join(buses)


func _get_3d_player() -> AudioStreamPlayer3D:
	for p in _audio_pool_3d:
		if not p.playing:
			return p
	return _audio_pool_3d[0] if not _audio_pool_3d.is_empty() else null


func _get_2d_player() -> AudioStreamPlayer:
	for p in _audio_pool_2d:
		if not p.playing:
			return p
	return _audio_pool_2d[0] if not _audio_pool_2d.is_empty() else null


# --- Volumes ---


func _load_user_volume_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		master_volume = config.get_value("audio", "master", 0.0)
		sfx_volume = config.get_value("audio", "sfx", 0.0)
		music_volume = config.get_value("audio", "music", -10.0)
		ambient_volume = config.get_value("audio", "ambient", -5.0)


func save_volume_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "ambient", ambient_volume)
	config.save("user://audio_settings.cfg")
	_apply_volume_settings()


func _apply_volume_settings() -> void:
	_set_bus_vol("Master", master_volume)
	_set_bus_vol(sfx_bus, sfx_volume)
	_set_bus_vol(music_bus, music_volume)
	_set_bus_vol(ambient_bus, ambient_volume)


func _set_bus_vol(local_bus_name: String, vol_db: float) -> void:
	var idx: int = AudioServer.get_bus_index(local_bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, vol_db)


# --- Music ---


func _scan_music_folder() -> void:
	_playlist.clear()
	var path: String = "res://game/art/audio/music/"
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if not dir.current_is_dir() and (file.ends_with(".mp3") or file.ends_with(".ogg")):
				_playlist.append(path + file)
			file = dir.get_next()
		dir.list_dir_end()

	# Safe access during initialization
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		print("[AudioSystem] Scanned music folder, found %d tracks" % _playlist.size())
		return
	var logger: Node = gm.get_core_system("logger")
	if logger:
		logger.info(
			"[AudioSystem] Scanned music folder, found %d tracks" % _playlist.size(), "Audio"
		)
		if _playlist.size() > 0:
			logger.debug("[AudioSystem] First track: %s" % _playlist[0].get_file(), "Audio")
	else:
		print("[AudioSystem] Scanned music folder, found %d tracks" % _playlist.size())


func play_next_track() -> void:
	if _playlist.is_empty():
		return

	if not _music_player:
		# Silently return - music player will be initialized soon
		return

	var current_idx := -1
	if _music_player.stream:
		current_idx = _playlist.find(_music_player.stream.resource_path)

	var next_idx := (current_idx + 1) % _playlist.size()
	play_music(load(_playlist[next_idx]))


func play_previous_track() -> void:
	if _playlist.is_empty():
		return

	if not _music_player:
		push_warning("[AudioSystem] Music player not initialized yet")
		return

	var current_idx := -1
	if _music_player.stream:
		current_idx = _playlist.find(_music_player.stream.resource_path)

	var prev_idx := (current_idx - 1 + _playlist.size()) % _playlist.size()
	play_music(load(_playlist[prev_idx]))
