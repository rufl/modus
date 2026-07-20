@tool
class_name VisualConnectionTool
extends Node

signal connection_started(source: Node3D)
signal connection_completed(source: Node3D, target: Node3D, channel: String)
signal connection_cancelled
signal connection_hovered(source: Node3D, target: Node3D)
signal connection_selected(channel_name: String)

enum ConnectionState { IDLE, DRAGGING, QUICK_CONNECT }  ## Dragging from source  ## Quick mode: source selected, clicking targets

var state: ConnectionState = ConnectionState.IDLE
var source_node: Node3D = null
var target_node: Node3D = null
var drag_end_position: Vector3 = Vector3.ZERO
var channel_system: Node = null
var editor_camera: Camera3D = null
var level_root: Node3D = null
var connection_renderer: Node3D = null
var connection_line: MeshInstance3D = null
var source_highlight: MeshInstance3D = null
var target_highlight: MeshInstance3D = null
var connection_color: Color = Color(0.3, 0.8, 0.4)
var hover_color: Color = Color(0.8, 0.8, 0.3)
var invalid_color: Color = Color(0.8, 0.3, 0.3)
var line_width: float = 0.05
var highlight_radius: float = 0.5
var quick_connect_channel: String = ""


func _ready() -> void:
	name = "VisualConnectionTool"
	_create_visual_elements()


## Setup with references


func setup(channel_sys: Node, camera: Camera3D, root: Node3D) -> void:
	channel_system = channel_sys
	editor_camera = camera
	level_root = root


## Set renderer reference


func set_renderer(renderer: Node3D) -> void:
	connection_renderer = renderer


## Handle 3D input


