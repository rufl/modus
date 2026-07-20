class_name EnemyDebugVisuals
extends Node3D

@export var enabled: bool = true

var _enemy: CharacterBody3D
var _facing_indicator: GPUParticles3D
var _debug_label: Label3D
var _debug_cone: MeshInstance3D
var _position_label: Label3D  # NEW: Shows coordinates in debug mode


func setup(enemy: CharacterBody3D) -> void:
	_enemy = enemy
	_create_visuals()

	# Sync initial state
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		toggle_debug(gs.match_service.debug_vision_enabled)


func _process(_delta: float) -> void:
	if not enabled or not _enemy:
		return
	_update_visuals()


func _create_visuals() -> void:
	# 1. Facing Indicator (Eye Glint)
	_facing_indicator = GPUParticles3D.new()
	_facing_indicator.name = "FacingIndicator"
	_facing_indicator.amount = 16
	_facing_indicator.lifetime = 0.6
	_facing_indicator.explosiveness = 0.0
	_facing_indicator.randomness = 0.3
	_facing_indicator.visibility_aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
	_facing_indicator.emitting = false
	_facing_indicator.visible = false

	var particle_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 0.08
	particle_mat.direction = Vector3(0, 0, -1)
	particle_mat.spread = 25.0
	particle_mat.initial_velocity_min = 0.1
	particle_mat.initial_velocity_max = 0.3
	particle_mat.gravity = Vector3(0, 0.2, 0)
	particle_mat.scale_min = 0.04
	particle_mat.scale_max = 0.1
	particle_mat.color = Color(1.0, 0.0, 0.0, 0.9)
	_facing_indicator.process_material = particle_mat

	var draw_pass: QuadMesh = QuadMesh.new()
	draw_pass.size = Vector2(0.1, 0.1)
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(1.0, 0.1, 0.1)
	draw_mat.emission_energy_multiplier = 2.0
	draw_pass.material = draw_mat
	_facing_indicator.draw_pass_1 = draw_pass

	var head_pos: Vector3 = Vector3(0, 1.7, 0.5)
	_facing_indicator.position = head_pos
	add_child(_facing_indicator)

	# 2. Debug Label
	_debug_label = Label3D.new()
	_debug_label.name = "DebugLabel"
	_debug_label.pixel_size = 0.005
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.no_depth_test = true
	_debug_label.fixed_size = true
	_debug_label.position = Vector3(0, 2.2, 0)
	_debug_label.visible = false
	add_child(_debug_label)

	# 3. Debug FOV Cone (Pizza View)
	_debug_cone = MeshInstance3D.new()
	_debug_cone.name = "DebugFOV"

	# Get Vision Stats
	var range_dist: float = 15.0
	var fov_deg: float = 90.0

	if _enemy and "perception_component" in _enemy and _enemy.perception_component:
		if "sight_range" in _enemy.perception_component:
			range_dist = _enemy.perception_component.sight_range
		if "fov" in _enemy.perception_component:
			fov_deg = _enemy.perception_component.fov

	# Generate Pizza Mesh
	_debug_cone.mesh = _generate_fov_mesh(fov_deg, range_dist)

	# Position at eyes (approx)
	_debug_cone.position = Vector3(0, 1.7, 0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.3)  # Default Yellow
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.0)
	mat.emission_energy_multiplier = 2.0
	_debug_cone.material_override = mat

	_debug_cone.visible = false
	add_child(_debug_cone)

	# 4. Position Label (shows coordinates in debug mode)
	_position_label = Label3D.new()
	_position_label.name = "PositionLabel"
	_position_label.pixel_size = 0.004
	_position_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_position_label.no_depth_test = true
	_position_label.fixed_size = true
	_position_label.position = Vector3(0, 2.8, 0)
	_position_label.font_size = 16
	_position_label.outline_size = 2
	_position_label.modulate = Color(0.5, 1.0, 0.5)  # Light green
	_position_label.visible = false
	add_child(_position_label)


