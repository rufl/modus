extends ModusGutTestBase

## Unit tests for dead-end removal algorithm
## Tests Requirement 3.3

const HallwayGenerator = preload("res://game/scripts/map_generator/hallway_generator.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")

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

## Test that a simple dead-end is removed
## Requirement 3.3: Detect and remove dead-end segments
func test_remove_simple_dead_end() -> void:
	# Create a hallway with a dead end
	# Pattern: R-H-H-H-H (Room connected to hallway with dead end)
	grid[10][10].type = Cell.Type.ROOM
	grid[10][11].type = Cell.Type.HALLWAY
	grid[10][12].type = Cell.Type.HALLWAY
	grid[10][13].type = Cell.Type.HALLWAY
	grid[10][14].type = Cell.Type.HALLWAY  # Dead end
	
	generator.remove_dead_ends(grid)
	
	# The dead end should be removed
	assert_eq(grid[10][14].type, Cell.Type.EMPTY, "Dead end should be removed")
	# The hallway leading to it should also be removed iteratively
	assert_eq(grid[10][13].type, Cell.Type.EMPTY, "Hallway leading to dead end should be removed")

## Test that hallways connecting two rooms are not removed
func test_hallway_between_rooms_not_removed() -> void:
	# Create a hallway connecting two rooms
	# Pattern: R-H-H-H-R
	grid[10][10].type = Cell.Type.ROOM
	grid[10][11].type = Cell.Type.HALLWAY
	grid[10][12].type = Cell.Type.HALLWAY
	grid[10][13].type = Cell.Type.HALLWAY
	grid[10][14].type = Cell.Type.ROOM
	
	generator.remove_dead_ends(grid)
	
	# The hallway should remain intact
	assert_eq(grid[10][11].type, Cell.Type.HALLWAY, "Hallway between rooms should not be removed")
	assert_eq(grid[10][12].type, Cell.Type.HALLWAY, "Hallway between rooms should not be removed")
	assert_eq(grid[10][13].type, Cell.Type.HALLWAY, "Hallway between rooms should not be removed")

## Test that junction hallways are not removed
func test_junction_hallways_not_removed() -> void:
	# Create a T-junction
	# Pattern:
	#     H
	#     H
	# R-H-H-H-R
	#     H
	grid[10][10].type = Cell.Type.ROOM
	grid[10][11].type = Cell.Type.HALLWAY
	grid[10][12].type = Cell.Type.HALLWAY  # Junction center
	grid[10][13].type = Cell.Type.HALLWAY
	grid[10][14].type = Cell.Type.ROOM
	grid[9][12].type = Cell.Type.HALLWAY
	grid[8][12].type = Cell.Type.HALLWAY
	grid[11][12].type = Cell.Type.HALLWAY
	
	generator.remove_dead_ends(grid)
	
	# Junction should remain intact
	assert_eq(grid[10][12].type, Cell.Type.HALLWAY, "Junction center should not be removed")
	assert_eq(grid[10][11].type, Cell.Type.HALLWAY, "Junction arm should not be removed")
	assert_eq(grid[10][13].type, Cell.Type.HALLWAY, "Junction arm should not be removed")

## Test that multiple dead ends are removed
func test_remove_multiple_dead_ends() -> void:
	# Create multiple dead ends
	grid[10][10].type = Cell.Type.ROOM
	grid[10][11].type = Cell.Type.HALLWAY
	grid[10][12].type = Cell.Type.HALLWAY
	
	# Dead end 1
	grid[10][13].type = Cell.Type.HALLWAY
	grid[10][14].type = Cell.Type.HALLWAY
	
	# Dead end 2 (branching from main hallway)
	grid[9][12].type = Cell.Type.HALLWAY
	grid[8][12].type = Cell.Type.HALLWAY
	
	generator.remove_dead_ends(grid)
	
	# Both dead ends should be removed
	assert_eq(grid[10][14].type, Cell.Type.EMPTY, "Dead end 1 should be removed")
	assert_eq(grid[10][13].type, Cell.Type.EMPTY, "Dead end 1 should be removed")
	assert_eq(grid[8][12].type, Cell.Type.EMPTY, "Dead end 2 should be removed")
	assert_eq(grid[9][12].type, Cell.Type.EMPTY, "Dead end 2 should be removed")

## Test that iterative removal works correctly
func test_iterative_dead_end_removal() -> void:
	# Create a long dead end that requires multiple iterations to remove
	# Pattern: R-H-H-H-H-H-H-H
	grid[10][10].type = Cell.Type.ROOM
	for x in range(11, 18):
		grid[10][x].type = Cell.Type.HALLWAY
	
	generator.remove_dead_ends(grid)
	
	# All dead end cells should be removed
	for x in range(11, 18):
		assert_eq(grid[10][x].type, Cell.Type.EMPTY, "Dead end at x=%d should be removed" % x)

## Test that hallways with two connections are preserved
func test_hallway_with_two_connections_preserved() -> void:
	# Create a hallway loop
	# Pattern:
	# R-H-H-R
	# |     |
	# H     H
	# |     |
	# H-H-H-H
	grid[10][10].type = Cell.Type.ROOM
	grid[10][11].type = Cell.Type.HALLWAY
	grid[10][12].type = Cell.Type.HALLWAY
	grid[10][13].type = Cell.Type.ROOM
	
	grid[11][10].type = Cell.Type.HALLWAY
	grid[12][10].type = Cell.Type.HALLWAY
	grid[13][10].type = Cell.Type.HALLWAY
	
	grid[11][13].type = Cell.Type.HALLWAY
	grid[12][13].type = Cell.Type.HALLWAY
	grid[13][13].type = Cell.Type.HALLWAY
	
	grid[13][11].type = Cell.Type.HALLWAY
	grid[13][12].type = Cell.Type.HALLWAY
	
	generator.remove_dead_ends(grid)
	
	# Loop should remain intact (all cells have 2+ neighbors)
	assert_eq(grid[10][11].type, Cell.Type.HALLWAY, "Loop hallway should be preserved")
	assert_eq(grid[13][11].type, Cell.Type.HALLWAY, "Loop hallway should be preserved")

## Test empty grid doesn't cause errors
func test_empty_grid_no_errors() -> void:
	# Should not crash or error on empty grid
	generator.remove_dead_ends(grid)
	
	# All cells should remain empty
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			assert_eq(grid[y][x].type, Cell.Type.EMPTY, "Empty grid should remain empty")

## Test that room cells are never removed
func test_room_cells_not_removed() -> void:
	# Create a room with a single hallway connection (looks like dead end)
	grid[10][10].type = Cell.Type.ROOM
	grid[10][11].type = Cell.Type.ROOM  # Room cell with one neighbor
	grid[10][12].type = Cell.Type.HALLWAY
	
	generator.remove_dead_ends(grid)
	
	# Room cells should never be removed
	assert_eq(grid[10][10].type, Cell.Type.ROOM, "Room cell should not be removed")
	assert_eq(grid[10][11].type, Cell.Type.ROOM, "Room cell should not be removed")
