#!/usr/bin/env -S godot --headless --script
# Simple test runner for map generator tests
extends SceneTree


func _init():
	var gut = load("res://addons/gut/gut.gd").new()

	# Configure GUT
	gut.set_log_level(gut.LOG_LEVEL_ALL_ASSERTS)
	gut.set_should_exit(true)
	gut.set_include_subdirectories(true)

	# Add specific test file
	gut.add_script("res://tests/unit/test_map_generator_seed_rng.gd")

	# Add to scene tree
	get_root().add_child(gut)

	# Connect completion signal
	if gut.has_signal("tests_finished"):
		gut.tests_finished.connect(_on_tests_finished)

	# Run tests
	print("Running map generator seed/RNG tests...")
	gut.test_scripts(true)


func _on_tests_finished():
	print("Tests completed")
	quit()
