extends Node3D

## Manual test for AdvancedGeometryBuilder
## Run this scene to visually verify sloped floors/ceilings and 3D floors

var context: GenerationContext
var csg_builder: CSGGeometryBuilder


func _ready() -> void:
	print("\n=== Manual Test: Advanced Geometry Builder ===\n")

	# Create test context
	_create_test_context()

	# Create CSG geometry builder
	csg_builder = CSGGeometryBuilder.new()
	csg_builder.initialize(context)

	# Add basic room geometry
	_create_test_room()

	# Add sloped floors
	print("Adding floor slopes...")
	csg_builder.add_floor_slope(Vector2i(5, 5), 30.0, Vector2(1, 0))
	csg_builder.add_floor_slope(Vector2i(7, 5), 20.0, Vector2(0, 1))

	# Add sloped ceilings
	print("Adding ceiling slopes...")
	csg_builder.add_ceiling_slope(Vector2i(5, 7), 25.0, Vector2(1, 1))

	# Add 3D floors (platforms)
	print("Adding 3D floor platforms...")
	csg_builder.add_3d_floor(Vector2i(3, 3), 1.0)  # Low platform
	csg_builder.add_3d_floor(Vector2i(3, 5), 1.5)  # Medium platform
	csg_builder.add_3d_floor(Vector2i(3, 7), 2.0)  # High platform

	# Add UDMF-style slopes
	print("Adding UDMF slopes...")
	csg_builder.add_udmf_slope("angle:35,1,0", Vector2i(9, 5), false)

	# Build all geometry
	print("Building geometry...")
	var csg_root := csg_builder.build_geometry()

	if csg_root:
		add_child(csg_root)
		print("✓ Geometry built successfully")

		# Print statistics
		_print_statistics(csg_root)
	else:
		print("✗ Failed to build geometry")

	# Add camera for viewing
	_setup_camera()

	# Add lighting
	_setup_lighting()

	print("\n=== Test Complete ===")
	print("Press ESC to quit")


func _create_test_context() -> void:
	context = GenerationContext.new()

	# Create a 16x16 test grid
	var grid_size := Vector2i(16, 16)
	context.grid_size = grid_size
	context.grid = []

	for y in range(grid_size.y):
		var row: Array[Cell] = []
		for x in range(grid_size.x):
			var cell := Cell.new(Cell.Type.ROOM)
			row.append(cell)
		context.grid.append(row)

	# Create test config
	var config := GenerationConfig.new()
	config.map_size = grid_size
	config.theme = GenerationConfig.ThemeType.TECH
	context.config = config

	# Create test theme
	context.theme = MapTheme.create_default_theme(GenerationConfig.ThemeType.TECH)

	# Initialize arrays
	context.rooms = []
	context.hallways = []
	context.metadata = {}
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345


func _create_test_room() -> void:
	# Create a large room for testing
	for y in range(2, 10):
		for x in range(2, 12):
			context.grid[y][x].type = Cell.Type.ROOM


func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(16, 10, 20)
	camera.look_at(Vector3(16, 0, 16))
	add_child(camera)
	camera.make_current()


func _setup_lighting() -> void:
	# Add directional light
	var light := DirectionalLight3D.new()
	light.position = Vector3(0, 10, 0)
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.0
	add_child(light)

	# Add ambient light
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.3)
	env.ambient_light_energy = 0.5
	environment.environment = env
	add_child(environment)


func _print_statistics(csg_root: CSGCombiner3D) -> void:
	print("\n--- Geometry Statistics ---")

	var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
	if slopes_node:
		print("Sloped Surfaces: ", slopes_node.get_child_count())
	else:
		print("Sloped Surfaces: 0 (node not found)")

	var platforms_node := csg_root.get_node_or_null("3DFloors")
	if platforms_node:
		print("3D Floor Platforms: ", platforms_node.get_child_count())
	else:
		print("3D Floor Platforms: 0 (node not found)")

	var floors_node := csg_root.get_node_or_null("Floors")
	if floors_node:
		print("Floor Tiles: ", floors_node.get_child_count())

	var walls_node := csg_root.get_node_or_null("Walls")
	if walls_node:
		print("Walls: ", walls_node.get_child_count())

	var ceilings_node := csg_root.get_node_or_null("Ceilings")
	if ceilings_node:
		print("Ceilings: ", ceilings_node.get_child_count())

	print("---------------------------\n")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
