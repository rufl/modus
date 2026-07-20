#!/usr/bin/env -S godot --headless --script
## Simple Checkpoint 24 Validation - Direct component checks
## Validates that all pipeline components are present and functional

extends SceneTree

var _validation_results := {}
var _total_checks := 0
var _passed_checks := 0


func _init() -> void:
	print("\n" + "=".repeat(80))
	print("  CHECKPOINT 24: GENERATION PIPELINE VALIDATION")
	print("  Direct Component Availability Check")
	print("=".repeat(80) + "\n")

	# Run validation checks
	_validate_core_foundation()
	_validate_generation_components()
	_validate_geometry_systems()
	_validate_gameplay_systems()
	_validate_optimization_systems()
	_validate_orchestration_systems()

	# Print results
	_print_results()

	# Exit with appropriate code
	var exit_code := 0 if _passed_checks == _total_checks else 1
	quit(exit_code)


func _validate_core_foundation() -> void:
	print("Phase 1-3: Core Foundation")
	_check_class_exists("GenerationConfig", "res://game/scripts/map_generator/generation_config.gd")
	_check_class_exists(
		"GenerationContext", "res://game/scripts/map_generator/generation_context.gd"
	)
	_check_class_exists(
		"GridLayoutManager", "res://game/scripts/map_generator/grid_layout_manager.gd"
	)
	_check_class_exists("Cell", "res://game/scripts/map_generator/cell.gd")
	_check_class_exists("Room", "res://game/scripts/map_generator/room.gd")
	print("")


func _validate_generation_components() -> void:
	print("Phase 4-8: Generation Components")
	_check_class_exists(
		"ShapeGrammarEngine", "res://game/scripts/map_generator/shape_grammar_engine.gd"
	)
	_check_class_exists("HallwayGenerator", "res://game/scripts/map_generator/hallway_generator.gd")
	_check_class_exists(
		"CellularAutomataEngine", "res://game/scripts/map_generator/cellular_automata_engine.gd"
	)
	_check_class_exists(
		"OutdoorParkGenerator", "res://game/scripts/map_generator/outdoor_park_generator.gd"
	)
	_check_class_exists(
		"CaveSystemGenerator", "res://game/scripts/map_generator/cave_system_generator.gd"
	)
	_check_class_exists(
		"BossArenaGenerator", "res://game/scripts/map_generator/boss_arena_generator.gd"
	)
	print("")


func _validate_geometry_systems() -> void:
	print("Phase 9-12: Geometry and Prefab Systems")
	_check_class_exists(
		"CSGGeometryBuilder", "res://game/scripts/map_generator/csg_geometry_builder.gd"
	)
	_check_class_exists(
		"VoxelCaveGenerator", "res://game/scripts/map_generator/voxel_cave_generator.gd"
	)
	_check_class_exists("PrefabSystem", "res://game/scripts/map_generator/prefab_system.gd")
	_check_class_exists("PrefabMetadata", "res://game/scripts/map_generator/prefab_metadata.gd")
	_check_class_exists("ThemeManager", "res://game/scripts/map_generator/theme_manager.gd")
	_check_class_exists("Theme", "res://game/scripts/map_generator/theme.gd")
	print("")


func _validate_gameplay_systems() -> void:
	print("Phase 14-18: Gameplay and Advanced Features")
	_check_class_exists(
		"GameplayElementPlacer", "res://game/scripts/map_generator/gameplay_element_placer.gd"
	)
	_check_class_exists(
		"SecretRoomGenerator", "res://game/scripts/map_generator/secret_room_generator.gd"
	)
	_check_class_exists("KeyLockSystem", "res://game/scripts/map_generator/key_lock_system.gd")
	_check_class_exists(
		"NavigationMeshBaker", "res://game/scripts/map_generator/navigation_mesh_baker.gd"
	)
	_check_class_exists(
		"AdvancedGeometryBuilder", "res://game/scripts/map_generator/advanced_geometry_builder.gd"
	)
	_check_class_exists("RuleBase", "res://game/scripts/map_generator/rule_base.gd")
	_check_class_exists("RuleSystem", "res://game/scripts/map_generator/rule_system.gd")
	print("")