func _update_visuals() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return

	# Update position label every frame
	_update_position_label()

	# Facing Indicator Logic
	if _facing_indicator:
		var to_player: Vector3 = (camera.global_position - _enemy.global_position).normalized()
		var forward: Vector3 = -_enemy.global_transform.basis.z.normalized()
		var dot: float = forward.dot(to_player)

		# Only show Eye Glint if looked AT and facing player
		if dot > 0.9:
			# Check LOS
			var space_state: PhysicsDirectSpaceState3D = _enemy.get_world_3d().direct_space_state
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				_enemy.global_position + Vector3(0, 1.5, 0),
				camera.global_position,
				CollisionLayers.MASK_WORLD_ONLY,
				[_enemy.get_rid()]
			)
			var result: Dictionary = space_state.intersect_ray(query)

			if result.is_empty():
				_facing_indicator.visible = true
				_facing_indicator.emitting = true
			else:
				_facing_indicator.visible = false
				_facing_indicator.emitting = false
		else:
			_facing_indicator.visible = false
			_facing_indicator.emitting = false

			# User requested to hide 3D debug info (F5) in favor of HUD
			_debug_label.visible = false

		# Always ensure label is hidden regardless of facing direction
		if _debug_label:
			_debug_label.visible = false

		# Update Ray Color based on Aggro
		if _debug_cone and _debug_cone.visible:
			var mat: StandardMaterial3D = _debug_cone.material_override as StandardMaterial3D
			if mat:
				# Check Aggro
				# Use is_aggro, or check if attacking/chasing
				var is_aggro: bool = false
				if "is_aggro" in _enemy:
					is_aggro = _enemy.is_aggro
				# Also check combat component state if available?

				if is_aggro:
					# RED (Chasing/Attack)
					if mat.albedo_color != Color(1.0, 0.0, 0.0, 0.6):
						mat.albedo_color = Color(1.0, 0.0, 0.0, 0.6)
						mat.emission = Color(1.0, 0.0, 0.0)
				else:
					# YELLOW (Idle/Scan)
					if mat.albedo_color != Color(1.0, 1.0, 0.0, 0.3):
						mat.albedo_color = Color(1.0, 1.0, 0.0, 0.3)
						mat.emission = Color(1.0, 1.0, 0.0)

	# Failsafe
	if not enabled:
		if _debug_cone:
			_debug_cone.visible = false


func toggle_debug(enabled_state: bool) -> void:
	enabled = enabled_state
	# Force label to remain hidden even when debug is enabled
	if _debug_label:
		_debug_label.visible = false
	if _debug_cone:
		_debug_cone.visible = enabled_state
	# NEW: Show position label with coordinates
	if _position_label:
		_position_label.visible = enabled_state
		if enabled_state:
			_update_position_label()

	# Toggle X-Ray on Visuals
	# Check for CustomVisuals first (loaded from visual_scene in enemy data)
	# Then fall back to default visuals
	if _enemy:
		var custom_visuals: Node = _enemy.get_node_or_null("CustomVisuals")
		if custom_visuals and custom_visuals.has_method("set_xray_enabled"):
			custom_visuals.set_xray_enabled(enabled_state)
		elif _enemy.visuals and _enemy.visuals.has_method("set_xray_enabled"):
			_enemy.visuals.set_xray_enabled(enabled_state)


func _generate_fov_mesh(fov: float, radius: float) -> ArrayMesh:
	var arr_mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()

	# Center point (Eye)
	verts.append(Vector3.ZERO)

	# Generate arc
	var segments: int = 20
	var half_fov: float = deg_to_rad(fov / 2.0)

	# -Z is forward in Godot
	# We want angles from +half_fov to -half_fov around Y axis (relative to -Z)
	# Rotated around Y: x = sin(angle), z = cos(angle)
	# But forward is -Z.
	# Right (+X) is -half_fov? No, typically standard angle 0 is Right (+X).
	# Let's adhere to: Forward is -Z.
	# Angle 0 = -Z.
	# Positive angle = Rotate Left? (ccw around Y). vector(sin, 0, -cos)? via RotY?

	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		# map t [0..1] to angle [-half, +half]
		var angle: float = lerp(-half_fov, half_fov, t)

		# Rotate forward vector (0, 0, -radius) by angle around Y-up
		var x: float = -radius * sin(angle)
		var z: float = -radius * cos(angle)

		verts.append(Vector3(x, 0, z))

		if i > 0:
			# Triangle: Center (0), Previous (i), Current (i+1)
			indices.append(0)
			indices.append(i)
			indices.append(i + 1)

	# Double sided? Or just disable culling in material (already done)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh


## Update position label with current coordinates and visibility status


func _update_position_label() -> void:
	if not _position_label or not _enemy:
		return

	if not enabled or not _position_label.visible:
		return

	var pos: Vector3 = _enemy.global_position
	var vis_indicator: String = "[V]" if _enemy.visible else "[H]"
	var health_str: String = ""
	if "health" in _enemy and "max_health" in _enemy:
		health_str = " HP:%.0f/%.0f" % [_enemy.health, _enemy.max_health]

	_position_label.text = (
		"%s (%.1f, %.1f, %.1f)%s" % [vis_indicator, pos.x, pos.y, pos.z, health_str]
	)

	# Color based on visibility
	if _enemy.visible:
		_position_label.modulate = Color(0.5, 1.0, 0.5)  # Light green
	else:
		_position_label.modulate = Color(1.0, 0.3, 0.3)  # Red/warning
