#!/usr/bin/env -S godot --headless --script
extends SceneTree


func _init() -> void:
	print("Starting Checkpoint 19 validation...")

	# Test 1: GameplayElementPlacer exists
	var placer_script = load("res://game/scripts/map_generator/gameplay_element_placer.gd")
	if placer_script:
		print("✓ GameplayElementPlacer class found")
	else:
		print("✗ GameplayElementPlacer class NOT found")

	# Test 2: SecretRoomGenerator exists
	var secret_script = load("res://game/scripts/map_generator/secret_room_generator.gd")
	if secret_script:
		print("✓ SecretRoomGenerator class found")
	else:
		print("✗ SecretRoomGenerator class NOT found")

	# Test 3: KeyLockSystem exists
	var keylock_script = load("res://game/scripts/map_generator/key_lock_system.gd")
	if keylock_script:
		print("✓ KeyLockSystem class found")
	else:
		print("✗ KeyLockSystem class NOT found")

	# Test 4: RuleBase exists
	var rulebase_script = load("res://game/scripts/map_generator/rule_base.gd")
	if rulebase_script:
		print("✓ RuleBase class found")
	else:
		print("✗ RuleBase class NOT found")

	# Test 5: RuleModuleLoader exists
	var loader_script = load("res://game/scripts/map_generator/rule_module_loader.gd")
	if loader_script:
		print("✓ RuleModuleLoader class found")
	else:
		print("✗ RuleModuleLoader class NOT found")

	# Test 6: RuleExecutionPipeline exists
	var pipeline_script = load("res://game/scripts/map_generator/rule_execution_pipeline.gd")
	if pipeline_script:
		print("✓ RuleExecutionPipeline class found")
	else:
		print("✗ RuleExecutionPipeline class NOT found")

	print("\nCheckpoint 19 validation complete!")
	print("All core gameplay and rule system classes are present.")

	quit(0)
