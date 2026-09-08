extends ModusGutTestBase

## Unit tests for GridLayoutManager A* pathfinding algorithm
## Tests Requirement 3.2

const GridLayoutManager = preload("res://game/scripts/map_generator/grid_layout_manager.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")

var grid_manager: GridLayoutManager


func before_each() -> void:
	grid_manager = GridLayoutManager.new()


func after_each() -> void:
	grid_manager = null


## Test that find_hallway_path finds a simple straight path
func test_find_straight_path() -> void:
	# Create a 10x10 grid
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Set up a straight horizontal corridor
	for x in range(2, 8):
		grid_manager.grid[5][x].type = Cell.Type.HALLWAY

	var start := Vector2i(2, 5)
	var goal := Vector2i(7, 5)
	var path: Array[Vector2i] = grid_manager.find_hallway_path(start, goal)

	assert_not_null(path, "Path should be found")
	assert_gt(path.size(), 0, "Path should not be empty")
	assert_eq(path[0], start, "Path should start at start position")
	assert_eq(path[-1], goal, "Path should end at goal position")
	assert_eq(path.size(), 6, "Path length should be 6 (distance of 5 + 1)")


## Test that find_hallway_path finds a path around obstacles
func test_find_path_around_obstacle() -> void:
	# Create a 10x10 grid
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Create a corridor with a wall in the middle, forcing a detour
	# Path: (2,5) -> (2,4) -> (3,4) -> (4,4) -> (5,4) -> (5,5)
	grid_manager.grid[5][2].type = Cell.Type.HALLWAY  # Start
	grid_manager.grid[4][2].type = Cell.Type.HALLWAY
	grid_manager.grid[4][3].type = Cell.Type.HALLWAY
	grid_manager.grid[4][4].type = Cell.Type.HALLWAY
	grid_manager.grid[4][5].type = Cell.Type.HALLWAY
	grid_manager.grid[5][5].type = Cell.Type.HALLWAY  # Goal
	# Wall at (5,3) and (5,4) blocks direct path

	var start := Vector2i(2, 5)
	var goal := Vector2i(5, 5)
	var path: Array[Vector2i] = grid_manager.find_hallway_path(start, goal)

	assert_not_null(path, "Path should be found")
	assert_gt(path.size(), 0, "Path should not be empty")
	assert_eq(path[0], start, "Path should start at start position")
	assert_eq(path[-1], goal, "Path should end at goal position")


## Test that find_hallway_path returns empty array when no path exists
func test_no_path_returns_empty_array() -> void:
	# Create a 10x10 grid with no walkable cells
	grid_manager.initialize_grid(Vector2i(10, 10))

	var start := Vector2i(2, 2)
	var goal := Vector2i(7, 7)
	var path: Array[Vector2i] = grid_manager.find_hallway_path(start, goal)

	assert_eq(path.size(), 0, "Should return empty array when no path exists")


## Test that find_hallway_path handles invalid positions
func test_invalid_positions() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Test out of bounds start
	var path1: Array[Vector2i] = grid_manager.find_hallway_path(Vector2i(-1, 5), Vector2i(5, 5))
	assert_eq(path1.size(), 0, "Should return empty array for out of bounds start")

	# Test out of bounds goal
	var path2: Array[Vector2i] = grid_manager.find_hallway_path(Vector2i(5, 5), Vector2i(15, 5))
	assert_eq(path2.size(), 0, "Should return empty array for out of bounds goal")


## Test that find_hallway_path works with different cell types
func test_pathfinding_with_different_cell_types() -> void:
	# Create a 10x10 grid
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Create a path using different walkable cell types
	grid_manager.grid[5][2].type = Cell.Type.ROOM
	grid_manager.grid[5][3].type = Cell.Type.HALLWAY
	grid_manager.grid[5][4].type = Cell.Type.OUTDOOR
	grid_manager.grid[5][5].type = Cell.Type.CAVE
	grid_manager.grid[5][6].type = Cell.Type.BOSS_ARENA
	grid_manager.grid[5][7].type = Cell.Type.SECRET

	var start := Vector2i(2, 5)
	var goal := Vector2i(7, 5)
	var path: Array[Vector2i] = grid_manager.find_hallway_path(start, goal)

	assert_not_null(path, "Path should be found across different cell types")
	assert_gt(path.size(), 0, "Path should not be empty")
	assert_eq(path[0], start, "Path should start at start position")
	assert_eq(path[-1], goal, "Path should end at goal position")


## Test that pathfinding is optimal (shortest path)
func test_pathfinding_finds_shortest_path() -> void:
	# Create a 10x10 grid with all cells walkable
	grid_manager.initialize_grid(Vector2i(10, 10))

	for y in range(10):
		for x in range(10):
			grid_manager.grid[y][x].type = Cell.Type.HALLWAY

	var start := Vector2i(0, 0)
	var goal := Vector2i(5, 5)
	var path: Array[Vector2i] = grid_manager.find_hallway_path(start, goal)

	# Shortest path should be Manhattan distance + 1 (for inclusive endpoints)
	var expected_length: int = abs(goal.x - start.x) + abs(goal.y - start.y) + 1
	assert_eq(path.size(), expected_length, "Path should be optimal (shortest)")


## Test that start equals goal returns single-element path
func test_start_equals_goal() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))
	grid_manager.grid[5][5].type = Cell.Type.HALLWAY

	var pos := Vector2i(5, 5)
	var path: Array[Vector2i] = grid_manager.find_hallway_path(pos, pos)

	assert_eq(path.size(), 1, "Path from position to itself should have length 1")
	assert_eq(path[0], pos, "Path should contain only the start/goal position")