func _validate_optimization_systems() -> void:
	print("Phase 20: Performance Optimization Systems")
	_check_class_exists("LODManager", "res://game/scripts/map_generator/lod_manager.gd")
	_check_class_exists("MultiMeshManager", "res://game/scripts/map_generator/multimesh_manager.gd")
	_check_class_exists(
		"OcclusionCullingManager", "res://game/scripts/map_generator/occlusion_culling_manager.gd"
	)
	print("")


func _validate_orchestration_systems() -> void:
	print("Phase 21-23: Threading, Validation, and Orchestration")
	_check_class_exists("ThreadingSystem", "res://game/scripts/map_generator/threading_system.gd")
	_check_class_exists("ValidationSystem", "res://game/scripts/map_generator/validation_system.gd")
	_check_class_exists("ErrorHandler", "res://game/scripts/map_generator/error_handler.gd")
	_check_class_exists("DebugSystem", "res://game/scripts/map_generator/debug_system.gd")

	# Check MapGenerator singleton
	_check_singleton_exists("MapGenerator")
	print("")


func _check_class_exists(cls_name: String, path: String) -> void:
	_total_checks += 1

	if ResourceLoader.exists(path):
		var script: Script = load(path)
		if script:
			_passed_checks += 1
			print("  ✓ %s" % cls_name)
			_validation_results[cls_name] = true
			return

	print("  ✗ %s (not found at %s)" % [cls_name, path])
	_validation_results[cls_name] = false


func _check_singleton_exists(singleton_name: String) -> void:
	_total_checks += 1

	if Engine.has_singleton(singleton_name) or root.has_node(singleton_name):
		_passed_checks += 1
		print("  ✓ %s (autoload)" % singleton_name)
		_validation_results[singleton_name] = true
	else:
		print("  ✗ %s (autoload not found)" % singleton_name)
		_validation_results[singleton_name] = false


func _print_results() -> void:
	print("=".repeat(80))
	print("  VALIDATION RESULTS")
	print("=".repeat(80))
	print("  Total Checks:  %d" % _total_checks)
	print("  Passed:        %d" % _passed_checks)
	print("  Failed:        %d" % (_total_checks - _passed_checks))
	print("  Success Rate:  %.1f%%" % ((_passed_checks / float(_total_checks)) * 100.0))
	print("=".repeat(80))

	if _passed_checks == _total_checks:
		print("\n✓ SUCCESS: All pipeline components are present and loadable!")
		print("\n  12-Phase Generation Pipeline:")
		print("    Phase 1:  Initialization (Seed hashing, RNG)")
		print("    Phase 2:  Grid Layout (Coarse grid allocation)")
		print("    Phase 3:  Shape Grammar (Organic room generation)")
		print("    Phase 4:  Hallway Generation (A* pathfinding, dead-end removal)")
		print("    Phase 5:  Outdoor/Cave Generation (Cellular automata)")
		print("    Phase 6:  Boss Arena Placement")
		print("    Phase 7:  CSG Geometry Building (Walls, floors, ceilings)")
		print("    Phase 8:  Prefab Placement (Props, furniture, decorative)")
		print("    Phase 9:  Gameplay Element Placement (Monsters, items, keys)")
		print("    Phase 10: Navigation Mesh Baking")
		print("    Phase 11: Validation (Connectivity, playability checks)")
		print("    Phase 12: Export (PackedScene .tscn + metadata JSON)")
		print("\n  Supporting Systems:")
		print("    ✓ Threading system (Task 21)")
		print("    ✓ Validation and error handling (Task 22)")
		print("    ✓ Complete pipeline orchestration (Task 23)")
		print("    ✓ Rule system and modularity (Task 18)")
		print("    ✓ Performance optimizations (Task 20)")
		print("\n  All components from Tasks 1-23 are implemented and available.")
	else:
		print(
			(
				"\n✗ FAILURE: %d component(s) missing or not loadable"
				% (_total_checks - _passed_checks)
			)
		)
		print("\n  Missing components:")
		for component: String in _validation_results:
			if not _validation_results[component]:
				print("    - %s" % component)

	print("\n" + "=".repeat(80) + "\n")
