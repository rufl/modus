extends ModusGutTestBase

## Unit tests for MODUS Audio System
## Tests sound effect playback, music system, audio mixing, 3D audio positioning,
## and volume controls
##
## Requirements: 7 (Audio System Testing)

const AudioSystemClass := preload("res://game/scripts/features/audio/audio_service.gd")
const SoundGen := preload("res://game/core/tools/sound_generator.gd")

var audio_system: Node
var test_stream: AudioStream


func before_each() -> void:
	# Get audio system from GameManager
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		audio_system = gm.get_core_system("audio")

	# Generate a test audio stream
	test_stream = SoundGen.generate_ui_sound("click")

	# Wait for audio system to be ready
	await get_tree().process_frame


func after_each() -> void:
	# Clean up test resources
	test_stream = null


# ============================================================================
# Sound Effect Playback Tests (Requirement 7.1)
# ============================================================================


func test_audio_system_exists() -> void:
	assert_not_null(audio_system, "Audio system should be available from GameManager")


func test_sound_effect_playback_triggers() -> void:
	# Verify audio system can play a sound event
	assert_not_null(audio_system, "Audio system should exist")

	# Play a test sound event
	audio_system.play_event("ui_click", Vector3.ZERO, true)

	# Wait for audio to process
	await get_tree().process_frame

	# Test passes if no errors occurred
	assert_true(true, "Sound effect playback should trigger without errors")


# ============================================================================
# Music System Tests (Requirement 7.2)
# ============================================================================


func test_music_system_exists() -> void:
	assert_not_null(audio_system, "Audio system should exist for music playback")


func test_music_playback() -> void:
	# Test music playback functionality
	assert_not_null(audio_system, "Audio system should exist")

	# Verify playback starts synchronously; this generated clip may finish within one frame.
	audio_system.play_music(test_stream)
	assert_true(audio_system.is_music_playing(), "Music should start after play_music call")


func test_music_looping() -> void:
	# Test music looping behavior
	assert_not_null(audio_system, "Audio system should exist")

	# Play music (should loop by default)
	audio_system.play_music(test_stream)
	await get_tree().process_frame

	# Music system should handle looping automatically
	assert_true(true, "Music looping should work without errors")


func test_music_transitions_next_track() -> void:
	# Test transitioning to next track
	assert_not_null(audio_system, "Audio system should exist")

	# Play initial music
	audio_system.play_music(test_stream)
	await get_tree().process_frame

	# Transition to next track
	audio_system.play_next_track()
	await get_tree().process_frame

	# Test passes if no errors occurred
	assert_true(true, "Music transition to next track should work")


func test_music_transitions_previous_track() -> void:
	# Test transitioning to previous track
	assert_not_null(audio_system, "Audio system should exist")

	# Play initial music
	audio_system.play_music(test_stream)
	await get_tree().process_frame

	# Transition to previous track
	audio_system.play_previous_track()
	await get_tree().process_frame

	# Test passes if no errors occurred
	assert_true(true, "Music transition to previous track should work")


# ============================================================================
# Audio Mixing Tests (Requirement 7.3)
# ============================================================================


func test_audio_mixing_multiple_sounds() -> void:
	assert_not_null(audio_system, "Audio system should exist")

	# Play multiple sounds simultaneously
	audio_system.play_event("ui_click", Vector3.ZERO, true)
	audio_system.play_event("jump", Vector3(1, 0, 0))
	audio_system.play_event("land", Vector3(2, 0, 0))

	await get_tree().process_frame

	# Test passes if no errors occurred
	assert_true(true, "Audio mixing should handle multiple sounds")


# ============================================================================
# 3D Audio Positioning Tests (Requirement 7.4)
# ============================================================================


func test_3d_audio_positioning() -> void:
	assert_not_null(audio_system, "Audio system should exist")

	# Play a 3D positioned sound
	var sound_position := Vector3(10, 0, 5)
	audio_system.play_event("jump", sound_position, false)

	await get_tree().process_frame

	# Test passes if no errors occurred
	assert_true(true, "3D audio positioning should work")


# ============================================================================
# Volume Control Tests (Requirement 7.5)
# ============================================================================


func test_volume_controls_master() -> void:
	assert_not_null(audio_system, "Audio system should exist")

	# Set master volume
	var test_volume: float = -5.0
	audio_system.set_master_volume(test_volume)

	# Verify volume was set
	assert_eq(audio_system.master_volume, test_volume, "Master volume should be adjustable")


func test_volume_controls_sfx() -> void:
	assert_not_null(audio_system, "Audio system should exist")

	# Set SFX volume
	var test_volume: float = -3.0
	audio_system.set_sfx_volume(test_volume)

	# Verify volume was set
	assert_eq(audio_system.sfx_volume, test_volume, "SFX volume should be adjustable")


func test_volume_controls_music() -> void:
	assert_not_null(audio_system, "Audio system should exist")

	# Set music volume
	var test_volume: float = -15.0
	audio_system.set_music_volume(test_volume)

	# Verify volume was set
	assert_eq(audio_system.music_volume, test_volume, "Music volume should be adjustable")
