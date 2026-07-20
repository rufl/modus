#!/usr/bin/env -S godot --headless --script
## Test runner for ragdoll physics preservation tests

extends SceneTree

var _gut: Node = null


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  RAGDOLL PHYSICS PRESERVATION TEST")
	print("  Verifying no regressions after bugfix implementation")
	print("=".repeat(70) + "\n")

	# Load GUT
	var gut_script: GDScript = load("res://addons/gut/gut.gd")
	if not gut_script:
		print("ERROR: Could not load GUT framework")
		quit(1)
		return

	_gut = gut_script.new()

	# Configure GUT (use property, not method)
	_gut.log_level = _gut.LOG_LEVEL_ALL_ASSERTS

	# Load GameManager autoload (required for ragdoll tests)
	var gm_script: GDScript = load("res://game/scripts/core/game_manager.gd")
	if gm_script:
		var gm: Node = gm_script.new()
		gm.name = "GameManager"
		get_root().add_child(gm)
		# Initialize GameManager
		if gm.has_method("initialize"):
			gm.initialize()
	else:
		print("WARNING: Could not load GameManager - tests may fail")

	# Add to scene tree first
	get_root().add_child(_gut)

	# Add test file
	_gut.add_script("res://tests/property/test_ragdoll_preservation_pbt.gd")

	# Connect signals
	if _gut.has_signal("tests_finished"):
		_gut.tests_finished.connect(_on_tests_finished)

	# Run tests
	print("Running preservation property-based tests...")
	_gut.test_scripts(true)


func _on_tests_finished() -> void:
	var passed: int = _gut.get_pass_count()
	var failed: int = _gut.get_fail_count()
	var total: int = passed + failed

	print("\n" + "=".repeat(70))
	print("  TEST RESULTS")
	print("=".repeat(70))
	print("  Total: %d | Passed: %d | Failed: %d" % [total, passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ All preservation tests passed!")
		print("  No regressions detected - existing features preserved.")
	else:
		print("✗ Some preservation tests failed!")
		print("  Regressions detected - review failures above.")

	print("=".repeat(70) + "\n")

	# Exit with appropriate code
	if failed > 0:
		quit(1)
	else:
		quit(0)
