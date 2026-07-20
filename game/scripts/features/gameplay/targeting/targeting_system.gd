class_name TargetingSystem
extends Node

signal target_acquired(target: Node3D)
signal target_lost(target: Node3D)

@export_group("Targeting")
@export var targeting_range: float = 50.0
@export var targeting_angle: float = 30.0  ## Degrees from center
@export var sticky_targeting: bool = true  ## Keep target for a short time after losing sight
@export_group("Visuals")
@export var show_health_bar: bool = true
@export var show_distance: bool = true
@export var highlight_color: Color = Color(1.0, 0.3, 0.3, 1.0)

var current_target: Node3D = null

var _previous_target: Node3D = null
var _camera: Camera3D = null
var _sticky_timer: float = 0.0
var _sticky_duration: float = 0.5


func _ready() -> void:
	name = "TargetingSystem"
	add_to_group("targeting_system")

	var config: Node = GameManager.get_core_system("config")
	if config:
		if config.has_signal("config_reloaded"):
			config.config_reloaded.connect(_on_config_reloaded)
	_load_config()


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var config: Node = GameManager.get_core_system("config")
	if config:
		if (
			config.has_signal("config_reloaded")
			and config.config_reloaded.is_connected(_on_config_reloaded)
		):
			config.config_reloaded.disconnect(_on_config_reloaded)


func _on_config_reloaded(_file_path: String = "") -> void:
	_load_config()
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[TargetingSystem] Configuration reloaded", "Core")


func _load_config() -> void:
	var config: Node = GameManager.get_core_system("config")
	if not config or not config.has_method("get_value"):
		return

	var data_result: Variant = config.get_value("visuals.targeting")
	if data_result == null or not data_result is Dictionary:
		return

	var data: Dictionary = data_result
	if data.is_empty():
		return

	# Apply targeting settings
	if data.has("targeting"):
		var t: Dictionary = data["targeting"]
		targeting_range = t.get("range", targeting_range)
		targeting_angle = t.get("angle", targeting_angle)
		sticky_targeting = t.get("sticky_targeting", sticky_targeting)
		_sticky_duration = t.get("sticky_duration", _sticky_duration)

	# Apply visual settings
	if data.has("visuals"):
		var v: Dictionary = data["visuals"]
		show_health_bar = v.get("show_health_bar", show_health_bar)
		show_distance = v.get("show_distance", show_distance)
		if v.has("highlight_color"):
			var c: Dictionary = v["highlight_color"]
			var r: float = c.get("r", 1.0)
			var g: float = c.get("g", 0.3)
			var b: float = c.get("b", 0.3)
			var a: float = c.get("a", 1.0)
			highlight_color = Color(r, g, b, a)

	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[TargetingSystem] Config loaded via GameManager.get_core_system('config')", "Core"
		)


func _process(delta: float) -> void:
	var config: Node = GameManager.get_core_system("config")
	if not config or not config.has_method("is_feature_enabled"):
		return
	if not config.is_feature_enabled("targeting"):
		return

	if not _camera:
		_camera = get_viewport().get_camera_3d()
		if not _camera:
			return

	# Update targeting
	_update_targeting(delta)


func _update_targeting(delta: float) -> void:
	var new_target: Node3D = _find_best_target()

	# Handle sticky targeting
	if sticky_targeting and current_target and not new_target:
		_sticky_timer += delta
		if _sticky_timer < _sticky_duration:
			return  # Keep current target

	_sticky_timer = 0.0

	# Target changed
	if new_target != current_target:
		_previous_target = current_target

		if current_target:
			_unhighlight_target(current_target)
			target_lost.emit(current_target)
			GameManager.emit_event("crosshair_target_changed", {"hit": false, "enemy": false})

		current_target = new_target

		if current_target:
			_highlight_target(current_target)
			target_acquired.emit(current_target)
			# Emit crosshair target changed for red crosshair
			var is_enemy: bool = current_target.is_in_group("enemies")
			GameManager.emit_event("crosshair_target_changed", {"hit": true, "enemy": is_enemy})


func _find_best_target() -> Node3D:
	if not _camera:
		return null

	var camera_pos: Vector3 = _camera.global_position
	var camera_forward: Vector3 = -_camera.global_transform.basis.z

	var best_target: Node3D = null
	var best_score: float = -1.0

	# Check enemies
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for enemy_node: Node in enemies:
		var enemy: Node3D = enemy_node as Node3D
		if not enemy or not is_instance_valid(enemy) or not enemy.visible:
			continue

		# Check distance
		var to_enemy: Vector3 = enemy.global_position - camera_pos
		var distance: float = to_enemy.length()

		if distance > targeting_range:
			continue

		# Check angle
		var direction: Vector3 = to_enemy.normalized()
		var dot: float = camera_forward.dot(direction)
		var angle: float = rad_to_deg(acos(clampf(dot, -1.0, 1.0)))

		if angle > targeting_angle:
			continue

		# Check Line of Sight (Strict visibility requirement)
		if not _has_line_of_sight(enemy):
			continue

		# Calculate score (Prioritize angle heavily for "crosshair feel")
		# Previous: (1.0 - dist/range) + dot
		# New: dot * 5.0 + (1.0 - dist/range)
		var score: float = dot * 5.0 + (1.0 - distance / targeting_range)

		if score > best_score:
			best_score = score
			best_target = enemy

	return best_target


