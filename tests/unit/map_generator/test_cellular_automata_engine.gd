extends GutTest

## Unit tests for CellularAutomataEngine
## Tests the 4-5-5 cellular automata rule implementation

const CellularAutomataEngine = preload(
	"res://game/scripts/map_generator/cellular_automata_engine.gd"
)
const Cell = preload("res://game/scripts/map_generator/cell.gd")

var engine: CellularAutomataEngine
var rng: RandomNumberGenerator

func before_each():
	engine = CellularAutomataEngine.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for deterministic tests

func test_generate_area_creates_cave_cells():
	# Arrange
	var grid_size := Vector2i(20, 20)
	var grid := _create_empty_grid(grid_size)
	var region := Rect2i(5, 5, 10, 10)

	# Act
	engine.generate_area(region, grid, rng, Cell.Type.CAVE, 5)

	# Assert - should have some cave cells in the region
	var cave_count := _count_cells_in_region(grid, region, Cell.Type.CAVE)
	assert_gt(cave_count, 0, "Should generate at least some cave cells")

func test_generate_area_creates_outdoor_cells():
	# Arrange
	var grid_size := Vector2i(20, 20)
	var grid := _create_empty_grid(grid_size)
	var region := Rect2i(5, 5, 10, 10)

	# Act
	engine.generate_area(region, grid, rng, Cell.Type.OUTDOOR, 5)

	# Assert - should have some outdoor cells in the region
	var outdoor_count := _count_cells_in_region(grid, region, Cell.Type.OUTDOOR)
	assert_gt(outdoor_count, 0, "Should generate at least some outdoor cells")

func test_generate_area_respects_region_bounds():
	# Arrange
	var grid_size := Vector2i(20, 20)
	var grid := _create_empty_grid(grid_size)
	var region := Rect2i(5, 5, 10, 10)

	# Act
	engine.generate_area(region, grid, rng, Cell.Type.CAVE, 5)

	# Assert - cells outside region should remain empty
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var pos := Vector2i(x, y)
			if not region.has_point(pos):
				assert_eq(grid[y][x].type, Cell.Type.EMPTY,
					"Cells outside region should remain empty at (%d, %d)" % [x, y])

func test_generate_area_with_zero_iterations_warns():
	# Arrange
	var grid_size := Vector2i(20, 20)
	var grid := _create_empty_grid(grid_size)
	var region := Rect2i(5, 5, 10, 10)

	# Act & Assert - should handle gracefully
	engine.generate_area(region, grid, rng, Cell.Type.CAVE, 0)
	# Should still generate something (uses 1 iteration minimum)
	var cave_count := _count_cells_in_region(grid, region, Cell.Type.CAVE)
	assert_gt(cave_count, 0, "Should generate cells even with 0 iterations (uses minimum 1)")

func test_generate_area_with_invalid_cell_type_errors():
	# Arrange
	var grid_size := Vector2i(20, 20)
	var grid := _create_empty_grid(grid_size)
	var region := Rect2i(5, 5, 10, 10)

	# Act
	engine.generate_area(region, grid, rng, Cell.Type.ROOM, 5)
	assert_push_error("cell_type must be CAVE or OUTDOOR")

	# Assert - should not generate any cells
	var room_count := _count_cells_in_region(grid, region, Cell.Type.ROOM)
	assert_eq(room_count, 0, "Should not generate cells with invalid type")

func test_deterministic_generation_with_same_seed():
	# Arrange
	var grid_size := Vector2i(20, 20)
	var region := Rect2i(5, 5, 10, 10)

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	var grid1 := _create_empty_grid(grid_size)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var grid2 := _create_empty_grid(grid_size)

	# Act
	engine.generate_area(region, grid1, rng1, Cell.Type.CAVE, 5)
	engine.generate_area(region, grid2, rng2, Cell.Type.CAVE, 5)

	# Assert - grids should be identical
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			assert_eq(grid1[y][x].type, grid2[y][x].type,
				"Grids should be identical with same seed at (%d, %d)" % [x, y])

func test_ca_iterations_create_organic_shapes():
	# Arrange
	var grid_size := Vector2i(30, 30)
	var grid := _create_empty_grid(grid_size)
	var region := Rect2i(5, 5, 20, 20)

	# Act
	engine.generate_area(region, grid, rng, Cell.Type.CAVE, 6)

	# Assert - should have clusters (not just random noise)
	# Check that cells tend to be near other cells
	var clustered_cells := 0
	var total_cells := 0

	for y in range(region.position.y + 1, region.end.y - 1):
		for x in range(region.position.x + 1, region.end.x - 1):
			if grid[y][x].type == Cell.Type.CAVE:
				total_cells += 1
				# Count neighbors
				var neighbors := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dy == 0 and dx == 0:
							continue
						if grid[y + dy][x + dx].type == Cell.Type.CAVE:
							neighbors += 1

				# If cell has 3+ neighbors, it's part of a cluster
				if neighbors >= 3:
					clustered_cells += 1

	# Most cells should be clustered (organic shapes)
	if total_cells > 0:
		var cluster_ratio := float(clustered_cells) / float(total_cells)
		assert_gt(cluster_ratio, 0.5, "Most cells should be clustered (organic shapes)")

func test_edge_smoothing_removes_isolated_cells():
	# Arrange
	var grid_size := Vector2i(10, 10)
	var grid := _create_empty_grid(grid_size)
	var region := Rect2i(0, 0, 10, 10)

	# Create an isolated cell
	grid[5][5].type = Cell.Type.CAVE

	# Act - smooth edges
	engine._smooth_edges(region, grid, Cell.Type.CAVE)

	# Assert - isolated cell should be removed
	assert_eq(grid[5][5].type, Cell.Type.EMPTY, "Isolated cell should be removed")

func test_edge_smoothing_fills_small_gaps():
	# Arrange
	var grid_size := Vector2i(10, 10)
	var grid := _create_empty_grid(grid_size)
	var region := Rect2i(0, 0, 10, 10)

	# Create a gap surrounded by cells (6+ neighbors)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dy == 0 and dx == 0:
				continue
			grid[5 + dy][5 + dx].type = Cell.Type.CAVE

	# Center cell is empty but surrounded
	grid[5][5].type = Cell.Type.EMPTY

	# Act - smooth edges
	engine._smooth_edges(region, grid, Cell.Type.CAVE)

	# Assert - gap should be filled
	assert_eq(grid[5][5].type, Cell.Type.CAVE, "Small gap should be filled")

## Helper: Create empty grid
func _create_empty_grid(size: Vector2i) -> Array[Array]:
	var grid: Array[Array] = []
	for y in range(size.y):
		var row: Array[Cell] = []
		row.resize(size.x)
		for x in range(size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		grid.append(row)
	return grid

## Helper: Count cells of a specific type in a region
func _count_cells_in_region(grid: Array[Array], region: Rect2i, cell_type: Cell.Type) -> int:
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if y >= 0 and y < grid.size() and x >= 0 and x < grid[y].size():
				if grid[y][x].type == cell_type:
					count += 1
	return count
