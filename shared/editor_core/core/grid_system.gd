@tool
class_name GridSystem
extends Node

signal grid_size_changed(cell_size: float)
signal grid_visibility_changed(visible: bool)

@export var cell_size: float = 1.0
@export var show_grid: bool = true
@export var grid_extent: int = 50
@export var grid_levels: int = 10

var current_height_level: int = 0
var occupied_cells: Dictionary = {}


func _ready() -> void:
	# Exported defaults and empty occupancy state require no runtime initialization.
	pass


## Snap a world position to the grid


func snap_to_grid(world_pos: Vector3) -> Vector3:
	return Vector3(
		snappedf(world_pos.x, cell_size),
		snappedf(world_pos.y, cell_size),
		snappedf(world_pos.z, cell_size)
	)


## Snap to grid and offset to cell center


func snap_to_cell_center(world_pos: Vector3) -> Vector3:
	var snapped := snap_to_grid(world_pos)
	return snapped + Vector3(cell_size, cell_size, cell_size) * 0.5


## Convert world position to grid cell coordinates


func world_to_cell(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / cell_size),
		floori(world_pos.y / cell_size),
		floori(world_pos.z / cell_size)
	)


## Convert grid cell coordinates to world position (cell corner)


func cell_to_world(cell: Vector3i) -> Vector3:
	return Vector3(cell) * cell_size


## Convert grid cell coordinates to world position (cell center)


func cell_to_world_center(cell: Vector3i) -> Vector3:
	return cell_to_world(cell) + Vector3(cell_size, cell_size, cell_size) * 0.5


## Get cell size


func get_cell_size() -> float:
	return cell_size


## Set cell size


func set_cell_size(size: float) -> void:
	cell_size = size


## Toggle grid visibility


func toggle_grid() -> void:
	show_grid = not show_grid


## Increase grid cell size


func increase_cell_size() -> void:
	cell_size = minf(cell_size * 2.0, 4.0)


## Decrease grid cell size


func decrease_cell_size() -> void:
	cell_size = maxf(cell_size * 0.5, 0.25)


## Change current height level


func set_height_level(level: int) -> void:
	current_height_level = clampi(level, 0, grid_levels - 1)


## Get current height level in world coordinates


func get_current_height() -> float:
	return current_height_level * cell_size


## Check if a cell is occupied


func is_cell_occupied(cell: Vector3i) -> bool:
	return occupied_cells.has(cell)


## Mark a cell as occupied by a node


func occupy_cell(cell: Vector3i, node: Node) -> void:
	occupied_cells[cell] = node


## Mark multiple cells as occupied (for multi-cell objects)


func occupy_cells(cells: Array[Vector3i], node: Node) -> void:
	for cell in cells:
		occupy_cell(cell, node)


## Free a cell


func free_cell(cell: Vector3i) -> void:
	occupied_cells.erase(cell)


## Free multiple cells


func free_cells(cells: Array[Vector3i]) -> void:
	for cell in cells:
		free_cell(cell)


## Get the node occupying a cell


func get_occupant(cell: Vector3i) -> Node:
	return occupied_cells.get(cell, null)


## Clear all occupancy data


func clear_occupancy() -> void:
	occupied_cells.clear()


## Get cells in a box region


func get_cells_in_box(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []

	var min_cell := Vector3i(mini(start.x, end.x), mini(start.y, end.y), mini(start.z, end.z))
	var max_cell := Vector3i(maxi(start.x, end.x), maxi(start.y, end.y), maxi(start.z, end.z))

	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for z in range(min_cell.z, max_cell.z + 1):
				cells.append(Vector3i(x, y, z))

	return cells


## Check if a box region has any occupied cells


func is_region_occupied(start: Vector3i, end: Vector3i) -> bool:
	for cell in get_cells_in_box(start, end):
		if is_cell_occupied(cell):
			return true
	return false


## Get grid lines for rendering (returns array of line segment pairs)


func get_grid_lines(center: Vector3, extent: float) -> PackedVector3Array:
	var lines := PackedVector3Array()
	var half_extent := extent * cell_size
	var height := current_height_level * cell_size

	# Snap center to grid
	var grid_center := snap_to_grid(center)

	# Generate X-axis lines
	for i in range(-int(extent), int(extent) + 1):
		var x := grid_center.x + i * cell_size
		lines.append(Vector3(x, height, grid_center.z - half_extent))
		lines.append(Vector3(x, height, grid_center.z + half_extent))

	# Generate Z-axis lines
	for i in range(-int(extent), int(extent) + 1):
		var z := grid_center.z + i * cell_size
		lines.append(Vector3(grid_center.x - half_extent, height, z))
		lines.append(Vector3(grid_center.x + half_extent, height, z))

	return lines
