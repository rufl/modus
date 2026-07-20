class_name CellularAutomataEngine
extends RefCounted

## Cellular Automata Engine for generating organic cave and outdoor park areas
## Implements the 4-5-5 rule: birth on 4 neighbors, survive on 5+ neighbors
## Requirements: 4.2, 5.2, 5.3

const Cell = preload("res://game/scripts/map_generator/cell.gd")


## Generate cellular automata pattern in a region of the grid
## Uses 4-5-5 rule: cells with 4 neighbors are born, cells with 5+ neighbors survive
## region: The rectangular area to generate in
## grid: The 2D grid array to modify
## rng: Random number generator for deterministic generation
## cell_type: The type of cell to generate (CAVE or OUTDOOR)
## iterations: Number of CA iterations to run (4-6 recommended)
func generate_area(
	region: Rect2i,
	grid: Array[Array],
	rng: RandomNumberGenerator,
	cell_type: Cell.Type,
	iterations: int = 5
) -> void:
	# Validate inputs
	if iterations < 1:
		push_warning("CellularAutomataEngine: iterations must be >= 1, using 1")
		iterations = 1

	if cell_type not in [Cell.Type.CAVE, Cell.Type.OUTDOOR]:
		push_error("CellularAutomataEngine: cell_type must be CAVE or OUTDOOR")
		return

	# Initialize with random noise (45% filled)
	_initialize_with_noise(region, grid, rng, cell_type)

	# Run cellular automata iterations
	for iteration in range(iterations):
		_apply_ca_iteration(region, grid, cell_type)

	# Smooth edges for natural appearance
	_smooth_edges(region, grid, cell_type)


## Initialize region with random noise (45% fill rate)
func _initialize_with_noise(
	region: Rect2i, grid: Array[Array], rng: RandomNumberGenerator, cell_type: Cell.Type
) -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			# Skip if out of bounds
			if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
				continue

			# 45% chance to fill cell
			if rng.randf() < 0.45:
				grid[y][x].type = cell_type


## Apply one iteration of cellular automata using 4-5-5 rule
func _apply_ca_iteration(region: Rect2i, grid: Array[Array], cell_type: Cell.Type) -> void:
	# Create a copy of the region to avoid modifying while reading
	var new_states: Dictionary = {}  # Vector2i -> Cell.Type

	# Process each cell in the region (excluding borders)
	for y in range(region.position.y + 1, region.end.y - 1):
		for x in range(region.position.x + 1, region.end.x - 1):
			# Skip if out of bounds
			if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
				continue

			var alive_neighbors := _count_alive_neighbors(grid, x, y, cell_type)
			var pos := Vector2i(x, y)

			# 4-5-5 rule: birth on 4, survive on 5+
			if grid[y][x].type == cell_type:
				# Cell is alive - survives if 5+ neighbors
				new_states[pos] = cell_type if alive_neighbors >= 5 else Cell.Type.EMPTY
			else:
				# Cell is dead - born if 4+ neighbors
				new_states[pos] = cell_type if alive_neighbors >= 4 else Cell.Type.EMPTY

	# Apply new states
	for pos: Vector2i in new_states:
		if pos.y >= 0 and pos.y < grid.size() and pos.x >= 0 and pos.x < grid[pos.y].size():
			grid[pos.y][pos.x].type = new_states[pos]


## Count alive neighbors in 8 directions
func _count_alive_neighbors(grid: Array[Array], x: int, y: int, cell_type: Cell.Type) -> int:
	var count := 0

	# Check all 8 directions
	var directions := [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),  # Top row
		Vector2i(-1, 0),
		Vector2i(1, 0),  # Middle row
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 1)  # Bottom row
	]

	for dir: Vector2i in directions:
		var nx: int = x + dir.x
		var ny: int = y + dir.y

		# Check bounds
		if ny >= 0 and ny < grid.size() and nx >= 0 and nx < grid[ny].size():
			if grid[ny][nx].type == cell_type:
				count += 1

	return count


## Smooth edges for natural appearance
## Removes single isolated cells and fills single-cell gaps
func _smooth_edges(region: Rect2i, grid: Array[Array], cell_type: Cell.Type) -> void:
	var changes: Dictionary = {}  # Vector2i -> Cell.Type

	# Process each cell in the region
	for y in range(region.position.y + 1, region.end.y - 1):
		for x in range(region.position.x + 1, region.end.x - 1):
			# Skip if out of bounds
			if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
				continue

			var alive_neighbors := _count_alive_neighbors(grid, x, y, cell_type)
			var pos := Vector2i(x, y)

			# Remove isolated cells (0-2 neighbors)
			if grid[y][x].type == cell_type and alive_neighbors <= 2:
				changes[pos] = Cell.Type.EMPTY

			# Fill small gaps (6+ neighbors)
			elif grid[y][x].type != cell_type and alive_neighbors >= 6:
				changes[pos] = cell_type

	# Apply changes
	for pos: Vector2i in changes:
		if pos.y >= 0 and pos.y < grid.size() and pos.x >= 0 and pos.x < grid[pos.y].size():
			grid[pos.y][pos.x].type = changes[pos]
