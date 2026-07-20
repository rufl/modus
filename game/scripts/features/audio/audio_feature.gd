## AudioFeature - Feature module for audio system
##
## Manages audio playback including sound effects, music, and voice.
## Provides API for playing sounds at positions, managing volume, and music playback.
##
## Requirements: 2.3
class_name AudioFeature
extends FeatureModule

const SoundGenerator = preload("res://game/core/tools/sound_generator.gd")

signal music_changed(song_name: String)

## Audio bus names
var sfx_bus: String = "SFX"
var music_bus: String = "Music"
var ambient_bus: String = "Ambient"

## Volume settings (in dB)
var master_volume: float = 0.0
var sfx_volume: float = 0.0
var music_volume: float = -10.0
var ambient_volume: float = -5.0

## Pool sizes
var pool_size_3d: int = 32
var pool_size_2d: int = 16

## Internal state
var _audio_pool_3d: Array[AudioStreamPlayer3D] = []
var _audio_pool_2d: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _playlist: Array[String] = []
var _event_config: Dictionary = {}
var _stream_cache: Dictionary = {}
var _generator_map: Dictionary = {}
var _current_song_name: String = ""


## Constructor
func _init() -> void:
	super._init("audio")
	feature_name = "Audio System"


## Initialize the audio feature
func initialize() -> void:
	super.initialize()

	# Load configuration values
	sfx_bus = get_config_value("sfx_bus", "SFX")
	music_bus = get_config_value("music_bus", "Music")
	ambient_bus = get_config_value("ambient_bus", "Ambient")
	pool_size_3d = get_config_value("pool_size_3d", 32)
	pool_size_2d = get_config_value("pool_size_2d", 16)

	# Load event configuration
	_event_config = config.get("events", {})

	# Initialize subsystems
	_init_generator_map()
	_init_audio_pools()
	_load_user_volume_settings()
	_apply_volume_settings()
	_scan_music_folder()

	# Test sound generation
	var test_stream: AudioStream = SoundGenerator.generate_ui_sound("click")
	if test_stream:
		play_stream_2d(test_stream, 1.0, 0.0)


## Shutdown the audio feature
func shutdown() -> void:
	# Clean up audio players
	for player in _audio_pool_3d:
		if is_instance_valid(player):
			player.queue_free()
	for player in _audio_pool_2d:
		if is_instance_valid(player):
			player.queue_free()
	if _music_player and is_instance_valid(_music_player):
		_music_player.queue_free()

	_audio_pool_3d.clear()
	_audio_pool_2d.clear()
	_stream_cache.clear()

	super.shutdown()


## Play a generic audio event by name
func play_event(
	event_name: String,
	pos: Vector3 = Vector3.ZERO,
	is_2d: bool = false,
	volume_override: float = NAN,
	pitch_override: float = NAN
) -> void:
	var stream: AudioStream = _get_event_stream(event_name)
	var event_cfg: Dictionary = _event_config.get(event_name, {})
	var base_vol: float = event_cfg.get("volume", 0.0)
	var pitch_var: float = event_cfg.get("pitch_var", 0.0)
	var pitch: float = pitch_override
	var final_vol: float = volume_override

	if not stream:
		if not event_name.begins_with("fire_") and not event_name.begins_with("reload_"):
			push_warning("[AudioFeature] No stream found for event: %s" % event_name)
		return

	if is_nan(pitch):
		pitch = 1.0 + randf_range(-pitch_var, pitch_var)
	if is_nan(final_vol):
		final_vol = base_vol

	if is_2d or pos == Vector3.ZERO:
		play_stream_2d(stream, pitch, final_vol)
	else:
		play_stream_3d(stream, pos, pitch, final_vol)


## Get the AudioStream for an event
func get_event_stream(event_name: String) -> AudioStream:
	return _get_event_stream(event_name)


