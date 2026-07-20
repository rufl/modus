#!/usr/bin/env -S godot --headless --script
# Performance Benchmark Runner
extends SceneTree

var _gut: Node = null


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  MODUS PERFORMANCE BENCHMARKS")
	print("=".repeat(70) + "\n")

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

	# Add performance benchmark tests
	_gut.add_directory("res://tests/benchmarks/", "test_", ".gd")

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

	print("\n" + "=".repeat(70))
	print("  BENCHMARK RESULTS")
	print("=".repeat(70))
	print("  Total:  %d" % total_count)
	print("  Passed: %d" % passed_count)
	print("  Failed: %d" % failed_count)
	print("=".repeat(70) + "\n")

	# Exit with error code if tests failed
	if failed_count > 0:
		print("✗ FAILURE: Some benchmarks failed")
		quit(1)
	else:
		print("✓ SUCCESS: All benchmarks passed")
		quit(0)
