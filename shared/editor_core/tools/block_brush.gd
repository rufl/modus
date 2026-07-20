@tool
class_name BlockBrush
extends RefCounted

signal block_placed(block: CSGShape3D)

enum BlockType { BOX, CYLINDER, RAMP, STAIRS, WEDGE, ARCH, SPHERE }  ## Stepped staircase  ## Angled wedge/slope  ## Curved arch segment  ## Spherical shape

var grid_system: Node = null
var editor_state: Node = null
var current_material: Material = null
var block_size: Vector3i = Vector3i.ONE
var is_dragging: bool = false
var drag_start: Vector3 = Vector3.ZERO
var drag_end: Vector3 = Vector3.ZERO
var auto_merge: bool = false
var block_type: BlockType = BlockType.BOX
var stair_steps: int = 4
var stair_direction: Vector3 = Vector3.FORWARD


func setup(grid: Node, state: Node) -> void:
	grid_system = grid
	editor_state = state


## Set the material for new blocks


func set_material(material: Material) -> void:
	current_material = material


## Set block size in cells


func set_size(size: Vector3i) -> void:
	block_size = size.clamp(Vector3i.ONE, Vector3i(10, 10, 10))


## Start drag placement


func start_drag(world_position: Vector3) -> void:
	is_dragging = true
	drag_start = _snap_position(world_position)
	drag_end = drag_start


## Update drag end point


func update_drag(world_position: Vector3) -> void:
	if is_dragging:
		drag_end = _snap_position(world_position)


## Finish drag and place block(s)


func finish_drag(level_root: Node3D) -> Array[CSGShape3D]:
	is_dragging = false
	return _place_blocks_in_range(drag_start, drag_end, level_root)


## Cancel drag


func cancel_drag() -> void:
	is_dragging = false


## Place a single block at position


func place_block(world_position: Vector3, level_root: Node3D) -> CSGShape3D:
	var snapped := _snap_position(world_position)
	return _create_block(snapped, level_root)


func _place_blocks_in_range(start: Vector3, end: Vector3, level_root: Node3D) -> Array[CSGShape3D]:
	var blocks: Array[CSGShape3D] = []

	if not grid_system:
		var block := _create_block(start, level_root)
		if block:
			blocks.append(block)
		return blocks

	var cell_size: float = grid_system.cell_size
	var start_cell: Vector3i = grid_system.world_to_cell(start)
	var end_cell: Vector3i = grid_system.world_to_cell(end)

	# Calculate actual block dimensions
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

	# Create single stretched block or multiple blocks
	if auto_merge:
		# Create one large block
		var size := Vector3(max_cell - min_cell + Vector3i.ONE) * cell_size
		var center: Vector3 = grid_system.cell_to_world(min_cell) + size * 0.5
		var block := _create_block_at(center, size, level_root)
		if block:
			blocks.append(block)
			# Mark all cells as occupied
			for x in range(min_cell.x, max_cell.x + 1):
				for y in range(min_cell.y, max_cell.y + 1):
					for z in range(min_cell.z, max_cell.z + 1):
						grid_system.occupy_cell(Vector3i(x, y, z), block)
	else:
		# Create individual blocks
		for x in range(min_cell.x, max_cell.x + 1):
			for y in range(min_cell.y, max_cell.y + 1):
				for z in range(min_cell.z, max_cell.z + 1):
					var cell: Vector3i = Vector3i(x, y, z)
					if not grid_system.is_cell_occupied(cell):
						var pos: Vector3 = grid_system.cell_to_world_center(cell)
						var block := _create_block(pos, level_root)
						if block:
							blocks.append(block)

	return blocks


func _create_block(position: Vector3, level_root: Node3D) -> CSGShape3D:
	var cell_size: float = 1.0
	if grid_system:
		cell_size = grid_system.cell_size

	var size := Vector3(block_size) * cell_size
	return _create_block_at(position, size, level_root)


