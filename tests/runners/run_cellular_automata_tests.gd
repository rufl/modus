#!/usr/bin/env -S godot --headless --script
# Test runner for cellular automata engine tests
extends SceneTree


func _init():
	var gut = load("res://addons/gut/gut.gd").new()

	# Configure GUT
	gut.set_log_level(gut.LOG_LEVEL_ALL_ASSERTS)
	gut.set_should_exit(true)
	gut.set_include_subdirectories(false)

	# Add cellular automata test file
	gut.add_script("res://tests/unit/map_generator/test_cellular_automata_engine.gd")

	# Add to scene tree
	get_root().add_child(gut)

	# Connect completion signal
	if gut.has_signal("tests_finished"):
		gut.tests_finished.connect(_on_tests_finished)

	# Run tests
	print("Running cellular automata engine tests...")
	gut.test_scripts(true)


func _on_tests_finished():
	print("Tests completed")
	quit()
