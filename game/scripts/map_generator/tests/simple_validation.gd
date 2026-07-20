#!/usr/bin/env -S godot --headless --script
## Simple validation for Checkpoint 13
## Tests core functionality without full game initialization

extends SceneTree


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  CHECKPOINT 13 - SIMPLE VALIDATION")
	print("=".repeat(70) + "\n")

	var all_passed := true

	# Test 1: CSG Geometry Builder
	print("Testing CSG Geometry Builder...")
	var builder = CSGGeometryBuilder.new()
	if builder:
		print("  ✓ CSGGeometryBuilder instantiated")
	else:
		print("  ✗ Failed to instantiate CSGGeometryBuilder")
		all_passed = false

	# Test 2: Prefab System
	print("\nTesting Prefab System...")
	var prefab_system := MapPrefabSystem.new()
	if prefab_system:
		print("  ✓ MapPrefabSystem instantiated")
		var count := prefab_system.get_prefab_count(GenerationConfig.ThemeType.TECH)
		print("  ✓ Cache initialized (count: %d)" % count)
	else:
		print("  ✗ Failed to instantiate MapPrefabSystem")
		all_passed = false

	# Test 3: Theme Manager
	print("\nTesting Theme Manager...")
	var theme_manager := ThemeManager.new()
	if theme_manager:
		print("  ✓ ThemeManager instantiated")
		var has_tech := theme_manager.has_theme(GenerationConfig.ThemeType.TECH)
		var has_hell := theme_manager.has_theme(GenerationConfig.ThemeType.HELL)
		var has_urban := theme_manager.has_theme(GenerationConfig.ThemeType.URBAN)
		var has_cave := theme_manager.has_theme(GenerationConfig.ThemeType.CAVE)
		var has_jumbled := theme_manager.has_theme(GenerationConfig.ThemeType.JUMBLED)

		if has_tech and has_hell and has_urban and has_cave and has_jumbled:
			print("  ✓ All 5 themes loaded")
		else:
			print("  ✗ Not all themes loaded")
			all_passed = false
	else:
		print("  ✗ Failed to instantiate ThemeManager")
		all_passed = false

	# Test 4: Prefab Metadata
	print("\nTesting Prefab Metadata...")
	var metadata_path := "res://game/data/map_generator/prefabs/tech/test_crate.json"
	if FileAccess.file_exists(metadata_path):
		var metadata := PrefabMetadata.from_file(metadata_path)
		if metadata and metadata.is_valid():
			print("  ✓ Test prefab metadata parsed and valid")
		else:
			print("  ✗ Failed to parse or validate metadata")
			all_passed = false
	else:
		print("  ✗ Test prefab not found")
		all_passed = false

	# Test 5: Integration
	print("\nTesting Integration...")
	var config := GenerationConfig.new()
	config.theme = GenerationConfig.ThemeType.TECH

	var context := GenerationContext.new()
	context.config = config

	theme_manager.set_theme(config.theme)
	builder.initialize(context)

	if context.theme and context.csg_root:
		print("  ✓ Theme and CSG root set in context")
	else:
		print("  ✗ Integration failed")
		all_passed = false

	# Summary
	print("\n" + "=".repeat(70))
	if all_passed:
		print("  ✅ ALL TESTS PASSED - Checkpoint 13 validated")
	else:
		print("  ❌ SOME TESTS FAILED - Review output above")
	print("=".repeat(70) + "\n")

	quit(0 if all_passed else 1)
