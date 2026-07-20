extends GutTest

## Unit tests for VoxelCaveGenerator
## Tests voxel tools detection and cave generation

const VoxelCaveGenerator = preload("res://game/scripts/map_generator/voxel_cave_generator.gd")
const CaveSystemGenerator = preload("res://game/scripts/map_generator/cave_system_generator.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")

var voxel_generator: VoxelCaveGenerator
var cave_system_generator: CaveSystemGenerator


func before_each() -> void:
	voxel_generator = VoxelCaveGenerator.new()
	cave_system_generator = CaveSystemGenerator.new()


func after_each() -> void:
	voxel_generator = null
	cave_system_generator = null


## Test: Voxel Tools detection
func test_voxel_tools_detection() -> void:
	# Test static method for voxel tools availability
	var is_available := VoxelCaveGenerator.is_voxel_tools_available()

	# Should return a boolean (true or false)
	assert_typeof(is_available, TYPE_BOOL, "Should return boolean")

	# Log the result for manual verification
	if is_available:
		gut.p("Voxel Tools detected: AVAILABLE")
	else:
		gut.p("Voxel Tools detected: NOT AVAILABLE (using CSG fallback)")


## Test: CaveSystemGenerator uses correct generator based on availability
func test_cave_system_generator_initialization() -> void:
	# Check if cave system generator correctly detected voxel tools
	var uses_voxel := cave_system_generator.is_using_voxel_tools()
	var voxel_available := VoxelCaveGenerator.is_voxel_tools_available()

	# Should match the detection result
	assert_eq(
		uses_voxel, voxel_available, "CaveSystemGenerator should use voxel tools if available"
	)

	gut.p("CaveSystemGenerator using voxel tools: %s" % uses_voxel)


## Test: Voxel cave generation returns null when voxel tools unavailable
func test_voxel_generation_fallback() -> void:
	# Create minimal context
	var context := GenerationContext.new()
	context.config = GenerationConfig.new()
	context.grid_size = Vector2i(64, 64)
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345
	context.seed_hash = 12345

	# Initialize grid
	context.grid = []
	for y in range(64):
		var row: Array[Cell] = []
		for x in range(64):
			var cell := Cell.new()
			cell.type = (
				Cell.Type.CAVE if (x > 10 and x < 20 and y > 10 and y < 20) else Cell.Type.EMPTY
			)
			row.append(cell)
		context.grid.append(row)

	# Try to generate voxel cave geometry
	var region := Rect2i(10, 10, 10, 10)
	var voxel_terrain := cave_system_generator.generate_voxel_cave_geometry(region, context)

	# If voxel tools not available, should return null
	if not VoxelCaveGenerator.is_voxel_tools_available():
		assert_null(voxel_terrain, "Should return null when voxel tools unavailable")
		gut.p("Correctly returned null for voxel generation (fallback to CSG)")
	else:
		# If voxel tools available, should return a Node3D
		assert_not_null(voxel_terrain, "Should return Node3D when voxel tools available")
		assert_true(voxel_terrain is Node3D, "Should be a Node3D")
		gut.p("Successfully generated voxel terrain")

		# Clean up
		if voxel_terrain:
			voxel_terrain.free()


## Test: ClassDB detection method
func test_classdb_detection() -> void:
	# Test if ClassDB.class_exists works for VoxelTerrain
	var has_voxel_terrain := ClassDB.class_exists("VoxelTerrain")

	gut.p("ClassDB.class_exists('VoxelTerrain'): %s" % has_voxel_terrain)

	# Should be consistent with is_voxel_tools_available
	var is_available := VoxelCaveGenerator.is_voxel_tools_available()

	# If ClassDB finds it, is_available should be true
	if has_voxel_terrain:
		assert_true(is_available, "If ClassDB finds VoxelTerrain, should be available")


## Test: ResourceLoader detection method
func test_resource_loader_detection() -> void:
	# Test if ResourceLoader can find voxel addon files
	var has_voxel_script := ResourceLoader.exists("res://addons/voxel/voxel_terrain.gd")

	gut.p("ResourceLoader.exists('res://addons/voxel/voxel_terrain.gd'): %s" % has_voxel_script)

	# This is a fallback method, so it's okay if it returns false
	# Just log the result for information
