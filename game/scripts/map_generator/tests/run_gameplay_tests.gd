#!/usr/bin/env -S godot --headless --script
## Test runner for Gameplay Element Placer tests
## Usage: godot --headless --script game/scripts/map_generator/tests/run_gameplay_tests.gd

extends SceneTree

var _gut = null


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  GAMEPLAY ELEMENT PLACER TEST SUITE")
	print("=".repeat(70) + "\n")

	# Load GUT
	var gut_script = load("res://addons/gut/gut.gd")
	if not gut_script:
		print("ERROR: Could not load GUT framework")
		quit(1)
		return

	_gut = gut_script.new()
	get_root().add_child(_gut)

	# Configure GUT
	_gut.set_yield_between_tests(true)
	_gut.set_double_strategy(_gut.DOUBLE_STRATEGY.SCRIPT_ONLY)
	_gut.set_include_subdirectories(false)

	# Add test file
	_gut.add_script("res://game/scripts/map_generator/tests/test_gameplay_element_placer.gd")

	# Connect signals
	_gut.tests_finished.connect(_on_tests_finished)

	# Run tests
	_gut.test_scripts()


func _on_tests_finished() -> void:
	var summary = _gut.get_summary()

	print("\n" + "=".repeat(70))
	print("  TEST RESULTS")
	print("=".repeat(70))
	print("  Total Tests:  %d" % summary.get_totals().tests)
	print("  Passed:       %d" % summary.get_totals().passing)
	print("  Failed:       %d" % summary.get_totals().failing)
	print("  Pending:      %d" % summary.get_totals().pending)
	print("  Warnings:     %d" % summary.get_totals().warnings)
	print("=".repeat(70) + "\n")

	var exit_code = 0 if summary.get_totals().failing == 0 else 1

	if exit_code == 0:
		print("✓ All tests passed! Gameplay element placement validated.")
	else:
		print("✗ Some tests failed. Please review the output above.")

	quit(exit_code)
