extends ModusGutTestBase

## Unit tests for GridLayoutManager
## Tests Requirements 1.1, 1.2, 1.4, 3.3, 13.4, 34.2, 34.3

const GridLayoutManager = preload("res://game/scripts/map_generator/grid_layout_manager.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")

var grid_manager: GridLayoutManager


func before_each() -> void:
	grid_manager = GridLayoutManager.new()


func after_each() -> void:
	grid_manager = null


## Test grid initialization with 64×64 size
func test_initialize_grid_64x64() -> void:
	var size := Vector2i(64, 64)
	grid_manager.initialize_grid(size)

	assert_eq(grid_manager.grid_size, size, "Grid size should be set correctly")
	assert_eq(grid_manager.grid.size(), 64, "Grid should have 64 rows")
	assert_eq(grid_manager.grid[0].size(), 64, "Each row should have 64 cells")


## Test grid initialization with 128×128 size
func test_initialize_grid_128x128() -> void:
	var size := Vector2i(128, 128)
	grid_manager.initialize_grid(size)

	assert_eq(grid_manager.grid_size, size, "Grid size should be set correctly")
	assert_eq(grid_manager.grid.size(), 128, "Grid should have 128 rows")
	assert_eq(grid_manager.grid[0].size(), 128, "Each row should have 128 cells")


## Test grid initialization with 256×256 size
func test_initialize_grid_256x256() -> void:
	var size := Vector2i(256, 256)
	grid_manager.initialize_grid(size)

	assert_eq(grid_manager.grid_size, size, "Grid size should be set correctly")
	assert_eq(grid_manager.grid.size(), 256, "Grid should have 256 rows")
	assert_eq(grid_manager.grid[0].size(), 256, "Each row should have 256 cells")


## Test that all cells are initialized as EMPTY
func test_cells_initialized_as_empty() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	for y in range(64):
		for x in range(64):
			var cell: Cell = grid_manager.grid[y][x]
			assert_not_null(cell, "Cell at (%d, %d) should not be null" % [x, y])
			assert_eq(cell.type, Cell.Type.EMPTY, "Cell at (%d, %d) should be EMPTY" % [x, y])


## Test get_cell_at with valid position
func test_get_cell_at_valid_position() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	var pos := Vector2i(10, 20)
	var cell := grid_manager.get_cell_at(pos)

	assert_not_null(cell, "Should return cell at valid position")
	assert_eq(cell.type, Cell.Type.EMPTY, "Cell should be EMPTY initially")


## Test get_cell_at with out of bounds position
func test_get_cell_at_out_of_bounds() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	var invalid_positions := [
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(64, 0), Vector2i(0, 64), Vector2i(100, 100)
	]

	for pos in invalid_positions:
		var cell := grid_manager.get_cell_at(pos)
		assert_null(cell, "Should return null for out of bounds position %s" % pos)


## Test is_valid_position
func test_is_valid_position() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	# Valid positions
	assert_true(grid_manager.is_valid_position(Vector2i(0, 0)), "Top-left corner should be valid")
	assert_true(
		grid_manager.is_valid_position(Vector2i(63, 63)), "Bottom-right corner should be valid"
	)
	assert_true(grid_manager.is_valid_position(Vector2i(32, 32)), "Center should be valid")

	# Invalid positions
	assert_false(grid_manager.is_valid_position(Vector2i(-1, 0)), "Negative x should be invalid")
	assert_false(grid_manager.is_valid_position(Vector2i(0, -1)), "Negative y should be invalid")
	assert_false(grid_manager.is_valid_position(Vector2i(64, 0)), "x >= size should be invalid")
	assert_false(grid_manager.is_valid_position(Vector2i(0, 64)), "y >= size should be invalid")


## Test get_neighbors_4 returns correct 4-directional neighbors
func test_get_neighbors_4_center_position() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	var pos := Vector2i(32, 32)
	var neighbors := grid_manager.get_neighbors_4(pos)

	assert_eq(neighbors.size(), 4, "Center position should have 4 neighbors")

	var expected := [
		# North
		Vector2i(32, 31),
		# South
		Vector2i(32, 33),
		# East
		Vector2i(33, 32),
		# West
		Vector2i(31, 32)
	]

	for expected_pos in expected:
		assert_true(neighbors.has(expected_pos), "Should include neighbor at %s" % expected_pos)


