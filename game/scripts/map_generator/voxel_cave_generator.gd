class_name VoxelCaveGenerator
extends RefCounted

## Voxel Cave Generator
## Generates organic cave systems using Voxel Tools addon
## Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 5.4, 5.5

const Cell = preload("res://game/scripts/map_generator/cell.gd")


## Check if Voxel Tools addon is available
## Returns: true if the addon is installed and accessible
static func is_voxel_tools_available() -> bool:
	# Check for VoxelTerrain class (core class from Voxel Tools)
	if ClassDB.class_exists("VoxelTerrain"):
		return true

	# Fallback: Check for addon script files
	if ResourceLoader.exists("res://addons/voxel/voxel_terrain.gd"):
		return true

	return false


## Generate voxel-based cave terrain
## region: The grid region to generate caves in
## context: The generation context containing grid, config, and RNG
## Returns: Node3D containing the voxel terrain, or null if generation fails
func generate_voxel_cave_terrain(region: Rect2i, context: GenerationContext) -> Node3D:
	if not is_voxel_tools_available():
		push_warning("Voxel Tools not available, cannot generate voxel terrain")
		return null

	# Create VoxelTerrain node
	var voxel_terrain: Node3D = _create_voxel_terrain_node(region, context)
	if voxel_terrain == null:
		return null

	# Generate cave structure using marching cubes
	_generate_cave_voxels(voxel_terrain, region, context)

	# Apply noise for natural variation
	_apply_noise_variation(voxel_terrain, region, context)

	return voxel_terrain


## Create VoxelTerrain node with appropriate configuration
func _create_voxel_terrain_node(region: Rect2i, context: GenerationContext) -> Node3D:
	# Use ClassDB to instantiate VoxelTerrain dynamically
	if not ClassDB.class_exists("VoxelTerrain"):
		return null

	var voxel_terrain: Node3D = ClassDB.instantiate("VoxelTerrain")

	# Configure voxel terrain properties
	# Cell size: 2 meters to match grid scale
	voxel_terrain.set(
		"voxel_bounds",
		AABB(
			Vector3(region.position.x * 2.0, 0, region.position.y * 2.0),
			Vector3(region.size.x * 2.0, 6.0, region.size.y * 2.0)
		)
	)

	# Enable marching cubes for smooth surfaces
	voxel_terrain.set("mesher", 1)  # 1 = Marching Cubes

	# Set material based on theme
	var cave_material := _get_cave_material(context)
	if cave_material:
		voxel_terrain.set("material_override", cave_material)

	return voxel_terrain


## Generate cave voxel data using marching cubes algorithm
func _generate_cave_voxels(
	voxel_terrain: Node3D, region: Rect2i, context: GenerationContext
) -> void:
	# Get voxel buffer for editing
	var voxel_tool: Variant = voxel_terrain.get("voxel_tool")
	if voxel_tool == null:
		push_warning("Could not get voxel tool from terrain")
		return

	# Iterate through grid cells in the region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= context.grid.size() or x < 0 or x >= context.grid[y].size():
				continue

			var cell: Cell = context.grid[y][x]

			# Only process cave cells
			if cell.type != Cell.Type.CAVE:
				continue

			# Convert grid position to world position
			var world_x := x * 2.0
			var world_z := y * 2.0

			# Carve out cave space (set voxels to air)
			# Height: 0 to 4 meters (floor to ceiling)
			for voxel_y in range(0, 4):
				var voxel_pos := Vector3i(int(world_x), voxel_y, int(world_z))
				voxel_tool.call("set_voxel", voxel_pos, 0)  # 0 = air


## Apply noise functions for natural cave variation
func _apply_noise_variation(
	voxel_terrain: Node3D, region: Rect2i, context: GenerationContext
) -> void:
	var voxel_tool: Variant = voxel_terrain.get("voxel_tool")
	if voxel_tool == null:
		return

	# Create noise generator (Perlin/Simplex)
	var noise := FastNoiseLite.new()
	noise.seed = context.seed_hash
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05  # Low frequency for large-scale variation
	noise.fractal_octaves = 3

	# Apply noise to cave walls for natural bumps and irregularities
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y < 0 or y >= context.grid.size() or x < 0 or x >= context.grid[y].size():
				continue

			var cell: Cell = context.grid[y][x]
			if cell.type != Cell.Type.CAVE:
				continue

			var world_x := x * 2.0
			var world_z := y * 2.0

			# Sample noise at this position
			var noise_value := noise.get_noise_2d(world_x, world_z)

			# Use noise to vary ceiling height
			var ceiling_offset := int(noise_value * 2.0)  # -2 to +2 meters
			var ceiling_height := 4 + ceiling_offset

			# Apply ceiling variation
			for voxel_y in range(ceiling_height, 6):
				var voxel_pos := Vector3i(int(world_x), voxel_y, int(world_z))
				voxel_tool.call("set_voxel", voxel_pos, 1)  # 1 = solid

			# Use noise to create floor bumps (stalactites/stalagmites)
			if abs(noise_value) > 0.6:  # Only in high-noise areas
				var bump_height := int((abs(noise_value) - 0.6) * 5.0)
				for voxel_y in range(0, bump_height):
					var voxel_pos := Vector3i(int(world_x), voxel_y, int(world_z))
					voxel_tool.call("set_voxel", voxel_pos, 1)  # 1 = solid


## Get cave material based on theme
func _get_cave_material(context: GenerationContext) -> Material:
	# Use theme manager to get appropriate cave material
	if context.theme:
		return context.theme.get_cave_material()

	# Fallback: Create basic cave material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.25, 0.2)  # Brown/gray cave color
	material.roughness = 0.9
	return material
