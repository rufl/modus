#!/usr/bin/env -S godot --headless --script
# GUT Test Runner for Unit Tests Only (excludes benchmarks)
# Usage: godot --headless --script run_unit_tests_only.gd

extends SceneTree


func _init():
	# Configure GUT for unit tests only
	var gut = load("res://addons/gut/gut.gd").new()

	# Set up GUT configuration
	gut.set_yield_between_tests(true)
	gut.set_export_path("user://unit_tests_results.xml")
	gut.set_include_subdirectories(true)
	gut.set_log_level(gut.LOG_LEVEL_FAIL_ONLY)
	gut.set_should_exit_on_success(false)
	gut.set_should_exit(true)

	# Add test directories but exclude benchmark tests
	gut.add_directory("res://tests/")

	# Set test patterns - exclude benchmark tests
	gut.set_test_prefix("test_")
	gut.set_test_suffix(".gd")

	# Exclude benchmark test files
	gut.add_script_with_path("res://tests/test_autoloads.gd")
	gut.add_script_with_path("res://tests/test_config_manager.gd")
	gut.add_script_with_path("res://tests/test_event_bus.gd")
	gut.add_script_with_path("res://tests/test_game_database.gd")
	gut.add_script_with_path("res://tests/test_network_manager.gd")
	gut.add_script_with_path("res://tests/test_effects.gd")
	gut.add_script_with_path("res://tests/test_ui_system.gd")
	gut.add_script_with_path("res://tests/test_weapons.gd")
	gut.add_script_with_path("res://tests/test_animation_system.gd")
	gut.add_script_with_path("res://tests/test_modding.gd")
	gut.add_script_with_path("res://tests/test_conversion_validation_pbt.gd")

	# Explicitly exclude benchmark tests
	# Note: GUT doesn't have direct exclusion, so we use selective inclusion

	# Add to scene tree and run
	get_root().add_child(gut)
	gut.test_scripts_run_complete.connect(_on_tests_complete)

	print("Running unit tests only (excluding benchmarks)...")
	gut.test_scripts()


func _on_tests_complete():
	print("Unit tests completed")
	quit()
