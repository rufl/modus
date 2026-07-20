#!/usr/bin/env -S godot --headless --script
# Simple Test Runner for MODUS Framework
# Usage: godot --headless --script tests/runners/run_gut_tests.gd

extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _total: int = 0
var _frame_count: int = 0


func _init() -> void:
	print("\n" + "=".repeat(60))
	print("  MODUS TEST RUNNER")
	print("=".repeat(60) + "\n")


func _process(_delta: float) -> bool:
	_frame_count += 1

	# Wait 5 frames for autoloads to initialize
	if _frame_count < 5:
		return false

	if _frame_count == 5:
		_run_all_tests()

		print("\n" + "=".repeat(60))
		print("  RESULTS: %d passed, %d failed, %d total" % [_passed, _failed, _total])
		print("=".repeat(60) + "\n")

		quit(0 if _failed == 0 else 1)

	return false


func _run_all_tests() -> void:
	var test_dir: String = "res://tests/"
	var dir: DirAccess = DirAccess.open(test_dir)

	if not dir:
		print("ERROR: Cannot open tests directory")
		_failed += 1
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			# Skip utility files
			if not file_name in ["test_base.gd", "simple_test_base.gd"]:
				_run_test_file(test_dir + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()


func _run_test_file(path: String) -> void:
	print("\n--- Running: %s ---" % path.get_file())

	var script: Script = load(path)
	if not script:
		print("  ERROR: Failed to load script")
		_failed += 1
		_total += 1
		return

	var instance: Node = script.new()

	# Add to scene tree so it can access autoloads
	get_root().add_child(instance)

	# Find all test_ methods
	var methods: Array[Dictionary] = instance.get_method_list()
	for method: Dictionary in methods:
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			_run_test_method(instance, method_name)

	# Clean up
	instance.queue_free()


func _run_test_method(instance: Node, method_name: String) -> void:
	_total += 1

	# Simple test execution without complex async handling
	var result: Dictionary = {"passed": true, "error": ""}

	# Run the test
	if instance.has_method(method_name):
		var test_result: Variant = instance.call(method_name)

		# Handle different return types
		if test_result is Dictionary:
			result = test_result
		elif test_result == false:
			result.passed = false
			result.error = "Test returned false"
		elif test_result == null:
			# For assertion-based tests, check if test passed
			if instance.has_method("_get_test_result"):
				result = instance.call("_get_test_result")
			else:
				result.passed = true

	# Validate result structure
	if not result.has("passed"):
		result.passed = false
		result.error = "Test returned invalid Dictionary (missing 'passed' key)"

	if result.passed:
		print("  ✓ %s" % method_name)
		_passed += 1
	else:
		var err_msg: String = str(result.get("error", "Unknown Error"))
		print("  ✗ %s - %s" % [method_name, err_msg])
		_failed += 1
