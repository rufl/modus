#!/usr/bin/env -S godot --headless --script
## Dedicated Ragdoll Test Runner - Runs only ragdoll physics tests
## Uses GUT framework directly without loading broken tests
extends SceneTree

var _gut: Node = null


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  RAGDOLL PHYSICS TEST SUITE")
	print("  Running via GUT Framework")
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

	# Add ONLY ragdoll test files directly
	_gut.add_script("res://tests/property/test_ragdoll_physics_bug_exploration_pbt.gd")
	_gut.add_script("res://tests/property/test_ragdoll_preservation_pbt.gd")

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
	var pending_count: int = totals.pending

	print("\n" + "=".repeat(70))
	print("  RAGDOLL TEST RESULTS")
	print("=".repeat(70))
	print("  Total:   %d" % total_count)
	print("  Passed:  %d" % passed_count)
	print("  Failed:  %d" % failed_count)
	print("  Pending: %d" % pending_count)
	print("=".repeat(70) + "\n")

	# Print failed test details
	if failed_count > 0:
		print("FAILED TESTS:")
		var all_tests: Array = _gut.get_test_list()
		for test: Dictionary in all_tests:
			if test.status == "fail":
				print("  - %s" % test.name)
				if test.reason:
					print("    Reason: %s" % test.reason)
		print("")

	# Exit with error code if tests failed
	if failed_count > 0:
		print("RESULT: FAILURE - %d tests failed" % failed_count)
		quit(1)
	else:
		print("RESULT: SUCCESS - All tests passed!")
		quit(0)