func _create_block_at(position: Vector3, size: Vector3, level_root: Node3D) -> CSGShape3D:
	if not level_root:
		return null

	var block: CSGShape3D

	match block_type:
		BlockType.BOX:
			var box := CSGBox3D.new()
			box.size = size
			block = box
		BlockType.CYLINDER:
			var cyl := CSGCylinder3D.new()
			cyl.radius = minf(size.x, size.z) * 0.5
			cyl.height = size.y
			block = cyl
		BlockType.RAMP:
			# Create ramp using CSGPolygon
			var poly := CSGPolygon3D.new()
			poly.polygon = PackedVector2Array(
				[
					Vector2(0, 0),
					Vector2(size.x, 0),
					Vector2(size.x, size.y),
				]
			)
			poly.depth = size.z
			block = poly

		BlockType.STAIRS:
			# Create stairs as combined node
			block = _create_stairs(size)

		BlockType.WEDGE:
			# Create angled wedge
			block = _create_wedge(size)

		BlockType.ARCH:
			# Create curved arch
			block = _create_arch(size)

		BlockType.SPHERE:
			# Create sphere
			var sphere := CSGSphere3D.new()
			sphere.radius = minf(minf(size.x, size.y), size.z) * 0.5
			block = sphere

	block.position = position
	block.use_collision = true

	if current_material:
		block.material = current_material

	# Mark as editor-placed
	block.set_meta("level_editor_placed", true)

	# Use undo/redo
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Place Block")

	undo.add_do_method(level_root, "add_child", block)
	undo.add_do_property(block, "owner", level_root.get_tree().edited_scene_root)
	undo.add_undo_method(level_root, "remove_child", block)
	undo.add_undo_method(block, "queue_free")

	# Track grid occupancy
	if grid_system:
		var cell: Vector3i = grid_system.world_to_cell(position)
		undo.add_do_method(grid_system, "occupy_cell", cell, block)
		undo.add_undo_method(grid_system, "free_cell", cell)

	undo.commit_action()

	block_placed.emit(block)
	return block


func _snap_position(position: Vector3) -> Vector3:
	if grid_system:
		return grid_system.snap_to_grid(position)
	return position


## Get drag bounds for preview


func get_drag_bounds() -> Dictionary:
	if not is_dragging:
		return {}

	return {
		"start": drag_start,
		"end": drag_end,
		"min":
		Vector3(
			minf(drag_start.x, drag_end.x),
			minf(drag_start.y, drag_end.y),
			minf(drag_start.z, drag_end.z)
		),
		"max":
		Vector3(
			maxf(drag_start.x, drag_end.x),
			maxf(drag_start.y, drag_end.y),
			maxf(drag_start.z, drag_end.z)
		)
	}


## Create stepped staircase


func _create_stairs(size: Vector3) -> CSGShape3D:
	# Create a CSGCombiner to hold all steps
	var stairs := CSGCombiner3D.new()
	stairs.name = "Stairs"

	var step_height: float = size.y / stair_steps
	var step_depth: float = size.z / stair_steps

	for i: int in range(stair_steps):
		var step := CSGBox3D.new()
		step.size = Vector3(size.x, step_height, size.z - step_depth * i)
		step.position = Vector3(0, step_height * (i + 0.5), step_depth * i * 0.5)

		if current_material:
			step.material = current_material

		stairs.add_child(step)

	stairs.use_collision = true
	return stairs


## Create angled wedge/slope


func _create_wedge(size: Vector3) -> CSGShape3D:
	# Create wedge using CSGPolygon (like ramp but different profile)
	var poly := CSGPolygon3D.new()

	# Right-angle wedge profile
	poly.polygon = PackedVector2Array(
		[
			Vector2(-size.x * 0.5, 0),
			Vector2(size.x * 0.5, 0),
			Vector2(size.x * 0.5, size.y),
		]
	)
	poly.depth = size.z
	poly.use_collision = true

	if current_material:
		poly.material = current_material

	return poly


## Create curved arch segment


func _create_arch(size: Vector3) -> CSGShape3D:
	# Create arch using CSGPolygon with curved profile
	var poly := CSGPolygon3D.new()

	# Create arch profile (semicircle approximation)
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 8
	var radius: float = size.y
	var thickness: float = size.x * 0.3  # Wall thickness

	# Outer curve
	for i: int in range(segments + 1):
		var angle: float = PI * i / segments
		var x: float = cos(angle) * radius
		var y: float = sin(angle) * radius + radius
		points.append(Vector2(x, y))

	# Inner curve (reverse)
	for i: int in range(segments, -1, -1):
		var angle: float = PI * i / segments
		var inner_r: float = radius - thickness
		var x: float = cos(angle) * inner_r
		var y: float = sin(angle) * inner_r + radius
		points.append(Vector2(x, y))

	poly.polygon = points
	poly.depth = size.z
	poly.use_collision = true

	if current_material:
		poly.material = current_material

	return poly


## Set number of steps for stairs


func set_stair_steps(steps: int) -> void:
	stair_steps = clampi(steps, 2, 16)


## Set stair direction


func set_stair_direction(direction: Vector3) -> void:
	stair_direction = direction.normalized()
