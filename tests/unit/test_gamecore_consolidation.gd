extends Node

var test_results: Dictionary = {
	"subsystems_exist": false,
	"audio_service_works": false,
	"event_service_works": false,
	"logger_service_works": false,
	"globals_service_works": false,
}


func _init() -> void:
	print("\n=== Testing GameCore Consolidation ===\n")

	# Wait for project initialization
	# Wait for project initialization
	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(_run_tests)


func _run_tests() -> void:
	# Retry logic for finding GameManager if it's still loading
	var manager: Node = get_node_or_null("/root/GameManager")
	if not manager:
		print("Waiting for GameManager registration...")
		get_tree().create_timer(1.0).timeout.connect(_run_tests)
		return

	# Wait for GameManager to be ready if it has initialization
	if manager.has_method("get_state") and manager.get_state() == 0:  # INITIALIZING
		print("Waiting for GameManager initialization...")
		await get_tree().process_frame
		_run_tests()
		return

	_test_subsystems_exist()
	_test_audio_service()
	_test_event_service()
	_test_logger_service()
	_test_globals_service()

	_print_results()
	get_tree().quit()


func _test_subsystems_exist() -> void:
	print("[TEST] Checking if subsystems exist...")
	var manager: Node = get_node_or_null("/root/GameManager")
	var audio = manager.get_core_system("audio") if manager else null
	var events = manager.get_core_system("events") if manager else null
	var logger = manager.get_core_system("logger") if manager else null
	var globals = manager.get_core_system("globals") if manager else null

	if manager and audio and events and logger and globals:
		test_results["subsystems_exist"] = true
		print("  ✓ All subsystems exist")
	else:
		print("  ✗ Missing subsystems!")
		if not manager:
			print("    - GameManager is null")
		elif not audio:
			print("    - audio subsystem missing")
		elif not events:
			print("    - events subsystem missing")
		elif not logger:
			print("    - logger subsystem missing")
		elif not globals:
			print("    - globals subsystem missing")


func _test_audio_service() -> void:
	print("[TEST] Testing AudioService...")
	var manager: Node = get_node_or_null("/root/GameManager")
	var audio = manager.get_core_system("audio") if manager else null

	if manager and audio:
		# Test method exists
		if audio.has_method("play_sound_3d"):
			test_results["audio_service_works"] = true
			print("  ✓ AudioService has expected methods")
		else:
			print("  ✗ AudioService missing methods")
	else:
		print("  ✗ AudioService not available")


func _test_event_service() -> void:
	print("[TEST] Testing EventService...")
	var manager: Node = get_node_or_null("/root/GameManager")
	var events = manager.get_core_system("events") if manager else null

	if manager and events:
		# Test signals exist
		var has_signals: bool = (
			events.has_signal("weapon_fired") and events.has_signal("damage_dealt")
		)
		if has_signals:
			test_results["event_service_works"] = true
			print("  ✓ EventService has expected signals")
		else:
			print("  ✗ EventService missing signals")
	else:
		print("  ✗ EventService not available")


func _test_logger_service() -> void:
	print("[TEST] Testing LogService...")
	var manager: Node = get_node_or_null("/root/GameManager")
	var logger = manager.get_core_system("logger") if manager else null

	if manager and logger:
		# Test logging methods exist
		if logger.has_method("info") and logger.has_method("debug") and logger.has_method("error"):
			test_results["logger_service_works"] = true
			logger.info("Test log message", "Test")
			print("  ✓ LogService has expected methods")
		else:
			print("  ✗ LogService missing methods")
	else:
		print("  ✗ LogService not available")


func _test_globals_service() -> void:
	print("[TEST] Testing GlobalState...")
	var manager: Node = get_node_or_null("/root/GameManager")
	var globals = manager.get_core_system("globals") if manager else null

	if manager and globals:
		# Test properties exist
		if "sensitivity" in globals and "current_save_slot" in globals:
			test_results["globals_service_works"] = true
			print("  ✓ GlobalState has expected properties")
		else:
			print("  ✗ GlobalState missing properties")
	else:
		print("  ✗ GlobalState not available")


func _print_results() -> void:
	print("\n=== Test Results ===")
	var passed: int = 0
	var total: int = test_results.size()

	for test_name: String in test_results:
		var result: bool = test_results[test_name]
		var icon: String = "✓" if result else "✗"
		var status: String = "PASS" if result else "FAIL"
		print("%s %s: %s" % [icon, test_name, status])
		if result:
			passed += 1

	print("\n%d/%d tests passed" % [passed, total])
	if passed == total:
		print("🎉 All tests PASSED!")
	else:
		print("❌ Some tests FAILED")
