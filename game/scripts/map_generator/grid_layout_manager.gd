class_name GridLayoutManager
extends RefCounted

## Manages the 2D grid representation of the map layout
## Provides spatial queries, connectivity analysis, and grid validation utilities

# Preload Cell class
const Cell = preload("res://game/scripts/map_generator/cell.gd")

# Grid data
var grid: Array[Array] = []
var grid_size: Vector2i = Vector2i.ZERO


## Initialize grid with specified dimensions
## Supports sizes: 64×64, 128×128, 256×256
func initialize_grid(size: Vector2i) -> void:
	grid_size = size
	grid.clear()

	# Initialize 2D array of Cell objects
	for y in range(grid_size.y):
		var row: Array[Cell] = []
		row.resize(grid_size.x)
		for x in range(grid_size.x):
			row[x] = Cell.new(Cell.Type.EMPTY)
		grid.append(row)


## Get cell at specified grid position with bounds checking
## Returns null if position is out of bounds
func get_cell_at(pos: Vector2i) -> Cell:
	if not is_valid_position(pos):
		return null
	return grid[pos.y][pos.x]


## Check if a grid position is within bounds
func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y


## Get neighboring cells in 4 directions (N, S, E, W)
## Returns array of Vector2i positions
func get_neighbors_4(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	# North, South, East, West
	var directions := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

	for dir: Vector2i in directions:
		var neighbor_pos: Vector2i = pos + dir
		if is_valid_position(neighbor_pos):
			neighbors.append(neighbor_pos)

	return neighbors


## Get neighboring cells in 8 directions (N, S, E, W, NE, NW, SE, SW)
## Returns array of Vector2i positions
func get_neighbors_8(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions := [
		Vector2i(0, -1),  # North
		Vector2i(0, 1),  # South
		Vector2i(1, 0),  # East
		Vector2i(-1, 0),  # West
		Vector2i(1, -1),  # Northeast
		Vector2i(-1, -1),  # Northwest
		Vector2i(1, 1),  # Southeast
		Vector2i(-1, 1)  # Southwest
	]

	for dir: Vector2i in directions:
		var neighbor_pos: Vector2i = pos + dir
		if is_valid_position(neighbor_pos):
			neighbors.append(neighbor_pos)

	return neighbors


## Flood fill algorithm for connectivity analysis
## Returns array of all connected positions starting from start_pos
## Only considers cells matching the filter_func predicate
func flood_fill(start_pos: Vector2i, filter_func: Callable) -> Array[Vector2i]:
	if not is_valid_position(start_pos):
		return []

	var start_cell: Cell = get_cell_at(start_pos)
	if not filter_func.call(start_cell):
		return []

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_pos]
	var result: Array[Vector2i] = []

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()

		if visited.has(current):
			continue

		visited[current] = true
		result.append(current)

		# Check 4-directional neighbors
		for neighbor_pos in get_neighbors_4(current):
			if not visited.has(neighbor_pos):
				var neighbor_cell: Cell = get_cell_at(neighbor_pos)
				if filter_func.call(neighbor_cell):
					queue.append(neighbor_pos)

	return result


## Count total walkable cells in the grid
## Walkable cells are: ROOM, HALLWAY, OUTDOOR, CAVE, BOSS_ARENA, SECRET
func count_walkable_cells() -> int:
	var count := 0

	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell: Cell = grid[y][x]
			if is_walkable_cell(cell):
				count += 1

	return count


## Check if a cell is walkable
func is_walkable_cell(cell: Cell) -> bool:
	return (
		cell.type
		in [
			Cell.Type.ROOM,
			Cell.Type.HALLWAY,
			Cell.Type.OUTDOOR,
			Cell.Type.CAVE,
			Cell.Type.BOSS_ARENA,
			Cell.Type.SECRET
		]
	)


## Count open (walkable) neighbors for a given position
## Used for dead-end detection
func count_open_neighbors(pos: Vector2i) -> int:
	var count := 0

	for neighbor_pos in get_neighbors_4(pos):
		var neighbor_cell := get_cell_at(neighbor_pos)
		if neighbor_cell and is_walkable_cell(neighbor_cell):
			count += 1

	return count


## Get all walkable neighbor positions (4-directional)
func get_walkable_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var walkable: Array[Vector2i] = []

	for neighbor_pos in get_neighbors_4(pos):
		var neighbor_cell := get_cell_at(neighbor_pos)
		if neighbor_cell and is_walkable_cell(neighbor_cell):
			walkable.append(neighbor_pos)

	return walkable


## Find path between two positions using A* pathfinding algorithm
## Uses Manhattan distance heuristic for optimal pathfinding on grid
## Returns array of Vector2i positions from start to goal (inclusive)
## Returns empty array if no path found
func find_hallway_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not is_valid_position(start) or not is_valid_position(goal):
		return []
	if not is_walkable_cell(get_cell_at(start)) or not is_walkable_cell(get_cell_at(goal)):
		return []

	# Priority queue implemented as array (sorted by f_score)
	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}  # pos -> previous pos
	var g_score: Dictionary = {start: 0}  # pos -> cost from start
	var f_score: Dictionary = {start: _heuristic(start, goal)}  # pos -> estimated total cost

	while not open_set.is_empty():
		# Get node with lowest f_score
		var current := _get_lowest_f_score(open_set, f_score)

		# Goal reached - reconstruct path
		if current == goal:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		# Check all walkable neighbors
		for neighbor in get_neighbors_4(current):
			if not is_walkable_cell(get_cell_at(neighbor)):
				continue

			# Calculate tentative g_score
			var tentative_g_score: float = g_score[current] + 1

			# If this path to neighbor is better than any previous one
			if tentative_g_score < g_score.get(neighbor, INF):
				# This path is the best so far - record it
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + _heuristic(neighbor, goal)

				# Add neighbor to open set if not already there
				if neighbor not in open_set:
					open_set.append(neighbor)

	# No path found
	return []


## Manhattan distance heuristic for A* pathfinding
## Optimal for grid-based movement with 4-directional movement
func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Get position with lowest f_score from open set
func _get_lowest_f_score(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var lowest_pos: Vector2i = open_set[0]
	var lowest_score: float = f_score.get(lowest_pos, INF)

	for pos: Vector2i in open_set:
		var score: float = f_score.get(pos, INF)
		if score < lowest_score:
			lowest_score = score
			lowest_pos = pos

	return lowest_pos


## Reconstruct path from came_from dictionary
func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]

	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)

	return path