## Play a 2D audio stream
func play_stream_2d(stream: AudioStream, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream:
		push_warning("[AudioFeature] play_stream_2d called with null stream")
		return
	var player: AudioStreamPlayer = _get_2d_player()
	if not player:
		push_warning("[AudioFeature] No available 2D audio player")
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


## Play a 3D audio stream at a position
func play_stream_3d(
	stream: AudioStream, pos: Vector3, pitch: float = 1.0, volume_db: float = 0.0
) -> void:
	if not stream:
		push_warning("[AudioFeature] play_stream_3d called with null stream")
		return
	var player: AudioStreamPlayer3D = _get_3d_player()
	if not player:
		push_warning("[AudioFeature] No available 3D audio player")
		return
	player.stream = stream
	player.global_position = pos
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


## Play music track
func play_music(stream: AudioStream) -> void:
	if not _music_player:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()
	_current_song_name = stream.resource_path.get_file().get_basename().replace("_", " ")
	music_changed.emit(_current_song_name)


## Get current song name
func get_current_song_name() -> String:
	return _current_song_name


## Play next track in playlist
func play_next_track() -> void:
	if _playlist.is_empty():
		return

	var current_idx := -1
	if _music_player.stream:
		current_idx = _playlist.find(_music_player.stream.resource_path)

	var next_idx := (current_idx + 1) % _playlist.size()
	play_music(load(_playlist[next_idx]))


## Play previous track in playlist
func play_previous_track() -> void:
	if _playlist.is_empty():
		return

	var current_idx := -1
	if _music_player.stream:
		current_idx = _playlist.find(_music_player.stream.resource_path)

	var prev_idx := (current_idx - 1 + _playlist.size()) % _playlist.size()
	play_music(load(_playlist[prev_idx]))


## Set master volume
func set_master_volume(db: float) -> void:
	master_volume = db
	_set_bus_vol("Master", db)
	save_volume_settings()


## Set SFX volume
func set_sfx_volume(db: float) -> void:
	sfx_volume = db
	_set_bus_vol(sfx_bus, db)
	save_volume_settings()


## Set music volume
func set_music_volume(db: float) -> void:
	music_volume = db
	_set_bus_vol(music_bus, db)
	save_volume_settings()


## Set ambient volume
func set_ambient_volume(db: float) -> void:
	ambient_volume = db
	_set_bus_vol(ambient_bus, db)
	save_volume_settings()


## Save volume settings to user config
func save_volume_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.save("user://audio_settings.cfg")
	_apply_volume_settings()


## Initialize sound generator map
func _init_generator_map() -> void:
	_generator_map = {
		"jump": func() -> AudioStream: return SoundGenerator.generate_jump_sound(),
		"land": func() -> AudioStream: return SoundGenerator.generate_land_sound(),
		"shoot": func() -> AudioStream: return SoundGenerator.generate_shoot_sound(1.0),
		"reload": func() -> AudioStream: return SoundGenerator.generate_reload_sound("pistol"),
		"pickup": func() -> AudioStream: return SoundGenerator.generate_pickup_sound(),
		"weapon_switch":
		func() -> AudioStream: return SoundGenerator.generate_weapon_switch_sound(),
		"teleport": func() -> AudioStream: return SoundGenerator.generate_teleport_sound(),
		"player_death": func() -> AudioStream: return SoundGenerator.generate_player_death_sound(),
		"enemy_death": func() -> AudioStream: return SoundGenerator.generate_enemy_death_sound(),
		"hit": func() -> AudioStream: return SoundGenerator.generate_hit_sound(),
		"crit": func() -> AudioStream: return SoundGenerator.generate_crit_sound(),
		"kill_confirm": func() -> AudioStream: return SoundGenerator.generate_kill_confirm_sound(),
		"footstep_concrete":
		func() -> AudioStream: return SoundGenerator.generate_footstep_sound("concrete"),
		"footstep_grass":
		func() -> AudioStream: return SoundGenerator.generate_footstep_sound("grass"),
		"footstep_dirt":
		func() -> AudioStream: return SoundGenerator.generate_footstep_sound("dirt"),
		"footstep_wood":
		func() -> AudioStream: return SoundGenerator.generate_footstep_sound("wood"),
		"footstep_metal":
		func() -> AudioStream: return SoundGenerator.generate_footstep_sound("metal"),
		"ui_click": func() -> AudioStream: return SoundGenerator.generate_ui_sound("click"),
		"ui_back": func() -> AudioStream: return SoundGenerator.generate_ui_sound("back"),
		"pain": func() -> AudioStream: return SoundGenerator.generate_vocal_pain_sound(false),
		"pain_heavy": func() -> AudioStream: return SoundGenerator.generate_vocal_pain_sound(true),
	}


## Get event stream from cache or generator
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


## Initialize audio player pools
func _init_audio_pools() -> void:
	var sfx_idx: int = AudioServer.get_bus_index(sfx_bus)
	if sfx_idx < 0:
		push_error("[AudioFeature] SFX bus '%s' not found!" % sfx_bus)
		return

	for i in pool_size_3d:
		var p := AudioStreamPlayer3D.new()
		p.bus = sfx_bus
		p.name = "Pool3D_%d" % i
		add_child(p)
		_audio_pool_3d.append(p)

	for i in pool_size_2d:
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		p.name = "Pool2D_%d" % i
		add_child(p)
		_audio_pool_2d.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = music_bus
	_music_player.name = "MusicPlayer"
	add_child(_music_player)


## Get available 3D player from pool
func _get_3d_player() -> AudioStreamPlayer3D:
	for p in _audio_pool_3d:
		if not p.playing:
			return p
	return _audio_pool_3d[0]


## Get available 2D player from pool
func _get_2d_player() -> AudioStreamPlayer:
	for p in _audio_pool_2d:
		if not p.playing:
			return p
	return _audio_pool_2d[0]


## Load user volume settings
func _load_user_volume_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://audio_settings.cfg") == OK:
		master_volume = cfg.get_value("audio", "master", 0.0)
		sfx_volume = cfg.get_value("audio", "sfx", 0.0)
		music_volume = cfg.get_value("audio", "music", -10.0)
		ambient_volume = cfg.get_value("audio", "ambient", -5.0)


## Apply volume settings to audio buses
func _apply_volume_settings() -> void:
	_set_bus_vol("Master", master_volume)
	_set_bus_vol(sfx_bus, sfx_volume)
	_set_bus_vol(music_bus, music_volume)
	_set_bus_vol(ambient_bus, ambient_volume)


## Set bus volume
func _set_bus_vol(local_bus_name: String, vol_db: float) -> void:
	var idx: int = AudioServer.get_bus_index(local_bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, vol_db)


## Scan music folder for tracks
func _scan_music_folder() -> void:
	_playlist.clear()
	var path: String = get_config_value("music_folder", "res://game/art/audio/music/")
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if not dir.current_is_dir() and (file.ends_with(".mp3") or file.ends_with(".ogg")):
				_playlist.append(path + file)
			file = dir.get_next()
