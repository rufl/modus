extends Node3D

## Manual test for secret room and key-lock systems
## Run this scene to visualize secret rooms and key-lock placement

const SecretRoomGenerator = preload("res://game/scripts/map_generator/secret_room_generator.gd")
const KeyLockSystem = preload("res://game/scripts/map_generator/key_lock_system.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var context: GenerationContext
var secret_generator: SecretRoomGenerator
var key_lock_system: KeyLockSystem


func _ready() -> void:
	print("=== Secret Room and Key-Lock System Manual Test ===")

	# Initialize systems
	secret_generator = SecretRoomGenerator.new()
	key_lock_system = KeyLockSystem.new()

	# Create test context
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_secrets = true
	context.config.enable_key_locks = true
	context.config.secret_room_count = 2
	context.grid_size = Vector2i(64, 64)

	# Initialize grid
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		row.resize(context.grid_size.x)
		for x in range(context.grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		context.grid.append(row)

	# Seed RNG for reproducible results
	context.rng.seed = 12345

	# Create test rooms
	_create_test_rooms()

	# Generate secret rooms
	print("\n--- Generating Secret Rooms ---")
	var secret_rooms: Array = secret_generator.generate_secret_rooms(context)
	context.secret_rooms = secret_rooms

	print("Generated %d secret rooms" % secret_rooms.size())
	for i in range(secret_rooms.size()):
		var secret: Dictionary = secret_rooms[i]
		print("  Secret Room %d:" % i)
		print("    Cells: %d" % secret.cells.size())
		print("    Fake Wall: %s" % secret.fake_wall_position)
		print("    Adjacent Room: %d" % secret.adjacent_room_id)

	# Place secret items
	secret_generator.place_secret_items(context)
	print("\nPlaced %d high-value items in secret rooms" % context.item_spawns.size())

	# Generate key-lock system
	print("\n--- Generating Key-Lock System ---")
	var key_lock_data: Dictionary = key_lock_system.generate_key_lock_system(context)

	var keys: Array = key_lock_data.get("keys", [])
	var locked_doors: Array = key_lock_data.get("locked_doors", [])

	print("Generated %d keys and %d locked doors" % [keys.size(), locked_doors.size()])

	for i in range(keys.size()):
		var key: Dictionary = keys[i]
		print("  Key %d: %s in room %d" % [i, key.color, key.room_id])

	for i in range(locked_doors.size()):
		var door: Dictionary = locked_doors[i]
		print("  Door %d: %s blocking room %d" % [i, door.color, door.room_id])

	# Validate progression
	print("\n--- Validating Key-Lock Progression ---")
	var is_valid: bool = key_lock_system.validate_key_lock_progression(context, keys, locked_doors)
	print("Progression valid: %s" % is_valid)

	# Visualize results
	_visualize_map()

	print("\n=== Test Complete ===")


func _create_test_rooms() -> void:
	print("\n--- Creating Test Rooms ---")

	# Create a chain of 6 connected rooms
	var room_positions := [
		Vector2i(10, 10),
		Vector2i(25, 10),
		Vector2i(40, 10),
		Vector2i(40, 25),
		Vector2i(25, 25),
		Vector2i(10, 25)
	]

	for i in range(room_positions.size()):
		var center: Vector2i = room_positions[i]
		var room := Room.new(i, center, Room.RoomType.MEDIUM)

		# Create room cells (7x7 square)
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var pos := center + Vector2i(dx, dy)
				if (
					pos.x >= 0
					and pos.x < context.grid_size.x
					and pos.y >= 0
					and pos.y < context.grid_size.y
				):
					context.grid[pos.y][pos.x].type = Cell.Type.ROOM
					context.grid[pos.y][pos.x].room_id = room.id
					room.cells.append(pos)

		# Add entrance points
		if i > 0:
			room.entrance_points.append(center + Vector2i(-3, 0))
		if i < room_positions.size() - 1:
			room.entrance_points.append(center + Vector2i(3, 0))

		# Connect to previous room
		if i > 0:
			room.connections.append(i - 1)
			context.rooms[i - 1].connections.append(i)

		context.rooms.append(room)

	print("Created %d test rooms" % context.rooms.size())


func _visualize_map() -> void:
	print("\n--- Visualizing Map ---")

	# Create simple 3D visualization
	var cell_size := 2.0

	# Visualize rooms
	for room: Room in context.rooms:
		var room_mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.5, 0.1, 0.5)
		room_mesh.mesh = box_mesh

		var material := StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		room_mesh.set_surface_override_material(0, material)

		room_mesh.position = Vector3(room.center.x * cell_size, 0.0, room.center.y * cell_size)
		add_child(room_mesh)

	# Visualize secret rooms
	for secret: Dictionary in context.secret_rooms:
		for cell_pos: Vector2i in secret.cells:
			var secret_mesh := MeshInstance3D.new()
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(0.4, 0.2, 0.4)
			secret_mesh.mesh = box_mesh

			var material := StandardMaterial3D.new()
			material.albedo_color = Color.YELLOW
			secret_mesh.set_surface_override_material(0, material)

			secret_mesh.position = Vector3(cell_pos.x * cell_size, 0.1, cell_pos.y * cell_size)
			add_child(secret_mesh)

		# Visualize fake wall
		var wall_pos: Vector2i = secret.fake_wall_position
		var wall_mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.3, 0.3, 0.3)
		wall_mesh.mesh = box_mesh

		var material := StandardMaterial3D.new()
		material.albedo_color = Color.ORANGE
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.5
		wall_mesh.set_surface_override_material(0, material)

		wall_mesh.position = Vector3(wall_pos.x * cell_size, 0.15, wall_pos.y * cell_size)
		add_child(wall_mesh)

	# Visualize keys
	for key: Dictionary in context.key_placements:
		var key_mesh := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.3
		sphere_mesh.height = 0.6
		key_mesh.mesh = sphere_mesh

		var material := StandardMaterial3D.new()
		var color_name: String = key.get("color", "RED")
		match color_name:
			"RED":
				material.albedo_color = Color.RED
			"BLUE":
				material.albedo_color = Color.BLUE
			"YELLOW":
				material.albedo_color = Color.YELLOW
		key_mesh.set_surface_override_material(0, material)

		key_mesh.position = key.get("world_position", Vector3.ZERO) + Vector3(0, 0.3, 0)
		add_child(key_mesh)

	# Add camera
	var camera := Camera3D.new()
	camera.position = Vector3(32, 50, 32)
	camera.look_at(Vector3(32, 0, 32))
	add_child(camera)

	print("Visualization complete")