func _has_line_of_sight(target: Node3D) -> bool:
	if not _camera:
		return false

	# Raycast from camera to target center roughly (up 1.0m)
	var from_pos: Vector3 = _camera.global_position
	var to_pos: Vector3 = target.global_position + Vector3(0, 1.0, 0)

	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var exclude_list: Array[RID] = []
	if owner:
		exclude_list.append(owner.get_rid())
	elif get_parent() is CollisionObject3D:
		exclude_list.append(get_parent().get_rid())

	var query := PhysicsRayQueryParameters3D.create(
		from_pos, to_pos, CollisionLayers.MASK_PLAYER_HITSCAN, exclude_list
	)

	var result: Dictionary = space.intersect_ray(query)

	if result.is_empty():
		# Path clear to target point (rare unless mask allows passthrough)
		return true

	if result["collider"] == target:
		return true

	# Check if hit parent is target (e.g. hit hitbox, target is root)
	var collider: Node = result["collider"]
	if collider.owner == target or collider.get_parent() == target:
		return true

	return false


func _highlight_target(target: Node3D) -> void:
	# Apply outline shader or visual effect
	if target.has_method("set_highlighted"):
		target.set_highlighted(true, highlight_color)
	else:
		# Fallback: apply emission glow to all mesh materials
		var meshes: Array[Node] = target.find_children("*", "MeshInstance3D", true, false)
		for mesh_node: Node in meshes:
			var mesh: MeshInstance3D = mesh_node as MeshInstance3D
			if not mesh:
				continue

			# Get or create material override
			var mat: StandardMaterial3D = null
			if mesh.material_override and mesh.material_override is StandardMaterial3D:
				mat = mesh.material_override
			elif mesh.get_surface_override_material_count() > 0:
				var surface_mat: Material = mesh.get_surface_override_material(0)
				if surface_mat and surface_mat is StandardMaterial3D:
					mat = surface_mat.duplicate()
					mesh.set_surface_override_material(0, mat)
			else:
				# Create a new material override
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.8, 0.2, 0.2)
				mesh.material_override = mat

			if mat:
				# Store original emission state
				mesh.set_meta("_original_emission", mat.emission_enabled)
				mesh.set_meta("_original_emission_color", mat.emission)
				mesh.set_meta("_original_emission_energy", mat.emission_energy_multiplier)

				# Apply glow
				mat.emission_enabled = true
				mat.emission = highlight_color
				mat.emission_energy_multiplier = 0.8


func _unhighlight_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	if target.has_method("set_highlighted"):
		target.set_highlighted(false, Color.WHITE)
	else:
		# Restore original material state
		var meshes: Array[Node] = target.find_children("*", "MeshInstance3D", true, false)
		for mesh_node: Node in meshes:
			var mesh: MeshInstance3D = mesh_node as MeshInstance3D
			if not mesh:
				continue

			var mat: StandardMaterial3D = null
			if mesh.material_override and mesh.material_override is StandardMaterial3D:
				mat = mesh.material_override
			elif mesh.get_surface_override_material_count() > 0:
				var surface_mat: Material = mesh.get_surface_override_material(0)
				if surface_mat and surface_mat is StandardMaterial3D:
					mat = surface_mat

			if mat and mesh.has_meta("_original_emission"):
				mat.emission_enabled = mesh.get_meta("_original_emission")
				mat.emission = mesh.get_meta("_original_emission_color")
				mat.emission_energy_multiplier = mesh.get_meta("_original_emission_energy")

				mesh.remove_meta("_original_emission")
				mesh.remove_meta("_original_emission_color")
				mesh.remove_meta("_original_emission_energy")


## Get target info dictionary


func get_target_info() -> Dictionary:
	if not current_target or not is_instance_valid(current_target):
		return {}

	var info: Dictionary = {
		"name": current_target.name,
		"position": current_target.global_position,
		"distance": 0.0,
		"health": 0,
		"max_health": 0,
		"level": 1
	}

	# Get distance
	if _camera:
		info.distance = current_target.global_position.distance_to(_camera.global_position)

	# Get health if available
	if current_target.has_method("get_health"):
		info.health = current_target.get_health()
	elif "health" in current_target:
		info.health = current_target.health

	if current_target.has_method("get_max_health"):
		info.max_health = current_target.get_max_health()
	elif "max_health" in current_target:
		info.max_health = current_target.max_health

	# Get tier
	if "tier" in current_target:
		info.tier = current_target.tier

	# Get AI State
	if "ai_state_name" in current_target:
		info.state = current_target.ai_state_name

	# Get infighting information
	var infighting_system: Node = current_target.get_node_or_null("InfightingSystem")
	if infighting_system and infighting_system.has_method("is_infighting"):
		info.is_infighting = infighting_system.is_infighting()

		if info.is_infighting and infighting_system.has_method("get_infight_target"):
			var infight_target: Node3D = infighting_system.get_infight_target()
			if infight_target and is_instance_valid(infight_target):
				info.infight_target_name = infight_target.name
				# Also get display name if available
				if "display_name" in infight_target:
					info.infight_target_name = infight_target.display_name

	return info


## Check if we have a valid target


func has_target() -> bool:
	return current_target != null and is_instance_valid(current_target)


## Clear current target


func clear_target() -> void:
	if current_target:
		_unhighlight_target(current_target)
		target_lost.emit(current_target)
		current_target = null
