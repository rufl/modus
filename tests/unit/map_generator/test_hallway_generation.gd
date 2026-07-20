extends ModusGutTestBase

## Unit tests for hallway generation connecting rooms
## Tests Requirements 3.1, 3.4, 3.5, 3.6

const HallwayGenerator = preload("res://game/scripts/map_generator/hallway_generator.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const Room = preload("res://game/scripts/map_generator/room.gd")

var generator: HallwayGenerator
var grid: Array[Array]
var grid_size: Vector2i

func before_each() -> void:
	generator = HallwayGenerator.new()
	grid_size = Vector2i(50, 50)
	
	# Initialize empty grid
	grid = []
	for y in range(grid_size.y):
		var row: Array[Cell] = []
		for x in range(grid_size.x):
			row.append(Cell.new(Cell.Type.EMPTY))
		grid.append(row)

## Test that hallways are generated between adjacent rooms
## Requirement 3.1: Generate hallways connecting adjacent rooms
func test_generate_hallways_between_adjacent_rooms() -> void:
	# Create two adjacent rooms
	var room1: Room = Room.new(0, Vector2i(10, 10), Room.RoomType.SMALL)
	room1.cells = [Vector2i(10, 10), Vector2i(11, 10), Vector2i(10, 11), Vector2i(11, 11)]
	
	var room2: Room = Room.new(1, Vector2i(20, 10), Room.RoomType.SMALL)
	room2.cells = [Vector2i(20, 10), Vector2i(21, 10), Vector2i(20, 11), Vector2i(21, 11)]
	
	# Mark room cells in grid
	for cell_pos in room1.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	for cell_pos in room2.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	
	var rooms: Array[Room] = [room1, room2]
	var hallways: Array = generator.generate_hallways(rooms, grid)
	
	assert_gt(hallways.size(), 0, "Should generate at least one hallway")
	assert_eq(hallways[0].start_room_id, 0, "Hallway should connect room 0")
	assert_eq(hallways[0].end_room_id, 1, "Hallway should connect room 1")

## Test that hallway width is at least 2 cells
## Requirement 3.4: Ensure hallway width is at least 2 cells
func test_hallway_width_minimum_2_cells() -> void:
	# Create two rooms
	var room1: Room = Room.new(0, Vector2i(10, 10), Room.RoomType.SMALL)
	room1.cells = [Vector2i(10, 10), Vector2i(11, 10)]
	
	var room2: Room = Room.new(1, Vector2i(15, 10), Room.RoomType.SMALL)
	room2.cells = [Vector2i(15, 10), Vector2i(16, 10)]
	
	# Mark room cells in grid
	for cell_pos in room1.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	for cell_pos in room2.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	
	var rooms: Array[Room] = [room1, room2]
	var hallways: Array = generator.generate_hallways(rooms, grid)
	
	assert_gt(hallways.size(), 0, "Should generate hallway")
	assert_eq(hallways[0].width, 2, "Hallway width should be at least 2")

## Test that hallways are applied to the grid
func test_hallways_applied_to_grid() -> void:
	# Create two rooms
	var room1: Room = Room.new(0, Vector2i(10, 10), Room.RoomType.SMALL)
	room1.cells = [Vector2i(10, 10), Vector2i(11, 10)]
	
	var room2: Room = Room.new(1, Vector2i(15, 10), Room.RoomType.SMALL)
	room2.cells = [Vector2i(15, 10), Vector2i(16, 10)]
	
	# Mark room cells in grid
	for cell_pos in room1.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	for cell_pos in room2.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	
	var rooms: Array[Room] = [room1, room2]
	var hallways: Array = generator.generate_hallways(rooms, grid)
	
	# Check that hallway cells are marked in grid
	var hallway_cell_count := 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if grid[y][x].type == Cell.Type.HALLWAY:
				hallway_cell_count += 1
	
	assert_gt(hallway_cell_count, 0, "Grid should contain hallway cells")

## Test that room connections are updated
## Requirement 3.6: Hallways connect exactly two rooms
func test_room_connections_updated() -> void:
	# Create two rooms
	var room1: Room = Room.new(0, Vector2i(10, 10), Room.RoomType.SMALL)
	room1.cells = [Vector2i(10, 10), Vector2i(11, 10)]
	
	var room2: Room = Room.new(1, Vector2i(15, 10), Room.RoomType.SMALL)
	room2.cells = [Vector2i(15, 10), Vector2i(16, 10)]
	
	# Mark room cells in grid
	for cell_pos in room1.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	for cell_pos in room2.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	
	var rooms: Array[Room] = [room1, room2]
	var hallways: Array = generator.generate_hallways(rooms, grid)
	
	assert_true(room2.id in room1.connections, "Room 1 should be connected to Room 2")
	assert_true(room1.id in room2.connections, "Room 2 should be connected to Room 1")

## Test that distant rooms are not connected
func test_distant_rooms_not_connected() -> void:
	# Create two distant rooms
	var room1: Room = Room.new(0, Vector2i(5, 5), Room.RoomType.SMALL)
	room1.cells = [Vector2i(5, 5), Vector2i(6, 5)]
	
	var room2: Room = Room.new(1, Vector2i(45, 45), Room.RoomType.SMALL)
	room2.cells = [Vector2i(45, 45), Vector2i(46, 45)]
	
	# Mark room cells in grid
	for cell_pos in room1.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	for cell_pos in room2.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	
	var rooms: Array[Room] = [room1, room2]
	var hallways: Array = generator.generate_hallways(rooms, grid)
	
	# Should not generate hallway between very distant rooms
	assert_eq(hallways.size(), 0, "Should not connect distant rooms")

## Test that multiple rooms can be connected
func test_multiple_room_connections() -> void:
	# Create three rooms in a line
	var room1: Room = Room.new(0, Vector2i(10, 10), Room.RoomType.SMALL)
	room1.cells = [Vector2i(10, 10), Vector2i(11, 10)]
	
	var room2: Room = Room.new(1, Vector2i(15, 10), Room.RoomType.SMALL)
	room2.cells = [Vector2i(15, 10), Vector2i(16, 10)]
	
	var room3: Room = Room.new(2, Vector2i(20, 10), Room.RoomType.SMALL)
	room3.cells = [Vector2i(20, 10), Vector2i(21, 10)]
	
	# Mark room cells in grid
	for cell_pos in room1.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	for cell_pos in room2.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	for cell_pos in room3.cells:
		grid[cell_pos.y][cell_pos.x].type = Cell.Type.ROOM
	
	var rooms: Array[Room] = [room1, room2, room3]
	var hallways: Array = generator.generate_hallways(rooms, grid)
	
	# Should generate hallways between adjacent rooms
	assert_gt(hallways.size(), 1, "Should generate multiple hallways")