## Test get_neighbors_4 at corner returns only valid neighbors
func test_get_neighbors_4_corner_position() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	var pos := Vector2i(0, 0)  # Top-left corner
	var neighbors := grid_manager.get_neighbors_4(pos)

	assert_eq(neighbors.size(), 2, "Corner position should have 2 neighbors")
	assert_true(neighbors.has(Vector2i(1, 0)), "Should include right neighbor")
	assert_true(neighbors.has(Vector2i(0, 1)), "Should include bottom neighbor")


## Test get_neighbors_8 returns correct 8-directional neighbors
func test_get_neighbors_8_center_position() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	var pos := Vector2i(32, 32)
	var neighbors := grid_manager.get_neighbors_8(pos)

	assert_eq(neighbors.size(), 8, "Center position should have 8 neighbors")

	var expected := [
		Vector2i(32, 31),  # North
		Vector2i(32, 33),  # South
		Vector2i(33, 32),  # East
		Vector2i(31, 32),  # West
		Vector2i(33, 31),  # Northeast
		Vector2i(31, 31),  # Northwest
		Vector2i(33, 33),  # Southeast
		Vector2i(31, 33)  # Southwest
	]

	for expected_pos in expected:
		assert_true(neighbors.has(expected_pos), "Should include neighbor at %s" % expected_pos)


## Test get_neighbors_8 at corner returns only valid neighbors
func test_get_neighbors_8_corner_position() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	var pos := Vector2i(0, 0)  # Top-left corner
	var neighbors := grid_manager.get_neighbors_8(pos)

	assert_eq(neighbors.size(), 3, "Corner position should have 3 neighbors")
	assert_true(neighbors.has(Vector2i(1, 0)), "Should include right neighbor")
	assert_true(neighbors.has(Vector2i(0, 1)), "Should include bottom neighbor")
	assert_true(neighbors.has(Vector2i(1, 1)), "Should include diagonal neighbor")


## Test flood_fill finds all connected cells
func test_flood_fill_connected_region() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Create a 3×3 room region
	for y in range(4, 7):
		for x in range(4, 7):
			grid_manager.grid[y][x].type = Cell.Type.ROOM

	var start_pos := Vector2i(5, 5)
	var filter_func := func(cell: Cell) -> bool: return cell.type == Cell.Type.ROOM

	var connected := grid_manager.flood_fill(start_pos, filter_func)

	assert_eq(connected.size(), 9, "Should find all 9 connected room cells")


## Test flood_fill stops at boundaries
func test_flood_fill_with_boundaries() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Create two separate room regions
	for x in range(2, 5):
		grid_manager.grid[5][x].type = Cell.Type.ROOM

	for x in range(6, 9):
		grid_manager.grid[5][x].type = Cell.Type.ROOM

	var start_pos := Vector2i(3, 5)
	var filter_func := func(cell: Cell) -> bool: return cell.type == Cell.Type.ROOM

	var connected := grid_manager.flood_fill(start_pos, filter_func)

	assert_eq(connected.size(), 3, "Should only find first region (3 cells)")
	assert_false(connected.has(Vector2i(6, 5)), "Should not reach second region")


## Test count_walkable_cells with empty grid
func test_count_walkable_cells_empty_grid() -> void:
	grid_manager.initialize_grid(Vector2i(64, 64))

	var count := grid_manager.count_walkable_cells()

	assert_eq(count, 0, "Empty grid should have 0 walkable cells")


## Test count_walkable_cells with mixed cell types
func test_count_walkable_cells_mixed_types() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Set various walkable cell types
	grid_manager.grid[0][0].type = Cell.Type.ROOM
	grid_manager.grid[0][1].type = Cell.Type.HALLWAY
	grid_manager.grid[0][2].type = Cell.Type.OUTDOOR
	grid_manager.grid[0][3].type = Cell.Type.CAVE
	grid_manager.grid[0][4].type = Cell.Type.BOSS_ARENA
	grid_manager.grid[0][5].type = Cell.Type.SECRET
	# Rest remain EMPTY

	var count := grid_manager.count_walkable_cells()

	assert_eq(count, 6, "Should count all walkable cell types")


