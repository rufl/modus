#!/usr/bin/env -S godot --headless --script
## Test runner for Map Generator tests
## Usage: godot --headless --script game/scripts/map_generator/tests/run_tests.gd

extends SceneTree

var _gut: Node = null
var _test_files := [
	"res://game/scripts/map_generator/tests/test_csg_geometry_builder.gd",
	"res://game/scripts/map_generator/tests/test_prefab_system.gd",
	"res://game/scripts/map_generator/tests/test_theme_manager.gd",
	"res://game/scripts/map_generator/tests/test_prefab_integration.gd",
	"res://game/scripts/map_generator/tests/test_boss_arena_generator.gd",
	"res://game/scripts/map_generator/tests/test_cave_integration.gd",
	"res://game/scripts/map_generator/tests/test_voxel_cave_generator.gd",
	"res://game/scripts/map_generator/tests/test_advanced_geometry.gd"
]


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  MAP GENERATOR TEST SUITE - Checkpoint 13 Validation")
	print("  Testing: CSG Geometry Builder, Prefab System, Theme Manager")
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
	_gut.set_yield_between_tests(true)
	_gut.set_double_strategy(_gut.DOUBLE_STRATEGY.SCRIPT_ONLY)
	_gut.set_include_subdirectories(false)

	# Add test files
	for test_file: String in _test_files:
		_gut.add_script(test_file)

	# Connect signals
	_gut.tests_finished.connect(_on_tests_finished)

	# Run tests
	_gut.test_scripts()


func _on_tests_finished() -> void:
	var summary: Variant = _gut.get_summary()

	print("\n" + "=".repeat(70))
	print("  TEST RESULTS")
	print("=".repeat(70))
	print("  Total Tests:  %d" % summary.get_totals().tests)
	print("  Passed:       %d" % summary.get_totals().passing)
	print("  Failed:       %d" % summary.get_totals().failing)
	print("  Pending:      %d" % summary.get_totals().pending)
	print("  Warnings:     %d" % summary.get_totals().warnings)
	print("=".repeat(70) + "\n")

	var exit_code: int = 0 if summary.get_totals().failing == 0 else 1

	if exit_code == 0:
		print("✓ All tests passed! Geometry and prefab systems validated.")
	else:
		print("✗ Some tests failed. Please review the output above.")

	quit(exit_code)
