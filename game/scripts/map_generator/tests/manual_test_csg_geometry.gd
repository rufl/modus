extends Node3D

## Manual test scene for CSGGeometryBuilder
## Creates a simple test map with rooms, hallways, and doorways

var builder: CSGGeometryBuilder
var context: GenerationContext


func _ready() -> void:
	_setup_test_context()
	_create_test_layout()
	_build_geometry()


func _setup_test_context() -> void:
	# Create configuration
	var config := GenerationConfig.new()
	config.map_size = Vector2i(20, 20)
	config.theme = GenerationConfig.ThemeType.TECH

	# Create context
	context = GenerationContext.new()
	context.config = config
	context.grid_size = config.map_size
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	# Initialize grid
	context.grid = []
	for y in range(config.map_size.y):
		var row: Array[Cell] = []
		for x in range(config.map_size.x):
			row.append(Cell.new(Cell.Type.EMPTY))
		context.grid.append(row)


func _create_test_layout() -> void:
	# Create first room (5x5)
	for y in range(5, 10):
		for x in range(5, 10):
			context.grid[y][x].type = Cell.Type.ROOM
			context.grid[y][x].room_id = 0

	# Create hallway connecting to second room
	for x in range(10, 15):
		context.grid[7][x].type = Cell.Type.HALLWAY
		context.grid[8][x].type = Cell.Type.HALLWAY

	# Create second room (4x4)
	for y in range(6, 10):
		for x in range(15, 19):
			context.grid[y][x].type = Cell.Type.ROOM
			context.grid[y][x].room_id = 1

	# Create outdoor area (3x3)
	for y in range(12, 15):
		for x in range(5, 8):
			context.grid[y][x].type = Cell.Type.OUTDOOR

	# Create cave area (3x3)
	for y in range(12, 15):
		for x in range(10, 13):
			context.grid[y][x].type = Cell.Type.CAVE

	# Create rooms
	var room1 := Room.new(0, Vector2i(7, 7), Room.RoomType.MEDIUM)
	room1.entrance_points = [Vector2i(9, 7), Vector2i(9, 8)]
	context.rooms.append(room1)

	var room2 := Room.new(1, Vector2i(16, 8), Room.RoomType.SMALL)
	room2.entrance_points = [Vector2i(15, 7), Vector2i(15, 8)]
	context.rooms.append(room2)

	# Create hallway
	var hallway := Hallway.new(0, 0, 1)
	hallway.path = []
	for x in range(10, 15):
		hallway.path.append(Vector2i(x, 7))
		hallway.path.append(Vector2i(x, 8))
	context.hallways.append(hallway)


func _build_geometry() -> void:
	# Create builder and build geometry
	builder = CSGGeometryBuilder.new()
	builder.initialize(context)
	var csg_root := builder.build_geometry()

	if csg_root:
		add_child(csg_root)
		print("CSG Geometry built successfully!")
		print("- Floors: ", csg_root.get_node("Floors").get_child_count())
		print("- Walls: ", csg_root.get_node("Walls").get_child_count())
		print("- Ceilings: ", csg_root.get_node("Ceilings").get_child_count())
		print("- Doorways: ", csg_root.get_node("Doorways").get_child_count())
	else:
		push_error("Failed to build CSG geometry")


func _input(event: InputEvent) -> void:
	# Press B to bake geometry
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		_bake_geometry()

	# Press R to rebuild geometry
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_rebuild_geometry()


func _bake_geometry() -> void:
	if builder and context.csg_root:
		print("Baking CSG geometry...")
		var baked_mesh := builder.replace_with_baked_mesh(self)
		if baked_mesh:
			print("Geometry baked successfully!")
			print("- Mesh surfaces: ", baked_mesh.mesh.get_surface_count())
		else:
			push_error("Failed to bake geometry")


func _rebuild_geometry() -> void:
	# Remove existing geometry
	for child in get_children():
		child.queue_free()

	# Rebuild
	_setup_test_context()
	_create_test_layout()
	_build_geometry()
	print("Geometry rebuilt!")
