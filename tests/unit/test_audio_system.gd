extends ModusGutTestBase

## Playback contract for the canonical AudioSystem service.
## Deferred startup, teardown, and bus settings are covered by test_audio_lifecycle.gd.

const SoundGen := preload("res://game/core/tools/sound_generator.gd")

var audio_system: Node
var test_stream: AudioStream


func before_each() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		audio_system = gm.get_core_system("audio")
		await audio_system.initialize()
	test_stream = SoundGen.generate_ui_sound("click")


func after_each() -> void:
	test_stream = null


func test_music_playback() -> void:
	assert_not_null(audio_system, "Audio system should exist")
	# The generated clip may finish within one frame; inspect playback immediately.
	audio_system.play_music(test_stream)
	assert_true(audio_system.is_music_playing(), "Music should start after play_music call")
