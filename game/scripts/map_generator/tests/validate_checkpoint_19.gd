#!/usr/bin/env -S godot --headless --script
## Checkpoint 19 Validation: Gameplay Systems and Rules
## Validates Task 14 (Gameplay Element Placement) and Task 18 (Rule System)
## Usage: godot --headless --script game/scripts/map_generator/tests/validate_checkpoint_19.gd

extends SceneTree

# Component classes
const GameplayElementPlacer = preload("res://game/scripts/map_generator/gameplay_element_placer.gd")
const SecretRoomGenerator = preload("res://game/scripts/map_generator/secret_room_generator.gd")
const KeyLockSystem = preload("res://game/scripts/map_generator/key_lock_system.gd")
const RuleBase = preload("res://game/scripts/map_generator/rule_base.gd")
const RuleModuleLoader = preload("res://game/scripts/map_generator/rule_module_loader.gd")
const RuleExecutionPipeline = preload("res://game/scripts/map_generator/rule_execution_pipeline.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const GridLayoutManager = preload("res://game/scripts/map_generator/grid_layout_manager.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var test_count := 0
var passed_count := 0
var failed_count := 0


func _init() -> void:
	print("\n" + "=".repeat(80))
	print("  CHECKPOINT 19 VALIDATION: Gameplay Systems and Rules")
	print("  Task 14: Gameplay Element Placement")
	print("  Task 15: Secret Rooms and Key-Lock Systems")
	print("  Task 18: Modular Rule System")
	print("=".repeat(80) + "\n")

	run_all_validations()

	print("\n" + "=".repeat(80))
	print("  VALIDATION RESULTS")
	print("=".repeat(80))
	print("  Total Tests:  %d" % test_count)
	print("  Passed:       %d" % passed_count)
	print("  Failed:       %d" % failed_count)
	print(
		(
			"  Success Rate: %.1f%%"
			% ((passed_count / float(test_count)) * 100.0 if test_count > 0 else 0.0)
		)
	)
	print("=".repeat(80) + "\n")

	if failed_count == 0:
		print("✓ CHECKPOINT 19 PASSED - All gameplay systems and rules validated!")
		quit(0)
	else:
		print("✗ CHECKPOINT 19 FAILED - %d validation(s) failed" % failed_count)
		quit(1)


func run_all_validations() -> void:
	print("=".repeat(80))
	print("TASK 14: Gameplay Element Placement Systems")
	print("=".repeat(80) + "\n")

	validate_gameplay_element_placer_exists()
	validate_gameplay_element_placer_methods()
	validate_monster_placement_logic()
	validate_item_placement_logic()

	print("\n" + "=".repeat(80))
	print("TASK 15: Secret Room and Key-Lock Systems")
	print("=".repeat(80) + "\n")

	validate_secret_room_generator_exists()
	validate_key_lock_system_exists()
	validate_secret_room_methods()
	validate_key_lock_methods()

	print("\n" + "=".repeat(80))
	print("TASK 18: Modular Rule System")
	print("=".repeat(80) + "\n")

	validate_rule_base_interface()
	validate_rule_module_loader()
	validate_rule_execution_pipeline()
	validate_rule_loading()
	validate_rule_execution()


## ============================================================================
## TASK 14 VALIDATIONS: Gameplay Element Placement
## ============================================================================


func validate_gameplay_element_placer_exists() -> void:
	test_count += 1
	print("[14.1] Validating GameplayElementPlacer class exists...")

	var placer := GameplayElementPlacer.new()
	if placer != null:
		print("  ✓ PASS: GameplayElementPlacer instantiated successfully")
		passed_count += 1
		placer.free()
	else:
		print("  ✗ FAIL: Could not instantiate GameplayElementPlacer")
		failed_count += 1


func validate_gameplay_element_placer_methods() -> void:
	test_count += 1
	print("[14.2] Validating GameplayElementPlacer has required methods...")

	var placer := GameplayElementPlacer.new()
	var has_all_methods := true
	var required_methods := [
		"place_monster_spawns",
		"place_boss_monsters",
		"place_weapons_and_ammo",
		"place_health_pickups"
	]

	for method_name in required_methods:
		if not placer.has_method(method_name):
			print("  ✗ Missing method: %s" % method_name)
			has_all_methods = false

	if has_all_methods:
		print("  ✓ PASS: All required methods present")
		passed_count += 1
	else:
		print("  ✗ FAIL: Some required methods missing")
		failed_count += 1

	placer.free()


func validate_monster_placement_logic() -> void:
	test_count += 1
	print("[14.3] Validating monster placement logic...")

	var context := _create_test_context()
	var placer := GameplayElementPlacer.new()

	# Place monsters
	placer.place_monster_spawns(context)

	if context.monster_spawns.size() > 0:
		print("  ✓ PASS: Monster spawns created (%d spawns)" % context.monster_spawns.size())
		passed_count += 1
	else:
		print("  ✗ FAIL: No monster spawns created")
		failed_count += 1

	placer.free()
	context.free()


func validate_item_placement_logic() -> void:
	test_count += 1
	print("[14.4] Validating item placement logic...")

	var context := _create_test_context()
	var placer := GameplayElementPlacer.new()

	# Place items
	placer.place_weapons_and_ammo(context)
	placer.place_health_pickups(context)

	if context.item_spawns.size() > 0:
		print("  ✓ PASS: Item spawns created (%d items)" % context.item_spawns.size())
		passed_count += 1
	else:
		print("  ✗ FAIL: No item spawns created")
		failed_count += 1

	placer.free()
	context.free()


## ============================================================================
## TASK 15 VALIDATIONS: Secret Rooms and Key-Lock Systems
## ============================================================================


func validate_secret_room_generator_exists() -> void:
	test_count += 1
	print("[15.1] Validating SecretRoomGenerator class exists...")

	var generator := SecretRoomGenerator.new()
	if generator != null:
		print("  ✓ PASS: SecretRoomGenerator instantiated successfully")
		passed_count += 1
		generator.free()
	else:
		print("  ✗ FAIL: Could not instantiate SecretRoomGenerator")
		failed_count += 1


func validate_key_lock_system_exists() -> void:
	test_count += 1
	print("[15.2] Validating KeyLockSystem class exists...")

	var system := KeyLockSystem.new()
	if system != null:
		print("  ✓ PASS: KeyLockSystem instantiated successfully")
		passed_count += 1
		system.free()
	else:
		print("  ✗ FAIL: Could not instantiate KeyLockSystem")
		failed_count += 1


func validate_secret_room_methods() -> void:
	test_count += 1
	print("[15.3] Validating SecretRoomGenerator has required methods...")

	var generator := SecretRoomGenerator.new()
	var has_all_methods := true
	var required_methods := ["generate_secret_rooms", "place_secret_items"]

	for method_name in required_methods:
		if not generator.has_method(method_name):
			print("  ✗ Missing method: %s" % method_name)
			has_all_methods = false

	if has_all_methods:
		print("  ✓ PASS: All required methods present")
		passed_count += 1
	else:
		print("  ✗ FAIL: Some required methods missing")
		failed_count += 1

	generator.free()


func validate_key_lock_methods() -> void:
	test_count += 1
	print("[15.4] Validating KeyLockSystem has required methods...")

	var system := KeyLockSystem.new()
	var has_all_methods := true
	var required_methods := ["generate_key_lock_system", "validate_key_lock_progression"]

	for method_name in required_methods:
		if not system.has_method(method_name):
			print("  ✗ Missing method: %s" % method_name)
			has_all_methods = false

	if has_all_methods:
		print("  ✓ PASS: All required methods present")
		passed_count += 1
	else:
		print("  ✗ FAIL: Some required methods missing")
		failed_count += 1

	system.free()


## ============================================================================
## TASK 18 VALIDATIONS: Modular Rule System
## ============================================================================


func validate_rule_base_interface() -> void:
	test_count += 1
	print("[18.1] Validating RuleBase abstract interface...")

	var rule := RuleBase.new()
	var has_all_methods := true
	var required_methods := ["can_apply", "apply", "get_priority", "get_rule_name", "get_phase"]

	for method_name in required_methods:
		if not rule.has_method(method_name):
			print("  ✗ Missing method: %s" % method_name)
			has_all_methods = false

	if has_all_methods:
		print("  ✓ PASS: RuleBase interface complete")
		passed_count += 1
	else:
		print("  ✗ FAIL: RuleBase interface incomplete")
		failed_count += 1

	rule.free()


func validate_rule_module_loader() -> void:
	test_count += 1
	print("[18.2] Validating RuleModuleLoader functionality...")

	var loader := RuleModuleLoader.new()
	var has_all_methods := true
	var required_methods := ["load_rules", "get_rules_for_phase", "get_all_rules", "get_rule_names"]

	for method_name in required_methods:
		if not loader.has_method(method_name):
			print("  ✗ Missing method: %s" % method_name)
			has_all_methods = false

	if has_all_methods:
		print("  ✓ PASS: RuleModuleLoader interface complete")
		passed_count += 1
	else:
		print("  ✗ FAIL: RuleModuleLoader interface incomplete")
		failed_count += 1

	loader.free()


func validate_rule_execution_pipeline() -> void:
	test_count += 1
	print("[18.3] Validating RuleExecutionPipeline functionality...")

	var loader := RuleModuleLoader.new()
	var pipeline := RuleExecutionPipeline.new(loader)
	var has_all_methods := true
	var required_methods := ["execute_phase", "execute_phases", "get_applied_rules", "reset"]

	for method_name in required_methods:
		if not pipeline.has_method(method_name):
			print("  ✗ Missing method: %s" % method_name)
			has_all_methods = false

	if has_all_methods:
		print("  ✓ PASS: RuleExecutionPipeline interface complete")
		passed_count += 1
	else:
		print("  ✗ FAIL: RuleExecutionPipeline interface incomplete")
		failed_count += 1

	pipeline.free()
	loader.free()


func validate_rule_loading() -> void:
	test_count += 1
	print("[18.4] Validating rule module loading...")

	var loader := RuleModuleLoader.new()
	var success := loader.load_rules()

	if success:
		var all_rules := loader.get_all_rules()
		print("  ✓ PASS: Rules loaded successfully (%d rules)" % all_rules.size())
		passed_count += 1
	else:
		print("  ✗ FAIL: Rule loading failed")
		failed_count += 1

	loader.free()


func validate_rule_execution() -> void:
	test_count += 1
	print("[18.5] Validating rule execution...")

	var loader := RuleModuleLoader.new()
	loader.load_rules()

	var pipeline := RuleExecutionPipeline.new(loader)
	var context := GenerationContext.new()
	var config := GenerationConfig.new()
	config.map_size = Vector2i(64, 64)
	context.config = config
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	var success := pipeline.execute_phase("grid_layout", context)

	if success:
		print("  ✓ PASS: Rule execution successful")
		passed_count += 1
	else:
		print("  ✗ FAIL: Rule execution failed")
		failed_count += 1

	pipeline.free()
	loader.free()
	context.free()


## ============================================================================
## HELPER FUNCTIONS
## ============================================================================


func _create_test_context() -> GenerationContext:
	var context := GenerationContext.new()
	var config := GenerationConfig.new()

	# Set up basic configuration
	config.monster_density = 0.5
	config.item_density = 0.5
	config.difficulty_scaling = GenerationConfig.DifficultyLevel.NORMAL
	config.map_size = Vector2i(64, 64)

	context.config = config
	context.grid_size = Vector2i(64, 64)
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	# Initialize grid
	context.grid_manager = GridLayoutManager.new()
	context.grid_manager.initialize_grid(context.grid_size)
	context.grid = context.grid_manager.grid

	# Create test rooms
	var start_room := Room.new()
	start_room.id = 0
	start_room.center = Vector2i(10, 10)
	start_room.type = Room.RoomType.SMALL
	start_room.cells = _create_room_cells(Vector2i(10, 10), 6)
	context.rooms.append(start_room)

	var mid_room := Room.new()
	mid_room.id = 1
	mid_room.center = Vector2i(30, 30)
	mid_room.type = Room.RoomType.MEDIUM
	mid_room.cells = _create_room_cells(Vector2i(30, 30), 12)
	context.rooms.append(mid_room)

	return context


func _create_room_cells(center: Vector2i, size: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var half_size: int = size / 2

	for dy in range(-half_size, half_size + 1):
		for dx in range(-half_size, half_size + 1):
			cells.append(center + Vector2i(dx, dy))

	return cells
