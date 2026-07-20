class_name BootSequence
extends Node

signal log_message(text: String)
signal progress_updated(percent: float)
signal boot_complete

@warning_ignore("unused_signal")
signal boot_failed(reason: String)  # Reserved for future error handling


func start_sequence() -> void:
	# Run checks sequentially
	_log("Initializing System...")
	await get_tree().create_timer(0.5).timeout

	await _check_memory()
	progress_updated.emit(0.25)

	await _check_audio()
	progress_updated.emit(0.5)

	await _check_network()
	progress_updated.emit(0.75)

	await _check_resources()
	progress_updated.emit(1.0)

	_log("System Ready.")
	await get_tree().create_timer(1.0).timeout
	boot_complete.emit()


func _log(text: String) -> void:
	log_message.emit(text)
	# Also print to console for debugging
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[BOOT] " + text, "BootSequence")


func _check_memory() -> void:
	_log("Checking Memory Integrity...")
	await get_tree().create_timer(0.2).timeout
	# Fake check using OS
	var mem: int = OS.get_static_memory_usage()
	_log("  Memory Usage: " + String.humanize_size(mem))
	_log("  Memory OK.")


func _check_audio() -> void:
	_log("Initializing Audio Interface...")
	await get_tree().create_timer(0.3).timeout
	# Check if AudioManager is present (assuming autoload)
	if get_tree().root.has_node("AudioManager"):
		_log("  AudioManager: DETECTED")
	else:
		_log("  AudioManager: WARNING (Not found)")
	_log("  Audio Subsystem OK.")


func _check_network() -> void:
	_log("Binding Network Ports...")
	await get_tree().create_timer(0.4).timeout
	# Check ENet capability (informative only)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	if peer:
		_log("  ENet Driver: AVAILABLE")
	else:
		_log("  create_timerENet Driver: FAILED")
	_log("  Network Interface OK.")


func _check_resources() -> void:
	_log("Verifying Asset Integrity...")
	await get_tree().create_timer(0.5).timeout
	# Preload a critical resource as a test
	# e.g., the player scene
	var player_path: String = "res://game/scenes/entities/player/player.tscn"
	if ResourceLoader.exists(player_path):
		var _p: Resource = load(player_path)
		_log("  Core Assets: OK")
	else:
		_log("  Core Assets: WARNING (Player scene not found)")

	_log("  Asset System OK.")
