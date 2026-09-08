extends ModusGutTestBase

const AudioSystemScript := preload("res://game/scripts/features/audio/audio_service.gd")
const SoundGenerator := preload("res://game/core/tools/sound_generator.gd")


class InitializationWaiter:
	extends RefCounted

	var completed: bool = false
	var on_ready: Callable

	func start(audio: Node) -> void:
		await audio.initialize()
		completed = true
		if on_ready.is_valid():
			on_ready.call()


var _bus_layout: AudioBusLayout
var _settings_existed: bool
var _settings_bytes: PackedByteArray


func before_each() -> void:
	await GameManager.get_core_system("audio").initialize()
	_bus_layout = AudioServer.generate_bus_layout()
	_settings_existed = FileAccess.file_exists("user://audio_settings.cfg")
	if _settings_existed:
		_settings_bytes = FileAccess.get_file_as_bytes("user://audio_settings.cfg")


func after_each() -> void:
	AudioServer.set_bus_layout(_bus_layout)
	_bus_layout = null
	if _settings_existed:
		var file := FileAccess.open("user://audio_settings.cfg", FileAccess.WRITE)
		file.store_buffer(_settings_bytes)
		file.close()
	else:
		DirAccess.remove_absolute("user://audio_settings.cfg")
	_settings_bytes.clear()


func test_detach_cancels_waiting_initialization_without_recreating_players() -> void:
	var audio := AudioSystemScript.new()
	add_child_autofree(audio)
	var waiter := InitializationWaiter.new()
	waiter.start(audio)
	# Let the deferred pool setup begin and suspend before detaching.
	await get_tree().process_frame
	remove_child(audio)
	for frame in range(3):
		await get_tree().process_frame
	assert_true(waiter.completed, "Teardown must release callers awaiting readiness")
	assert_eq(audio.get_child_count(), 0, "Canceled startup must not recreate audio players")
	assert_false(audio.is_music_playing())


func test_free_before_deferred_startup_does_not_resume_dead_service() -> void:
	var audio := AudioSystemScript.new()
	add_child(audio)
	var waiter := InitializationWaiter.new()
	waiter.start(audio)
	audio.free()
	for frame in range(3):
		await get_tree().process_frame
	assert_true(waiter.completed, "Freeing the service must finish pending initialization callers")


func test_reentry_can_initialize_and_play_after_canceled_startup() -> void:
	var audio := AudioSystemScript.new()
	add_child_autofree(audio)
	var old_waiter := InitializationWaiter.new()
	old_waiter.start(audio)
	await get_tree().process_frame
	remove_child(audio)
	audio.request_ready()
	add_child(audio)
	await audio.initialize()
	assert_true(old_waiter.completed, "The canceled lifetime cannot survive into the next entry")
	assert_true(audio.is_music_playing(), "The new lifetime must reach playable readiness")
	remove_child(audio)
	for frame in range(3):
		await get_tree().process_frame
	assert_eq(audio.get_child_count(), 0, "Reentry must not strand duplicate audio players")
	assert_false(audio.is_music_playing())


func test_repeated_initialize_preserves_current_music() -> void:
	var audio := AudioSystemScript.new()
	add_child_autoqfree(audio)
	await audio.initialize()
	var chosen_music: AudioStream = SoundGenerator.generate_ui_sound("click")
	audio.play_music(chosen_music)
	var chosen_name: String = audio.get_current_song_name()
	watch_signals(audio)
	await audio.initialize()
	assert_eq(
		audio.get_current_song_name(), chosen_name, "Initialization cannot replace chosen music"
	)
	assert_signal_not_emitted(audio, "music_changed")


func test_sounds_before_readiness_do_not_break_later_playback() -> void:
	var audio := AudioSystemScript.new()
	add_child_autoqfree(audio)
	var stream: AudioStream = SoundGenerator.generate_ui_sound("click")
	audio.play_stream_2d(stream)
	audio.play_stream_3d(stream, Vector3.ONE)
	await audio.initialize()
	audio.play_stream_3d(stream, Vector3(2, 3, 4))
	var playing: Array[Node] = audio.get_children().filter(
		func(child: Node) -> bool: return child is AudioStreamPlayer3D and child.playing
	)
	assert_eq(playing.size(), 1, "Ready spatial playback must start exactly one source")
	if not playing.is_empty():
		assert_eq(playing[0].global_position, Vector3(2, 3, 4))


func test_failed_pool_setup_releases_readiness_waiters() -> void:
	var audio := AudioSystemScript.new()
	add_child_autoqfree(audio)
	audio.sfx_bus = "__missing_audio_lifecycle_bus"
	var waiter := InitializationWaiter.new()
	waiter.start(audio)
	for frame in range(3):
		await get_tree().process_frame
	assert_push_error_count(2)
	assert_true(waiter.completed, "Invalid bus configuration cannot strand readiness waiters")
	assert_eq(audio.get_child_count(), 0)
	assert_false(audio.is_music_playing())
	await audio.initialize()
	assert_false(audio.is_music_playing(), "Repeated initialization cannot bypass failed setup")


func test_startup_preserves_configured_mixer_volumes() -> void:
	var audio := AudioSystemScript.new()
	add_child_autoqfree(audio)
	audio.set_master_volume(-7.0)
	audio.set_sfx_volume(-9.0)
	audio.set_music_volume(-13.0)
	audio.set_ambient_volume(-15.0)
	await audio.initialize()
	var expected: Dictionary = {
		"Master": -7.0, audio.sfx_bus: -9.0, audio.music_bus: -13.0, audio.ambient_bus: -15.0
	}
	var observed: Dictionary = {}
	for bus_name: String in expected:
		observed[bus_name] = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))
	assert_eq(observed, expected, "Pool startup must not reset the actual mixer to layout defaults")


func test_concurrent_initialize_waiters_do_not_restart_selected_music() -> void:
	var audio := AudioSystemScript.new()
	add_child_autoqfree(audio)
	var first := InitializationWaiter.new()
	var second := InitializationWaiter.new()
	var selected: AudioStream = SoundGenerator.generate_ui_sound("click")
	first.on_ready = audio.play_music.bind(selected)
	watch_signals(audio)
	first.start(audio)
	second.start(audio)
	await audio.initialize()
	assert_true(first.completed)
	assert_true(second.completed)
	assert_signal_emit_count(
		audio, "music_changed", 2, "Only startup and the first waiter's music selection may play"
	)
