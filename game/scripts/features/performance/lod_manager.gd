class_name LODManager
extends Node

signal lod_changed(entity: Node3D, lod_level: int)
signal entity_culled(entity: Node3D, is_visible: bool)

const LOD_DISTANCES: Array[float] = [15.0, 30.0, 50.0, 75.0]

@export_group("LOD Settings")
@export var enable_lod: bool = true
@export var lod_bias: float = 1.0  ## Higher = more aggressive LOD
@export var lod_update_interval: float = 0.25  ## How often to recalculate LOD
@export_group("Culling Settings")
@export var enable_culling: bool = true
@export var max_draw_distance: float = 100.0
@export var cull_update_interval: float = 0.1

var _camera: Camera3D = null
var _lod_timer: float = 0.0
var _cull_timer: float = 0.0
var _managed_entities: Array[Node3D] = []


func _ready() -> void:
	name = "LODManager"
	add_to_group("lod_manager")
	GameManager.get_core_system("logger").info(
		"[LOD] Initialized with draw distance: %.0f" % max_draw_distance, "Core"
	)


func _process(delta: float) -> void:
	_camera = get_viewport().get_camera_3d()
	if not _camera:
		return

	# Update LOD
	if enable_lod:
		_lod_timer += delta
		if _lod_timer >= lod_update_interval:
			_lod_timer = 0.0
			_update_lod_levels()

	# Update culling
	if enable_culling:
		_cull_timer += delta
		if _cull_timer >= cull_update_interval:
			_cull_timer = 0.0
			_update_entity_culling()


## Register an entity to be managed by the LOD system


func register_entity(entity: Node3D) -> void:
	if entity not in _managed_entities:
		_managed_entities.append(entity)


## Unregister an entity from LOD management


func unregister_entity(entity: Node3D) -> void:
	_managed_entities.erase(entity)


## Clear invalid entity references


func cleanup_invalid_entities() -> void:
	var valid_entities: Array[Node3D] = []
	for entity: Node3D in _managed_entities:
		if is_instance_valid(entity):
			valid_entities.append(entity)
	_managed_entities = valid_entities


## Update LOD levels for all managed entities


func _update_lod_levels() -> void:
	if not is_inside_tree() or not _camera:
		return

	var camera_pos: Vector3 = _camera.global_position

	for entity: Node3D in _managed_entities:
		if not is_instance_valid(entity):
			continue

		var distance: float = entity.global_position.distance_to(camera_pos)
		var lod_level: int = _calculate_lod_level(distance)

		# Apply LOD if entity has the method
		if entity.has_method("set_lod_level"):
			entity.set_lod_level(lod_level)
			lod_changed.emit(entity, lod_level)
		else:
			# Fallback: adjust mesh visibility/quality
			_apply_default_lod(entity, lod_level)


## Calculate LOD level based on distance


func _calculate_lod_level(distance: float) -> int:
	var adjusted_distance: float = distance / lod_bias

	for i: int in range(LOD_DISTANCES.size()):
		if adjusted_distance < LOD_DISTANCES[i]:
			return i

	return LOD_DISTANCES.size()  # Lowest LOD


## Apply default LOD behavior (shadow/particle reduction)


func _apply_default_lod(entity: Node3D, lod_level: int) -> void:
	# Reduce shadow casting at distance
	var mesh_instances: Array[Node] = entity.find_children("*", "MeshInstance3D", true, false)
	for mesh_node: Node in mesh_instances:
		var mesh: MeshInstance3D = mesh_node as MeshInstance3D
		if mesh:
			# Disable shadows for distant objects
			if lod_level >= 2:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Reduce particle effects at distance
	var particles: Array[Node] = entity.find_children("*", "GPUParticles3D", true, false)
	for particle_node: Node in particles:
		var particle: GPUParticles3D = particle_node as GPUParticles3D
		if particle:
			if lod_level >= 3:
				particle.visible = false
			else:
				particle.visible = true
				# Reduce particle count at distance
				particle.amount_ratio = 1.0 - (lod_level * 0.25)


