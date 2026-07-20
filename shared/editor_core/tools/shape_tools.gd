@tool
class_name ShapeTools
extends RefCounted

signal shape_placed(blocks: Array[CSGShape3D])

enum DrawMode { RECTANGLE, CIRCLE, FILLED_CIRCLE, LINE, HOLLOW_BOX }  ## Fill rectangular area  ## Circle/ellipse outline  ## Filled circle/disk  ## Line between two points  ## Box with empty interior

var grid_system: Node = null
var editor_state: Node = null
var block_brush: BlockBrush = null
var draw_mode: DrawMode = DrawMode.RECTANGLE
var is_drawing: bool = false
var draw_start: Vector3 = Vector3.ZERO
var draw_end: Vector3 = Vector3.ZERO
var wall_thickness: int = 1
var hollow_thickness: int = 1


func setup(grid: Node, state: Node, brush: BlockBrush = null) -> void:
	grid_system = grid
	editor_state = state
	block_brush = brush


## Start drawing operation


func start_draw(world_position: Vector3) -> void:
	is_drawing = true
	draw_start = _snap_position(world_position)
	draw_end = draw_start


## Update drawing end point


func update_draw(world_position: Vector3) -> void:
	if is_drawing:
		draw_end = _snap_position(world_position)


## Finish drawing and place blocks


func finish_draw(level_root: Node3D) -> Array[CSGShape3D]:
	is_drawing = false
	var blocks: Array[CSGShape3D] = []

	match draw_mode:
		DrawMode.RECTANGLE:
			blocks = _draw_rectangle(level_root)
		DrawMode.CIRCLE:
			blocks = _draw_circle(level_root, false)
		DrawMode.FILLED_CIRCLE:
			blocks = _draw_circle(level_root, true)
		DrawMode.LINE:
			blocks = _draw_line(level_root)
		DrawMode.HOLLOW_BOX:
			blocks = _draw_hollow_box(level_root)

	if not blocks.is_empty():
		shape_placed.emit(blocks)

	return blocks


## Cancel drawing


func cancel_draw() -> void:
	is_drawing = false


## Draw filled rectangle


func _draw_rectangle(level_root: Node3D) -> Array[CSGShape3D]:
	if not grid_system:
		return []

	var blocks: Array[CSGShape3D] = []
	var cell_size: float = grid_system.cell_size

	var start_cell: Vector3i = grid_system.world_to_cell(draw_start)
	var end_cell: Vector3i = grid_system.world_to_cell(draw_end)

	var min_cell := Vector3i(
		mini(start_cell.x, end_cell.x),
		mini(start_cell.y, end_cell.y),
		mini(start_cell.z, end_cell.z)
	)
	var max_cell := Vector3i(
		maxi(start_cell.x, end_cell.x),
		maxi(start_cell.y, end_cell.y),
		maxi(start_cell.z, end_cell.z)
	)

	# Create single block covering the area
	var size := Vector3(max_cell - min_cell + Vector3i.ONE) * cell_size
	var center: Vector3 = grid_system.cell_to_world(min_cell) + size * 0.5

	var block := CSGBox3D.new()
	block.size = size
	block.position = center
	block.use_collision = true
	block.set_meta("level_editor_placed", true)
	block.set_meta("shape_tool", "rectangle")
	level_root.add_child(block)
	blocks.append(block)

	return blocks


## Draw circle outline or filled disk


func _draw_circle(level_root: Node3D, filled: bool) -> Array[CSGShape3D]:
	if not grid_system:
		return []

	var blocks: Array[CSGShape3D] = []
	var cell_size: float = grid_system.cell_size

	var start_cell: Vector3i = grid_system.world_to_cell(draw_start)
	var end_cell: Vector3i = grid_system.world_to_cell(draw_end)

	# Calculate radius from start to end
	var dx: int = abs(end_cell.x - start_cell.x)
	var dz: int = abs(end_cell.z - start_cell.z)
	var radius: int = maxi(dx, dz)

	if radius < 1:
		radius = 1

	var center_cell := start_cell

	# Use midpoint circle algorithm
	for x: int in range(-radius, radius + 1):
		for z: int in range(-radius, radius + 1):
			var dist_sq: float = x * x + z * z
			var radius_sq: float = radius * radius
			var inner_radius_sq: float = (radius - wall_thickness) * (radius - wall_thickness)

			var should_place: bool = false
			if filled:
				should_place = dist_sq <= radius_sq
			else:
				should_place = dist_sq <= radius_sq and dist_sq >= inner_radius_sq

			if should_place:
				var cell := Vector3i(center_cell.x + x, center_cell.y, center_cell.z + z)
				if not grid_system.is_cell_occupied(cell):
					var pos: Vector3 = grid_system.cell_to_world_center(cell)
					var block := CSGBox3D.new()
					block.size = Vector3.ONE * cell_size
					block.position = pos
					block.use_collision = true
					block.set_meta("level_editor_placed", true)
					block.set_meta("shape_tool", "circle")
					level_root.add_child(block)
					blocks.append(block)
					grid_system.occupy_cell(cell, block)

	return blocks


## Draw line/wall between two points


