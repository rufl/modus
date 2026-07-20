#!/usr/bin/env -S godot --headless --script
# Headless GUT Test Runner for CI/CD
# This script runs all GUT tests in headless mode for automated testing
extends SceneTree

var _gut: Node = null
var _game_manager: Node = null


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  MODUS TEST SUITE - Headless Execution")
	print("=".repeat(70) + "\n")

	# Load and initialize GameManager autoload manually
	var gm_script: GDScript = load("res://game/scripts/core/game_manager.gd")
	if not gm_script:
		print("ERROR: Could not load GameManager")
		quit(1)
		return

	_game_manager = gm_script.new()
	_game_manager.name = "GameManager"
	get_root().add_child(_game_manager)

	# Load GUT
	var gut_script: GDScript = load("res://addons/gut/gut.gd")
	if not gut_script:
		print("ERROR: Could not load GUT framework")
		quit(1)
		return

	_gut = gut_script.new()
	get_root().add_child(_gut)

	# Configure GUT - use properties directly
	_gut.log_level = 2  # LOG_LEVEL_ALL_ASSERTS
	_gut.include_subdirectories = true

	# Add test directories
	_gut.add_directory("res://tests/unit/", "test_", ".gd")
	_gut.add_directory("res://tests/integration/", "test_", ".gd")
	_gut.add_directory("res://tests/property/", "test_", ".gd")

	# Connect to completion signal
	_gut.end_run.connect(_on_tests_finished)


func _process(_delta: float) -> bool:
	# Run tests on first frame after initialization
	if _gut and not _gut.is_running():
		_gut.test_scripts()
	return false


func _on_tests_finished() -> void:
	var summary: Variant = _gut.get_summary()
	var totals: Variant = summary.get_totals()

	var failed_count: int = totals.failing
	var passed_count: int = totals.passing
	var total_count: int = totals.tests

	print("\n" + "=".repeat(70))
	print("  TEST RESULTS")
	print("=".repeat(70))
	print("  Total:  %d" % total_count)
	print("  Passed: %d" % passed_count)
	print("  Failed: %d" % failed_count)
	print("=".repeat(70) + "\n")

	# Exit with error code if tests failed
	if failed_count > 0:
		print("✗ FAILURE: Some tests failed")
		quit(1)
	else:
		print("✓ SUCCESS: All tests passed")
		quit(0)