## Test is_walkable_cell for all cell types
func test_is_walkable_cell() -> void:
	var walkable_types := [
		Cell.Type.ROOM,
		Cell.Type.HALLWAY,
		Cell.Type.OUTDOOR,
		Cell.Type.CAVE,
		Cell.Type.BOSS_ARENA,
		Cell.Type.SECRET
	]

	for cell_type in walkable_types:
		var cell := Cell.new(cell_type)
		assert_true(
			grid_manager.is_walkable_cell(cell), "Cell type %s should be walkable" % cell_type
		)

	var empty_cell := Cell.new(Cell.Type.EMPTY)
	assert_false(grid_manager.is_walkable_cell(empty_cell), "EMPTY cell should not be walkable")


## Test count_open_neighbors for dead-end detection
func test_count_open_neighbors_dead_end() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Create a hallway dead-end: H-H-H
	grid_manager.grid[5][5].type = Cell.Type.HALLWAY
	grid_manager.grid[5][6].type = Cell.Type.HALLWAY
	grid_manager.grid[5][7].type = Cell.Type.HALLWAY

	# End cell should have 1 open neighbor (dead-end)
	var end_count := grid_manager.count_open_neighbors(Vector2i(7, 5))
	assert_eq(end_count, 1, "Dead-end should have 1 open neighbor")

	# Middle cell should have 2 open neighbors
	var middle_count := grid_manager.count_open_neighbors(Vector2i(6, 5))
	assert_eq(middle_count, 2, "Middle cell should have 2 open neighbors")


## Test count_open_neighbors at junction
func test_count_open_neighbors_junction() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Create a junction: cross pattern
	grid_manager.grid[5][5].type = Cell.Type.HALLWAY  # Center
	grid_manager.grid[4][5].type = Cell.Type.HALLWAY  # North
	grid_manager.grid[6][5].type = Cell.Type.HALLWAY  # South
	grid_manager.grid[5][4].type = Cell.Type.HALLWAY  # West
	grid_manager.grid[5][6].type = Cell.Type.HALLWAY  # East

	var junction_count := grid_manager.count_open_neighbors(Vector2i(5, 5))
	assert_eq(junction_count, 4, "Junction should have 4 open neighbors")


## Test get_walkable_neighbors returns only walkable positions
func test_get_walkable_neighbors() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Create mixed environment
	grid_manager.grid[5][5].type = Cell.Type.ROOM
	grid_manager.grid[4][5].type = Cell.Type.HALLWAY  # North - walkable
	grid_manager.grid[6][5].type = Cell.Type.EMPTY  # South - not walkable
	grid_manager.grid[5][4].type = Cell.Type.ROOM  # West - walkable
	grid_manager.grid[5][6].type = Cell.Type.EMPTY  # East - not walkable

	var walkable := grid_manager.get_walkable_neighbors(Vector2i(5, 5))

	assert_eq(walkable.size(), 2, "Should have 2 walkable neighbors")
	assert_true(walkable.has(Vector2i(5, 4)), "Should include north neighbor")
	assert_true(walkable.has(Vector2i(4, 5)), "Should include west neighbor")


## Test flood_fill with invalid start position
func test_flood_fill_invalid_start() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	var filter_func := func(cell: Cell) -> bool: return cell.type == Cell.Type.ROOM

	var result := grid_manager.flood_fill(Vector2i(-1, -1), filter_func)

	assert_eq(result.size(), 0, "Should return empty array for invalid start position")


## Test flood_fill with start position not matching filter
func test_flood_fill_start_not_matching_filter() -> void:
	grid_manager.initialize_grid(Vector2i(10, 10))

	# Start position is EMPTY
	var start_pos := Vector2i(5, 5)
	var filter_func := func(cell: Cell) -> bool: return cell.type == Cell.Type.ROOM

	var result := grid_manager.flood_fill(start_pos, filter_func)

	assert_eq(result.size(), 0, "Should return empty array when start doesn't match filter")
