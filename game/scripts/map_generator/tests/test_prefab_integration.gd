extends Node

## Simple integration test for PrefabSystem
## Run this script to verify the prefab system works correctly

const PrefabMetadata = preload("res://game/scripts/map_generator/prefab_metadata.gd")
const MapPrefabSystem = preload("res://game/scripts/map_generator/prefab_system.gd")


func _ready() -> void:
	print("=== PrefabSystem Integration Test ===")

	# Test 1: Create and parse metadata
	print("\n[Test 1] Creating and parsing metadata...")
	var test_data := {
		"dimensions": [2.0, 3.0, 2.0],
		"anchor_points": [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
		"required_theme": "tech",
		"density_weight": 1.5,
		"tags": ["prop", "cover"],
		"collision_radius": 0.75,
		"placement_rules": {"min_distance_from_walls": 0.5}
	}

	var metadata := PrefabMetadata.from_dict(test_data)
	if metadata:
		print("✓ Metadata parsed successfully")
		print("  - Dimensions: ", metadata.dimensions)
		print("  - MapTheme: ", metadata.required_theme)
		print("  - Tags: ", metadata.tags)
	else:
		print("✗ Failed to parse metadata")

	# Test 2: Round-trip conversion
	print("\n[Test 2] Testing round-trip conversion...")
	if metadata:
		var exported := metadata.to_dict()
		var metadata2 := PrefabMetadata.from_dict(exported)
		if metadata2:
			print("✓ Round-trip successful")
			print("  - Dimensions match: ", metadata2.dimensions == metadata.dimensions)
			print("  - MapTheme match: ", metadata2.required_theme == metadata.required_theme)
		else:
			print("✗ Round-trip failed")

	# Test 3: JSON export
	print("\n[Test 3] Testing JSON export...")
	if metadata:
		var json_str := metadata.to_json_string()
		print("✓ JSON export successful")
		print("  - Length: ", json_str.length(), " characters")

	# Test 4: Create PrefabSystem
	print("\n[Test 4] Creating MapPrefabSystem...")
	var prefab_system := MapPrefabSystem.new()
	if prefab_system:
		print("✓ MapPrefabSystem created successfully")

		# Test 5: Check initial state
		print("\n[Test 5] Checking initial state...")
		var stats := prefab_system.get_statistics()
		print("✓ Statistics retrieved")
		print("  - Total prefabs: ", stats["total_prefabs"])
		print("  - Themes: ", stats["by_theme"].keys().size())

		# Test 6: Try loading prefabs (will be empty if no prefabs exist)
		print("\n[Test 6] Attempting to load prefabs...")
		var loaded := prefab_system.load_all_prefabs()
		print("  - Loaded ", loaded, " prefabs")
		if loaded > 0:
			print("✓ Prefabs loaded successfully")
			var final_stats := prefab_system.get_statistics()
			print("  - Total prefabs: ", final_stats["total_prefabs"])
			print("  - Categories: ", final_stats["by_category"])
		else:
			print(
				(
					"  (No prefab files found - "
					+ "this is expected if prefabs haven't been created yet)"
				)
			)
	else:
		print("✗ Failed to create MapPrefabSystem")

	print("\n=== Integration Test Complete ===")
	get_tree().quit()
