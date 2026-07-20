#!/usr/bin/env -S godot --headless --script
## Test runner for ragdoll physics bug exploration test

extends SceneTree

var _gut: Node = null


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  RAGDOLL PHYSICS BUG EXPLORATION TEST")
	print("=".repeat(70) + "\n")

	# Load GUT
	var gut_script: GDScript = load("res://addons/gut/gut.gd")
	if not gut_script:
		print("ERROR: Could not load GUT framework")
		quit(1)
		return

	_gut = gut_script.new()

	# Configure GUT (use properties, not methods)
	_gut.log_level = _gut.LOG_LEVEL_ALL_ASSERTS

	# Add to scene tree
	get_root().add_child(_gut)

	# Add test file
	_gut.add_script("res://tests/property/test_ragdoll_physics_bug_exploration_pbt.gd")

	# Connect signals
	_gut.tests_finished.connect(_on_tests_finished)

	# Run tests
	_gut.test_scripts()


func _on_tests_finished() -> void:
	var passed: int = _gut.get_pass_count()
	var failed: int = _gut.get_fail_count()
	var total: int = passed + failed

	print("\n" + "=".repeat(70))
	print("  TEST RESULTS")
	print("=".repeat(70))
	print("  Total: %d | Passed: %d | Failed: %d" % [total, passed, failed])
	print("=".repeat(70) + "\n")

	# Exit with appropriate code
	if failed > 0:
		quit(1)
	else:
		quit(0)
