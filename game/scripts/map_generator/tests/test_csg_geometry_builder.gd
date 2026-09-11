extends GutTest

## Unit tests for CSGGeometryBuilder
## Tests CSG geometry creation, material application, doorways, and baking

var builder: CSGGeometryBuilder
var context: GenerationContext
var config: GenerationConfig


func before_each() -> void:
	# Create test configuration
	config = GenerationConfig.new()
	config.map_size = Vector2i(10, 10)
	config.theme = GenerationConfig.ThemeType.TECH

	# Create test context
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

	# Create builder
	builder = CSGGeometryBuilder.new()


func after_each() -> void:
	if context.csg_root:
		context.csg_root.queue_free()
	builder = null
	context = null
	config = null


func test_initialize_creates_csg_root() -> void:
	builder.initialize(context)

	assert_not_null(context.csg_root, "CSG root should be created")
	assert_eq(context.csg_root.name, "MapGeometry", "CSG root should have correct name")
	assert_true(context.csg_root.use_collision, "CSG root should have collision enabled")


func test_initialize_loads_theme_materials() -> void:
	builder.initialize(context)

	assert_not_null(context.theme, "MapTheme should be created")
	assert_not_null(context.theme.wall_material, "Wall material should be loaded")
	assert_not_null(context.theme.floor_material, "Floor material should be loaded")
	assert_not_null(context.theme.ceiling_material, "Ceiling material should be loaded")


func test_build_geometry_creates_floors() -> void:
	# Create a simple 3x3 room
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.ROOM

	builder.initialize(context)
	var csg_root := builder.build_geometry()

	assert_not_null(csg_root, "CSG root should be returned")

	# Check for Floors node
	var floors_node := csg_root.get_node_or_null("Floors")
	assert_not_null(floors_node, "Floors node should exist")
	assert_gt(floors_node.get_child_count(), 0, "Floors should have child nodes")


func test_build_geometry_creates_walls() -> void:
	# Create a simple 3x3 room
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.ROOM

	builder.initialize(context)
	var csg_root := builder.build_geometry()

	# Check for Walls node
	var walls_node := csg_root.get_node_or_null("Walls")
	assert_not_null(walls_node, "Walls node should exist")
	assert_gt(walls_node.get_child_count(), 0, "Walls should have child nodes")


func test_build_geometry_creates_ceilings() -> void:
	# Create a simple 3x3 room
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.ROOM

	builder.initialize(context)
	var csg_root := builder.build_geometry()

	# Check for Ceilings node
	var ceilings_node := csg_root.get_node_or_null("Ceilings")
	assert_not_null(ceilings_node, "Ceilings node should exist")
	assert_gt(ceilings_node.get_child_count(), 0, "Ceilings should have child nodes")


func test_outdoor_cells_have_no_ceiling() -> void:
	# Create outdoor area
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.OUTDOOR

	builder.initialize(context)
	var csg_root := builder.build_geometry()

	var ceilings_node := csg_root.get_node_or_null("Ceilings")
	assert_not_null(ceilings_node, "Ceilings node should exist")

	# Outdoor cells should not have ceilings
	var ceiling_count := 0
	for child in ceilings_node.get_children():
		if child.name.begins_with("Ceiling_"):
			ceiling_count += 1

	assert_eq(ceiling_count, 0, "Outdoor cells should not have ceilings")


func test_doorways_created_for_hallway_connections() -> void:
	# Create a room and hallway
	context.grid[5][5].type = Cell.Type.ROOM
	context.grid[5][6].type = Cell.Type.HALLWAY

	# Create hallway object
	var hallway := Hallway.new(0, 0, 1)
	hallway.path = [Vector2i(5, 5), Vector2i(5, 6)]
	context.hallways.append(hallway)

	builder.initialize(context)
	var csg_root := builder.build_geometry()

	# Check for Doorways node
	var doorways_node := csg_root.get_node_or_null("Doorways")
	assert_not_null(doorways_node, "Doorways node should exist")
	assert_eq(
		doorways_node.operation,
		CSGShape3D.OPERATION_SUBTRACTION,
		"Doorways should use subtraction operation"
	)


func test_bake_geometry_creates_mesh_instance() -> void:
	# Create a simple room
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.ROOM

	builder.initialize(context)
	var csg_root := builder.build_geometry()
	add_child(csg_root)
	await get_tree().process_frame

	var baked_mesh := builder.bake_geometry()

	assert_not_null(baked_mesh, "Baked mesh should be created")
	assert_true(baked_mesh is MeshInstance3D, "Baked result should be MeshInstance3D")
	assert_not_null(baked_mesh.mesh, "Baked mesh should have mesh data")
	baked_mesh.free()
	csg_root.free()


func test_baked_mesh_has_collision() -> void:
	# Create a simple room
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.ROOM

	builder.initialize(context)
	var csg_root := builder.build_geometry()
	add_child(csg_root)
	await get_tree().process_frame

	var baked_mesh := builder.bake_geometry()

	# Check for collision body
	var collision_body := baked_mesh.get_node_or_null("Collision")
	assert_not_null(collision_body, "Collision body should exist")
	assert_true(collision_body is StaticBody3D, "Collision should be StaticBody3D")

	# Check for collision shape
	var collision_shape := collision_body.get_node_or_null("CollisionShape")
	assert_not_null(collision_shape, "Collision shape should exist")
	assert_not_null(collision_shape.shape, "Collision shape should have shape data")
	baked_mesh.free()
	csg_root.free()


func test_materials_applied_to_geometry() -> void:
	# Create a simple room
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.ROOM

	builder.initialize(context)
	var csg_root := builder.build_geometry()

	# Check that materials are applied
	var floors_node := csg_root.get_node("Floors")
	var first_floor := floors_node.get_child(0) as CSGBox3D
	assert_not_null(first_floor.material, "Floor should have material applied")

	var walls_node := csg_root.get_node("Walls")
	if walls_node.get_child_count() > 0:
		var first_wall := walls_node.get_child(0) as CSGBox3D
		assert_not_null(first_wall.material, "Wall should have material applied")
