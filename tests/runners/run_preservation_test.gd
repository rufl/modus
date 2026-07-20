#!/usr/bin/env -S godot --headless --script
# Preservation Test Runner - for test compilation fix preservation testing
extends SceneTree

var _gut: Node = null


func _init() -> void:
	print("Running preservation property test...")
	
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
	_gut.include_subdirectories = false
	
	# Add preservation test file
	_gut.add_script("res://tests/property/test_compilation_preservation_pbt.gd")
	
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
	print("  PRESERVATION TEST RESULTS")
	print("  Tests: %d/%d passed" % [passed_count, total_count])
	if failed_count > 0:
		print("  Status: FAILED - %d test(s) failed" % failed_count)
	else:
		print("  Status: PASSED - All preservation properties verified")
	print("=".repeat(70))
	
	if failed_count > 0:
		quit(1)
	else:
		quit(0)
