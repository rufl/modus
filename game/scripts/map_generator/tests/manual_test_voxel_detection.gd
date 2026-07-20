extends Node

## Manual test for Voxel Tools detection
## Run this scene to check if Voxel Tools addon is available

const VoxelCaveGenerator = preload("res://game/scripts/map_generator/voxel_cave_generator.gd")
const CaveSystemGenerator = preload("res://game/scripts/map_generator/cave_system_generator.gd")


func _ready() -> void:
	print("\n=== Voxel Tools Detection Test ===\n")

	# Test 1: Static detection method
	print("Test 1: VoxelCaveGenerator.is_voxel_tools_available()")
	var is_available := VoxelCaveGenerator.is_voxel_tools_available()
	print("  Result: %s" % ("AVAILABLE" if is_available else "NOT AVAILABLE"))

	# Test 2: ClassDB detection
	print("\nTest 2: ClassDB.class_exists('VoxelTerrain')")
	var has_voxel_terrain := ClassDB.class_exists("VoxelTerrain")
	print("  Result: %s" % has_voxel_terrain)

	# Test 3: ResourceLoader detection
	print("\nTest 3: ResourceLoader.exists('res://addons/voxel/voxel_terrain.gd')")
	var has_voxel_script := ResourceLoader.exists("res://addons/voxel/voxel_terrain.gd")
	print("  Result: %s" % has_voxel_script)

	# Test 4: CaveSystemGenerator initialization
	print("\nTest 4: CaveSystemGenerator initialization")
	var cave_gen := CaveSystemGenerator.new()
	var uses_voxel := cave_gen.is_using_voxel_tools()
	print("  Using voxel tools: %s" % uses_voxel)
	print("  Should match Test 1: %s" % ("PASS" if uses_voxel == is_available else "FAIL"))

	# Test 5: List available classes (for debugging)
	print("\nTest 5: Searching for Voxel-related classes")
	var all_classes := ClassDB.get_class_list()
	var voxel_classes: Array[String] = []
	for cls in all_classes:
		if "Voxel" in cls or "voxel" in cls:
			voxel_classes.append(cls)

	if voxel_classes.size() > 0:
		print("  Found %d voxel-related classes:" % voxel_classes.size())
		for voxel_class in voxel_classes:
			print("    - %s" % voxel_class)
	else:
		print("  No voxel-related classes found")

	print("\n=== Test Complete ===\n")

	# Quit immediately
	get_tree().quit()