## Update entity culling based on distance and frustum
## NOTE: Does NOT hide enemies directly - only adjusts AI update rates for performance.
## Enemy.gd controls its own visibility to prevent constant toggle flickering.


func _update_entity_culling() -> void:
	if not is_inside_tree() or not _camera:
		return

	var camera_pos: Vector3 = _camera.global_position

	# Get enemies and other cullable entities
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for enemy_node: Node in enemies:
		var enemy: Node3D = enemy_node as Node3D
		if not enemy or not is_instance_valid(enemy):
			continue

		# Skip dead enemies entirely
		if enemy.get("is_dead"):
			continue

		var distance: float = enemy.global_position.distance_to(camera_pos)
		var in_range: bool = distance <= max_draw_distance
		var in_frustum: bool = in_range and _is_in_camera_frustum(enemy)

		# IMPORTANT: Do NOT change enemy.visible directly!
		# This causes constant visibility toggling which triggers flickering.
		# Instead, just throttle AI updates for distant/offscreen enemies.

		# Throttle AI for off-screen or distant enemies (performance optimization)
		if enemy.has_method("set_ai_update_rate"):
			if not in_range:
				# Very far: minimum AI updates
				enemy.set_ai_update_rate(0.1)
			elif not in_frustum:
				# Off-screen but in range: reduced AI updates
				enemy.set_ai_update_rate(0.3)
			else:
				# On-screen and close: full AI
				enemy.set_ai_update_rate(1.0)

		# Emit signal for other systems that may want to react
		if not in_frustum:
			entity_culled.emit(enemy, false)
		else:
			entity_culled.emit(enemy, true)


## Check if entity is natively culled by LOD system


func is_culled_by_lod(entity: Node3D) -> bool:
	if not enable_culling:
		return false

	if not is_instance_valid(entity):
		return false

	# If entity is visible, it's not culled
	if entity.visible:
		return false

	# If hidden, check if it SHOULD be visible according to our logic
	if not _camera:
		return false  # Can't determine, assume not culled by us

	var distance: float = entity.global_position.distance_to(_camera.global_position)
	if distance > max_draw_distance:
		return true

	if not _is_in_camera_frustum(entity):
		return true

	return false  # Hidden for some other reason (dead, script, etc)


## Check if entity is within camera frustum


func _is_in_camera_frustum(entity: Node3D) -> bool:
	if not _camera:
		return true

	# Use camera's native optimized check
	# Add a margin (radius) to avoid popping at the edge
	# Most enemies are approx 2m tall, 1m wide
	var margin: float = 2.0
	var pos: Vector3 = entity.global_position

	# Check center
	if _camera.is_position_in_frustum(pos):
		return true

	# Simple margin check (check points above/below/sides)
	# This is cheaper than AABB check and sufficient for this game
	if _camera.is_position_in_frustum(pos + Vector3(0, margin, 0)):
		return true
	if _camera.is_position_in_frustum(pos + Vector3(margin, 0, 0)):
		return true
	if _camera.is_position_in_frustum(pos - Vector3(margin, 0, 0)):
		return true

	return false


## Set draw distance


func set_draw_distance(distance: float) -> void:
	max_draw_distance = distance
	GameManager.get_core_system("logger").info(
		"[LOD] Draw distance set to: %.0f" % distance, "Core"
	)


## Set LOD bias


func set_lod_bias(bias: float) -> void:
	lod_bias = clampf(bias, 0.25, 4.0)
	GameManager.get_core_system("logger").info("[LOD] LOD bias set to: %.2f" % lod_bias, "Core")


## Get statistics


func get_stats() -> Dictionary:
	var visible_count: int = 0
	var total_count: int = 0

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	total_count = enemies.size()

	for enemy_node: Node in enemies:
		var enemy: Node3D = enemy_node as Node3D
		if enemy and is_instance_valid(enemy) and enemy.visible:
			visible_count += 1

	return {
		"managed_entities": _managed_entities.size(),
		"visible_enemies": visible_count,
		"total_enemies": total_count,
		"draw_distance": max_draw_distance,
		"lod_bias": lod_bias
	}
