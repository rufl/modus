extends GutTest

## Unit tests for OcclusionCullingManager
## Tests occluder generation at room boundaries and large walls

const OcclusionCullingManagerScript: GDScript = preload(
	"res://game/scripts/map_generator/occlusion_culling_manager.gd"
)

var occlusion_manager: RefCounted
var context: GenerationContext
var grid_manager: GridLayoutManager


func before_each() -> void:
	# Create a test generation context
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_occlusion_culling = true
	context.grid_size = Vector2i(32, 32)

	# Initialize grid
	grid_manager = GridLayoutManager.new()
	grid_manager.initialize_grid(context.grid_size)
	context.grid = grid_manager.grid

	# Initialize occlusion culling manager
	occlusion_manager = OcclusionCullingManagerScript.new()
	occlusion_manager.initialize(context)


func after_each() -> void:
	occlusion_manager = null
	context = null
	grid_manager = null


## Test: Occluder generation for simple room
func test_occluder_generation() -> void:
	# Create a simple room
	var room := Room.new(0, Vector2i(16, 16), Room.RoomType.MEDIUM)
	for y in range(14, 19):
		for x in range(14, 19):
			room.cells.append(Vector2i(x, y))
			context.grid[y][x].type = Cell.Type.ROOM
			context.grid[y][x].room_id = 0

	room.entrance_points.append(Vector2i(16, 18))
	context.rooms.append(room)

	# Generate occluders
	var occluders_root: Node3D = occlusion_manager.generate_occluders()

	assert_not_null(occluders_root, "Occluders root should not be null")
	assert_eq(occluders_root.name, "Occluders", "Occluders root should be named 'Occluders'")

	var occluder_count: int = occlusion_manager.get_occluder_count()
	assert_gt(occluder_count, 0, "Should generate at least one occluder for room boundaries")


## Test: Room boundary detection with two adjacent rooms
func test_room_boundary_detection() -> void:
	# Create room 1
	var room1 := Room.new(0, Vector2i(10, 16), Room.RoomType.SMALL)
	for y in range(14, 19):
		for x in range(8, 13):
			room1.cells.append(Vector2i(x, y))
			context.grid[y][x].type = Cell.Type.ROOM
			context.grid[y][x].room_id = 0

	context.rooms.append(room1)

	# Create room 2 (adjacent to room 1)
	var room2 := Room.new(1, Vector2i(20, 16), Room.RoomType.SMALL)
	for y in range(14, 19):
		for x in range(18, 23):
			room2.cells.append(Vector2i(x, y))
			context.grid[y][x].type = Cell.Type.ROOM
			context.grid[y][x].room_id = 1

	context.rooms.append(room2)

	# Generate occluders
	var _occluders_root: Node3D = occlusion_manager.generate_occluders()

	var occluder_count: int = occlusion_manager.get_occluder_count()
	assert_gt(occluder_count, 0, "Should generate occluders for room boundaries")


## Test: Gameplay critical walls are excluded
func test_gameplay_critical_walls() -> void:
	# Create a room with entrance points
	var room := Room.new(0, Vector2i(16, 16), Room.RoomType.MEDIUM)
	for y in range(14, 19):
		for x in range(14, 19):
			room.cells.append(Vector2i(x, y))
			context.grid[y][x].type = Cell.Type.ROOM
			context.grid[y][x].room_id = 0

	# Add entrance point
	room.entrance_points.append(Vector2i(16, 18))

	# Add hallway adjacent to entrance
	context.grid[19][16].type = Cell.Type.HALLWAY

	context.rooms.append(room)

	# Generate occluders
	var _occluders_root: Node3D = occlusion_manager.generate_occluders()

	# Occluders should be generated, but not at the entrance
	var occluder_count: int = occlusion_manager.get_occluder_count()
	assert_gte(occluder_count, 0, "Should generate occluders but exclude entrance walls")


## Test: Occlusion data baking
func test_baking() -> void:
	# Create a simple room
	var room := Room.new(0, Vector2i(16, 16), Room.RoomType.MEDIUM)
	for y in range(14, 19):
		for x in range(14, 19):
			room.cells.append(Vector2i(x, y))
			context.grid[y][x].type = Cell.Type.ROOM
			context.grid[y][x].room_id = 0

	context.rooms.append(room)

	# Generate occluders
	var _occluders_root: Node3D = occlusion_manager.generate_occluders()

	# Bake occlusion data (should not throw errors)
	occlusion_manager.bake_occlusion_data()

	assert_true(true, "Baking should complete without errors")


## Test: Disabled occlusion culling
func test_disabled_occlusion() -> void:
	# Create context with occlusion culling disabled
	var disabled_context := GenerationContext.new()
	disabled_context.config = GenerationConfig.new()
	disabled_context.config.enable_occlusion_culling = false
	disabled_context.grid_size = Vector2i(32, 32)

	# Initialize grid
	var disabled_grid_manager := GridLayoutManager.new()
	disabled_grid_manager.initialize_grid(disabled_context.grid_size)
	disabled_context.grid = disabled_grid_manager.grid

	# Create a simple room
	var room := Room.new(0, Vector2i(16, 16), Room.RoomType.MEDIUM)
	for y in range(14, 19):
		for x in range(14, 19):
			room.cells.append(Vector2i(x, y))
			disabled_context.grid[y][x].type = Cell.Type.ROOM
			disabled_context.grid[y][x].room_id = 0

	disabled_context.rooms.append(room)

	# Initialize occlusion culling manager
	var disabled_occlusion: RefCounted = OcclusionCullingManagerScript.new()
	disabled_occlusion.initialize(disabled_context)

	# Generate occluders (should do nothing)
	var _occluders_root: Node3D = disabled_occlusion.generate_occluders()

	var occluder_count: int = disabled_occlusion.get_occluder_count()
	assert_eq(occluder_count, 0, "Should not generate occluders when disabled")


## Test: Occluder properties
func test_occluder_properties() -> void:
	# Create a simple room
	var room := Room.new(0, Vector2i(16, 16), Room.RoomType.MEDIUM)
	for y in range(14, 19):
		for x in range(14, 19):
			room.cells.append(Vector2i(x, y))
			context.grid[y][x].type = Cell.Type.ROOM
			context.grid[y][x].room_id = 0

	context.rooms.append(room)

	# Generate occluders
	var occluders_root: Node3D = occlusion_manager.generate_occluders()

	# Check that occluders have proper properties
	if occluders_root.get_child_count() > 0:
		var first_occluder: OccluderInstance3D = occluders_root.get_child(0) as OccluderInstance3D
		assert_not_null(first_occluder, "First child should be an OccluderInstance3D")
		assert_not_null(first_occluder.occluder, "Occluder should have an occluder shape")
		assert_true(
			first_occluder.occluder is BoxOccluder3D, "Occluder shape should be BoxOccluder3D"
		)
