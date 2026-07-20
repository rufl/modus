@tool
class_name BreakableBrush
extends RefCounted

signal block_placed(block: CSGShape3D)

enum MaterialType { GLASS, WOOD, CONCRETE }

const MATERIAL_PRESETS = {
	MaterialType.GLASS:
	{
		"color": Color(0.8, 0.9, 1.0, 0.4),
		"metallic": 0.0,
		"roughness": 0.1,
		"transparent": true,
		"health": 25.0,
		"debris_count": 8
	},
	MaterialType.WOOD:
	{
		"color": Color(0.5, 0.35, 0.2),
		"metallic": 0.0,
		"roughness": 0.8,
		"transparent": false,
		"health": 50.0,
		"debris_count": 5
	},
	MaterialType.CONCRETE:
	{
		"color": Color(0.5, 0.5, 0.5),
		"metallic": 0.0,
		"roughness": 0.9,
		"transparent": false,
		"health": 100.0,
		"debris_count": 6
	}
}

var grid_system: Node = null
var editor_state: Node = null
var current_material_type: MaterialType = MaterialType.WOOD
var block_size: Vector3i = Vector3i.ONE
var is_dragging: bool = false
var drag_start: Vector3 = Vector3.ZERO
var drag_end: Vector3 = Vector3.ZERO


func setup(grid: Node, state: Node) -> void:
	grid_system = grid
	editor_state = state


func set_material_type(type: MaterialType) -> void:
	current_material_type = type


func set_size(size: Vector3i) -> void:
	block_size = size.clamp(Vector3i.ONE, Vector3i(10, 10, 10))


func start_drag(world_position: Vector3) -> void:
	is_dragging = true
	drag_start = _snap_position(world_position)
	drag_end = drag_start


func update_drag(world_position: Vector3) -> void:
	if is_dragging:
		drag_end = _snap_position(world_position)


func finish_drag(level_root: Node3D) -> Array[CSGShape3D]:
	is_dragging = false
	return _place_blocks_in_range(drag_start, drag_end, level_root)


func cancel_drag() -> void:
	is_dragging = false


func place_block(world_position: Vector3, level_root: Node3D) -> CSGShape3D:
	var snapped_pos := _snap_position(world_position)
	return _create_breakable_block(snapped_pos, level_root)


func _place_blocks_in_range(start: Vector3, end: Vector3, level_root: Node3D) -> Array[CSGShape3D]:
	var blocks: Array[CSGShape3D] = []

	if not grid_system:
		var breakable_block := _create_breakable_block(start, level_root)
		if breakable_block:
			blocks.append(breakable_block)
		return blocks

	var cell_size: float = grid_system.cell_size
	var start_cell: Vector3i = grid_system.world_to_cell(start)
	var end_cell: Vector3i = grid_system.world_to_cell(end)

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

	# Create single merged block
	var size := Vector3(max_cell - min_cell + Vector3i.ONE) * cell_size
	var center: Vector3 = grid_system.cell_to_world(min_cell) + size * 0.5
	var block := _create_breakable_block_at(center, size, level_root)
	if block:
		blocks.append(block)

	return blocks


func _create_breakable_block(position: Vector3, level_root: Node3D) -> CSGShape3D:
	var cell_size: float = 1.0
	if grid_system:
		cell_size = grid_system.cell_size

	var size := Vector3(block_size) * cell_size
	return _create_breakable_block_at(position, size, level_root)


func _create_breakable_block_at(position: Vector3, size: Vector3, level_root: Node3D) -> CSGShape3D:
	if not level_root:
		return null

	# Create CSG box
	var box := CSGBox3D.new()
	box.size = size
	box.position = position
	box.use_collision = true

	# Apply material preset
	var preset: Dictionary = MATERIAL_PRESETS[current_material_type]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = preset["color"]
	mat.metallic = preset["metallic"]
	mat.roughness = preset["roughness"]

	if preset["transparent"]:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.refraction_enabled = true
		mat.refraction_scale = 0.05

	box.material = mat

	# Mark as editor-placed
	box.set_meta("level_editor_placed", true)
	box.set_meta("breakable_type", MaterialType.keys()[current_material_type].to_lower())
	box.set_meta("breakable_health", preset["health"])
	box.set_meta("debris_count", preset["debris_count"])

	# Add to scene
	level_root.add_child(box)
	box.owner = level_root.get_tree().edited_scene_root if level_root.get_tree() else null

	# Attach BreakableObject script
	var script := load("res://game/world/actors/hazards/breakable_object.gd")
	if script:
		box.set_script(script)

		# Set properties via metadata (will be read by script)
		match current_material_type:
			MaterialType.GLASS:
				box.set("material_type", 1)  # GLASS
			MaterialType.WOOD:
				box.set("material_type", 0)  # WOOD
			MaterialType.CONCRETE:
				box.set("material_type", 3)  # CONCRETE

		box.set("max_health", preset["health"])
		box.set("current_health", preset["health"])
		box.set("debris_count", preset["debris_count"])

	block_placed.emit(box)
	return box


func _snap_position(position: Vector3) -> Vector3:
	if grid_system:
		return grid_system.snap_to_grid(position)
	return position


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


func get_current_material_name() -> String:
	return MaterialType.keys()[current_material_type].capitalize()


func get_current_health() -> float:
	return MATERIAL_PRESETS[current_material_type]["health"]
