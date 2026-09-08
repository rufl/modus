extends GutTest

## Unit tests for HallwayGenerator

var generator: HallwayGenerator
var grid: Array[Array]
var grid_size: Vector2i


func before_each() -> void:
	generator = HallwayGenerator.new()
	grid_size = Vector2i(20, 20)

	# Initialize empty grid
	grid = []
	for y in range(grid_size.y):
		var row: Array[Cell] = []
		for x in range(grid_size.x):
			row.append(Cell.new(Cell.Type.EMPTY))
		grid.append(row)


func test_find_hallway_path_straight_line() -> void:
	var start := Vector2i(5, 5)
	var goal := Vector2i(5, 10)

	var path := generator.find_hallway_path(start, goal, grid)

	assert_gt(path.size(), 0, "Should find a path")
	assert_eq(path[0], start, "Path should start at start position")
	assert_eq(path[path.size() - 1], goal, "Path should end at goal position")


func test_find_hallway_path_diagonal() -> void:
	var start := Vector2i(5, 5)
	var goal := Vector2i(10, 10)

	var path := generator.find_hallway_path(start, goal, grid)

	assert_gt(path.size(), 0, "Should find a path")
	assert_eq(path[0], start, "Path should start at start position")
	assert_eq(path[path.size() - 1], goal, "Path should end at goal position")


func test_find_hallway_path_with_obstacle() -> void:
	var start := Vector2i(5, 5)
	var goal := Vector2i(5, 10)

	# Create a wall blocking the direct path
	for x in range(3, 8):
		grid[7][x].type = Cell.Type.ROOM  # Use ROOM as obstacle

	# Mark start and goal as empty to allow pathfinding
	grid[start.y][start.x].type = Cell.Type.EMPTY
	grid[goal.y][goal.x].type = Cell.Type.EMPTY

	var path := generator.find_hallway_path(start, goal, grid)

	# Path should exist but go around the obstacle
	assert_gt(path.size(), 0, "Should find a path around obstacle")
	assert_eq(path[0], start, "Path should start at start position")
	assert_eq(path[path.size() - 1], goal, "Path should end at goal position")


func test_find_hallway_path_no_path() -> void:
	var start := Vector2i(5, 5)
	var goal := Vector2i(15, 15)

	# Create a complete wall blocking the path
	for y in range(grid_size.y):
		grid[y][10].type = Cell.Type.ROOM

	var path := generator.find_hallway_path(start, goal, grid)

	assert_eq(path.size(), 0, "Should return empty array when no path exists")


func test_find_hallway_path_through_existing_hallway() -> void:
	var start := Vector2i(5, 5)
	var goal := Vector2i(5, 10)

	# Mark some cells as existing hallway
	grid[5][6].type = Cell.Type.HALLWAY
	grid[5][7].type = Cell.Type.HALLWAY

	var path := generator.find_hallway_path(start, goal, grid)

	assert_gt(path.size(), 0, "Should find path through existing hallway")


func test_path_is_continuous() -> void:
	var start := Vector2i(5, 5)
	var goal := Vector2i(10, 10)

	var path := generator.find_hallway_path(start, goal, grid)

	assert_gt(path.size(), 1, "Path should have at least 2 points")

	# Verify each step is adjacent to the next
	for i in range(path.size() - 1):
		var current := path[i]
		var next := path[i + 1]
		var distance: int = abs(current.x - next.x) + abs(current.y - next.y)
		assert_eq(distance, 1, "Each step should be adjacent (Manhattan distance = 1)")


func test_manhattan_distance_heuristic() -> void:
	# Test Manhattan distance calculation indirectly through pathfinding
	var start := Vector2i(0, 0)
	var goal := Vector2i(3, 4)

	var path := generator.find_hallway_path(start, goal, grid)

	# Path should exist and use Manhattan distance heuristic
	assert_gt(path.size(), 0, "Should find a path using Manhattan distance heuristic")
	assert_eq(path[0], start, "Path should start at start position")
	assert_eq(path[path.size() - 1], goal, "Path should end at goal position")


func test_manhattan_distance_same_point() -> void:
	# Test pathfinding to same point
	var start := Vector2i(5, 5)
	var goal := Vector2i(5, 5)

	var path := generator.find_hallway_path(start, goal, grid)

	# Should return path with just the start point
	assert_eq(path.size(), 1, "Path to same point should contain just that point")
	assert_eq(path[0], start, "Path should be the start/goal point")


func test_path_optimality() -> void:
	var start := Vector2i(5, 5)
	var goal := Vector2i(5, 10)

	var path := generator.find_hallway_path(start, goal, grid)

	# For a straight line with no obstacles, path length should be optimal
	var expected_length: int = abs(goal.y - start.y) + 1  # +1 to include start
	assert_eq(path.size(), expected_length, "Path should be optimal length")
