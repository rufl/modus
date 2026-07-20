#!/usr/bin/env -S godot --headless --script
## Quick validation for Checkpoint 24 - Core pipeline components only

extends SceneTree

var _gut = null
var _test_files := [
	# Core foundation
	"res://tests/unit/test_map_generator_seed_rng.gd",
	"res://tests/unit/test_grid_layout_manager.gd",
	# Key generation components
	"res://tests/unit/map_generator/test_shape_grammar_engine.gd",
	"res://tests/unit/map_generator/test_hallway_generation.gd",
	"res://tests/unit/map_generator/test_cellular_automata_engine.gd",
	# Integration tests
	"res://game/scripts/map_generator/tests/test_csg_geometry_builder.gd",
	"res://game/scripts/map_generator/tests/test_prefab_system.gd",
	# Threading and orchestration
	"res://tests/unit/test_map_generator_threading.gd",
]


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  CHECKPOINT 24: Quick Pipeline Validation")
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

	# Add test files
	for test_file in _test_files:
		if ResourceLoader.exists(test_file):
			_gut.add_script(test_file)
		else:
			print("  WARNING: Skipping %s" % test_file)

	# Connect signals
	_gut.tests_finished.connect(_on_tests_finished)

	# Run tests
	_gut.test_scripts()


func _on_tests_finished() -> void:
	var summary = _gut.get_summary()

	print("\n" + "=".repeat(70))
	print("  RESULTS")
	print("=".repeat(70))
	print("  Tests:   %d" % summary.get_totals().tests)
	print("  Passed:  %d" % summary.get_totals().passing)
	print("  Failed:  %d" % summary.get_totals().failing)
	print("=".repeat(70) + "\n")

	var exit_code := 0 if summary.get_totals().failing == 0 else 1
	quit(exit_code)
