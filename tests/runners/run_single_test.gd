#!/usr/bin/env -S godot --headless --script
# Single Test Runner - for debugging specific test files
extends SceneTree

var _gut: Node = null
var _test_path: String = ""


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()

	# Find test path argument
	for i: int in range(args.size()):
		if args[i] == "--test" and i + 1 < args.size():
			_test_path = args[i + 1]
			break

	if _test_path.is_empty():
		print("Usage: godot --headless --script run_single_test.gd -- --test <test_path>")
		quit(1)
		return

	print("Running test: ", _test_path)

	# Load GUT
	var gut_script: GDScript = load("res://addons/gut/gut.gd")
	if not gut_script:
		print("ERROR: Could not load GUT framework")
		quit(1)
		return

	_gut = gut_script.new()
	get_root().add_child(_gut)

	# Configure GUT
	_gut.log_level = 2  # LOG_LEVEL_ALL_ASSERTS

	# Add single test file
	_gut.add_script(_test_path)

	# Connect to completion signal
	_gut.end_run.connect(_on_tests_finished)

	# Run tests
	_gut.test_scripts()


func _on_tests_finished() -> void:
	var summary: Variant = _gut.get_summary()
	var totals: Variant = summary.get_totals()

	var failed_count: int = totals.failing
	var passed_count: int = totals.passing
	var total_count: int = totals.tests

	print("\nResults: %d/%d passed" % [passed_count, total_count])

	if failed_count > 0:
		quit(1)
	else:
		quit(0)