func handle_input(camera: Camera3D, event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 1. Try to start connection (click on actor)
				var actor_under_cursor: Node3D = _find_actor_at_position(
					camera.project_position(event.position, 10.0)  # approx
				)
				# Use raycast properly
				var from = camera.project_ray_origin(event.position)
				var to = from + camera.project_ray_normal(event.position) * 1000.0
				var space_state = camera.get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(from, to)
				query.collide_with_areas = true
				var result = space_state.intersect_ray(query)

				var clicked_actor: Node3D = null
				if result and result.collider:
					var c = result.collider
					var p = c.get_parent()

					var p_is_actor = false
					if p:
						p_is_actor = p.has_method("get_gizmo_data") or p.has_meta("actor_type")

					var c_is_actor = c.has_method("get_gizmo_data") or c.has_meta("actor_type")

					if p_is_actor:
						clicked_actor = p
					elif c_is_actor:
						clicked_actor = c

				if clicked_actor:
					if state == ConnectionState.QUICK_CONNECT:
						quick_connect_to(clicked_actor)
						return true

					start_connection(clicked_actor)
					return true

				# 2. If no actor, try to select connection wire
				var renderer_ready = false
				if connection_renderer:
					renderer_ready = connection_renderer.has_method("get_connection_at_position")

				if renderer_ready:
					var conn: Dictionary = connection_renderer.get_connection_at_position(
						event.position, camera
					)
					if not conn.is_empty():
						var channel: String = conn.get("channel", "")
						if not channel.is_empty():
							connection_selected.emit(channel)
							return true

				# 3. If here, clicked nothing

			else:  # Released
				if state == ConnectionState.DRAGGING:
					complete_connection()
					return true

	elif event is InputEventMouseMotion:
		if state == ConnectionState.DRAGGING:
			# Raycast to find world position for line end
			var from = camera.project_ray_origin(event.position)
			var dist = 50.0
			var to = from + camera.project_ray_normal(event.position) * dist

			# Better: Raycast against world geometry to find drag target pos
			var space_state = camera.get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(query)

			var world_pos = to
			if result:
				world_pos = result.position

			update_drag(world_pos)
			return true

	return false


func _create_visual_elements() -> void:
	# Connection line (cylinder stretched between points)
	connection_line = MeshInstance3D.new()
	connection_line.name = "ConnectionLine"
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = line_width
	line_mesh.bottom_radius = line_width
	line_mesh.height = 1.0
	connection_line.mesh = line_mesh

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = connection_color
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color.a = 0.8
	connection_line.material_override = line_mat
	connection_line.visible = false
	add_child(connection_line)

	# Source highlight sphere
	source_highlight = _create_highlight_sphere(connection_color)
	source_highlight.name = "SourceHighlight"
	add_child(source_highlight)

	# Target highlight sphere
	target_highlight = _create_highlight_sphere(hover_color)
	target_highlight.name = "TargetHighlight"
	add_child(target_highlight)


func _create_highlight_sphere(color: Color) -> MeshInstance3D:
	var highlight := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = highlight_radius
	sphere.height = highlight_radius * 2
	highlight.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_color.a = 0.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.material_override = mat
	highlight.visible = false

	return highlight


## Start dragging a connection from source


func start_connection(source: Node3D) -> void:
	if not source:
		return

	source_node = source
	state = ConnectionState.DRAGGING
	drag_end_position = source.global_position

	# Show source highlight
	source_highlight.global_position = source.global_position
	source_highlight.visible = true
	connection_line.visible = true

	connection_started.emit(source)


## Update drag position (call on mouse move)


func update_drag(world_position: Vector3) -> void:
	if state != ConnectionState.DRAGGING:
		return

	drag_end_position = world_position
	_update_connection_line()

	# Check for potential target under cursor
	var potential_target: Node3D = _find_actor_at_position(world_position)
	if potential_target and potential_target != source_node:
		target_node = potential_target
		target_highlight.global_position = potential_target.global_position
		target_highlight.visible = true

		# Update line color based on validity
		var can_connect: bool = _can_connect(source_node, target_node)
		_set_line_color(connection_color if can_connect else invalid_color)

		connection_hovered.emit(source_node, target_node)
	else:
		target_node = null
		target_highlight.visible = false
		_set_line_color(connection_color)


## Complete the connection


func complete_connection(channel_name: String = "") -> bool:
	if state != ConnectionState.DRAGGING or not source_node or not target_node:
		cancel_connection()
		return false

	if not _can_connect(source_node, target_node):
		cancel_connection()
		return false

	# Create channel name if not provided
	if channel_name.is_empty():
		channel_name = _generate_channel_name(source_node, target_node)

	# Create connection in channel system
	if channel_system and channel_system.has_method("quick_connect"):
		channel_system.quick_connect(source_node, target_node, channel_name)

	connection_completed.emit(source_node, target_node, channel_name)

	_reset_visual_state()
	state = ConnectionState.IDLE
	source_node = null
	target_node = null

	return true


## Cancel current connection


func cancel_connection() -> void:
	_reset_visual_state()
	state = ConnectionState.IDLE
	source_node = null
	target_node = null
	connection_cancelled.emit()


## Enter quick-connect mode


func enter_quick_connect_mode(source: Node3D, channel: String = "") -> void:
	if not source:
		return

	source_node = source
	state = ConnectionState.QUICK_CONNECT
	if not channel.is_empty():
		quick_connect_channel = channel
	else:
		quick_connect_channel = _generate_channel_name(source, null)

	source_highlight.global_position = source.global_position
	source_highlight.visible = true


## Quick-connect to target (in quick-connect mode)


func quick_connect_to(target: Node3D) -> bool:
	if state != ConnectionState.QUICK_CONNECT or not source_node:
		return false

	if not target or target == source_node:
		return false

	if not _can_connect(source_node, target):
		return false

	# Create connection
	if channel_system and channel_system.has_method("quick_connect"):
		channel_system.quick_connect(source_node, target, quick_connect_channel)

	connection_completed.emit(source_node, target, quick_connect_channel)
	return true


## Exit quick-connect mode


func exit_quick_connect_mode() -> void:
	_reset_visual_state()
	state = ConnectionState.IDLE
	source_node = null
	quick_connect_channel = ""


func _update_connection_line() -> void:
	if not source_node or not connection_line.visible:
		return

	var start_pos: Vector3 = source_node.global_position
	var end_pos: Vector3 = drag_end_position

	# Position line at midpoint
	var midpoint: Vector3 = (start_pos + end_pos) * 0.5
	connection_line.global_position = midpoint

	# Scale to length
	var length: float = start_pos.distance_to(end_pos)
	connection_line.scale = Vector3(1, length, 1)

	# Rotate to point from start to end
	if length > 0.01:
		var direction: Vector3 = (end_pos - start_pos).normalized()
		connection_line.look_at(end_pos, Vector3.UP)
		connection_line.rotate_object_local(Vector3.RIGHT, PI / 2)


func _set_line_color(color: Color) -> void:
	if connection_line.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = connection_line.material_override
		mat.albedo_color = color
		mat.albedo_color.a = 0.8


func _reset_visual_state() -> void:
	connection_line.visible = false
	source_highlight.visible = false
	target_highlight.visible = false


## Find actor node at world position


func _find_actor_at_position(world_pos: Vector3) -> Node3D:
	if not level_root:
		return null

	var closest: Node3D = null
	var closest_dist: float = 2.0  # Max pick distance

	for child: Node in level_root.get_children():
		if child is Node3D and child.has_method("get_gizmo_data"):
			var dist: float = child.global_position.distance_to(world_pos)
			if dist < closest_dist:
				closest_dist = dist
				closest = child

	return closest


## Check if connection is valid


func _can_connect(source: Node3D, target: Node3D) -> bool:
	if not source or not target:
		return false
	if source == target:
		return false

	# Check if they're connectable actors
	var source_is_actor: bool = source.has_method("get_gizmo_data") or source.has_meta("actor_type")
	var target_is_actor: bool = target.has_method("get_gizmo_data") or target.has_meta("actor_type")

	return source_is_actor or target_is_actor


func _generate_channel_name(source: Node3D, _target: Node3D) -> String:
	var base: String = source.name if source else "channel"
	var suffix: String = str(Time.get_ticks_msec() % 10000)
	return base.to_snake_case() + "_" + suffix


## Get current state for UI


func get_state_info() -> Dictionary:
	return {
		"state": ConnectionState.keys()[state],
		"source": source_node.name if source_node else "",
		"target": target_node.name if target_node else "",
		"channel": quick_connect_channel
	}


## Is currently in connection mode?


func is_connecting() -> bool:
	return state != ConnectionState.IDLE