func _draw_line(level_root: Node3D) -> Array[CSGShape3D]:
	if not grid_system:
		return []

	var blocks: Array[CSGShape3D] = []
	var cell_size: float = grid_system.cell_size

	var start_cell: Vector3i = grid_system.world_to_cell(draw_start)
	var end_cell: Vector3i = grid_system.world_to_cell(draw_end)

	# Use Bresenham's line algorithm (3D version)
	var cells: Array[Vector3i] = _bresenham_line_3d(start_cell, end_cell)

	for cell: Vector3i in cells:
		if not grid_system.is_cell_occupied(cell):
			# Add thickness
			for t: int in range(wall_thickness):
				var thick_cell := cell
				# Determine perpendicular direction for thickness
				var dx: int = end_cell.x - start_cell.x
				var dz: int = end_cell.z - start_cell.z

				if abs(dx) > abs(dz):
					thick_cell.z += t
				else:
					thick_cell.x += t

				if not grid_system.is_cell_occupied(thick_cell):
					var pos: Vector3 = grid_system.cell_to_world_center(thick_cell)
					var block := CSGBox3D.new()
					block.size = Vector3.ONE * cell_size
					block.position = pos
					block.use_collision = true
					block.set_meta("level_editor_placed", true)
					block.set_meta("shape_tool", "line")
					level_root.add_child(block)
					blocks.append(block)
					grid_system.occupy_cell(thick_cell, block)

	return blocks


## Draw hollow box (walls only)


func _draw_hollow_box(level_root: Node3D) -> Array[CSGShape3D]:
	if not grid_system:
		return []

	var blocks: Array[CSGShape3D] = []
	var cell_size: float = grid_system.cell_size

	var start_cell: Vector3i = grid_system.world_to_cell(draw_start)
	var end_cell: Vector3i = grid_system.world_to_cell(draw_end)

	var min_cell := Vector3i(
		mini(start_cell.x, end_cell.x),
		mini(start_cell.y, end_cell.y),
		mini(start_cell.z, end_cell.z)
	)
	var max_cell := Vector3i(
		maxi(start_cell.x, end_cell.x),
		maxi(start_cell.y, end_cell.y),
		maxi(start_cell.z, end_cell.z)
	)

	for x: int in range(min_cell.x, max_cell.x + 1):
		for y: int in range(min_cell.y, max_cell.y + 1):
			for z: int in range(min_cell.z, max_cell.z + 1):
				# Check if on boundary
				var on_boundary: bool = (
					x < min_cell.x + hollow_thickness
					or x > max_cell.x - hollow_thickness
					or y < min_cell.y + hollow_thickness
					or y > max_cell.y - hollow_thickness
					or z < min_cell.z + hollow_thickness
					or z > max_cell.z - hollow_thickness
				)

				if on_boundary:
					var cell := Vector3i(x, y, z)
					if not grid_system.is_cell_occupied(cell):
						var pos: Vector3 = grid_system.cell_to_world_center(cell)
						var block := CSGBox3D.new()
						block.size = Vector3.ONE * cell_size
						block.position = pos
						block.use_collision = true
						block.set_meta("level_editor_placed", true)
						block.set_meta("shape_tool", "hollow_box")
						level_root.add_child(block)
						blocks.append(block)
						grid_system.occupy_cell(cell, block)

	return blocks


## Bresenham's line algorithm in 3D


func _bresenham_line_3d(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	var points: Array[Vector3i] = []

	var dx: int = abs(end.x - start.x)
	var dy: int = abs(end.y - start.y)
	var dz: int = abs(end.z - start.z)

	var sx: int = 1 if start.x < end.x else -1
	var sy: int = 1 if start.y < end.y else -1
	var sz: int = 1 if start.z < end.z else -1

	var x: int = start.x
	var y: int = start.y
	var z: int = start.z

	# Driving axis is the one with largest delta
	if dx >= dy and dx >= dz:
		var ey: int = 2 * dy - dx
		var ez: int = 2 * dz - dx
		for step_idx: int in range(dx + 1):
			points.append(Vector3i(x, y, z))
			if ey >= 0:
				y += sy
				ey -= 2 * dx
			if ez >= 0:
				z += sz
				ez -= 2 * dx
			ey += 2 * dy
			ez += 2 * dz
			x += sx
	elif dy >= dx and dy >= dz:
		var ex: int = 2 * dx - dy
		var ez: int = 2 * dz - dy
		for step_idx: int in range(dy + 1):
			points.append(Vector3i(x, y, z))
			if ex >= 0:
				x += sx
				ex -= 2 * dy
			if ez >= 0:
				z += sz
				ez -= 2 * dy
			ex += 2 * dx
			ez += 2 * dz
			y += sy
	else:
		var ex: int = 2 * dx - dz
		var ey: int = 2 * dy - dz
		for step_idx: int in range(dz + 1):
			points.append(Vector3i(x, y, z))
			if ex >= 0:
				x += sx
				ex -= 2 * dz
			if ey >= 0:
				y += sy
				ey -= 2 * dz
			ex += 2 * dx
			ey += 2 * dy
			z += sz

	return points


func _snap_position(position: Vector3) -> Vector3:
	if grid_system:
		return grid_system.snap_to_grid(position)
	return position


## Get draw preview bounds


func get_draw_bounds() -> Dictionary:
	if not is_drawing:
		return {}

	return {"start": draw_start, "end": draw_end, "mode": DrawMode.keys()[draw_mode]}


## Set wall thickness (for line and hollow modes)


func set_wall_thickness(thickness: int) -> void:
	wall_thickness = clampi(thickness, 1, 5)


## Set hollow thickness


func set_hollow_thickness(thickness: int) -> void:
	hollow_thickness = clampi(thickness, 1, 5)
