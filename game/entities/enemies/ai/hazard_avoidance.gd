extends Node
class_name HazardAvoidance

signal hazard_detected(hazard_type: String, hazard_position: Vector3)
signal avoiding_hazard(safe_position: Vector3)
signal hazard_cleared

@export_group("Detection")
@export var hazard_scan_radius: float = 10.0
@export var hazard_scan_interval: float = 0.2
@export var edge_detection_distance: float = 2.0
@export var edge_check_rays: int = 8
@export_group("Avoidance")
@export var explosive_danger_radius: float = 8.0
@export var sector_avoidance_priority: float = 1.5
@export var edge_avoidance_priority: float = 2.0
@export var min_safe_distance: float = 5.0

var enemy: CharacterBody3D = null
var scan_timer: float = 0.0
var current_hazards: Array[Dictionary] = []
var is_avoiding: bool = false
var safe_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	enemy = get_parent() as CharacterBody3D
	if not enemy:
		push_error("[HazardAvoidance] Must be child of CharacterBody3D")
		return

	# Only run on server in multiplayer
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		set_physics_process(false)
		return

	# Connect to infighting system if available
	if enemy.has_node("InfightingSystem"):
		var infighting: Node = enemy.get_node("InfightingSystem")
		if infighting.has_signal("pushed_by_enemy"):
			infighting.pushed_by_enemy.connect(_on_pushed_by_enemy)


func _physics_process(delta: float) -> void:
	if not enemy:
		return

	scan_timer += delta
	if scan_timer >= hazard_scan_interval:
		scan_timer = 0.0
		_scan_for_hazards()

	# Check for platform edges continuously
	if _is_near_edge():
		_handle_edge_avoidance()


func should_avoid_position(target_pos: Vector3) -> bool:
	## Check if target position is dangerous
	if _is_position_in_damage_sector(target_pos):
		return true

	if _is_position_near_explosive(target_pos):
		return true

	if _is_position_near_edge(target_pos):
		return true

	return false


func get_safe_position() -> Vector3:
	## Get safe position to move to when avoiding hazards
	if is_avoiding and safe_position != Vector3.ZERO:
		return safe_position

	return enemy.global_position


func is_avoiding_hazard() -> bool:
	## Check if currently avoiding a hazard
	return is_avoiding


func _scan_for_hazards() -> void:
	## Scan for nearby hazards
	current_hazards.clear()

	# Scan for explosives (grenades, rockets)
	_scan_for_explosives()

	# Scan for damage sectors
	_scan_for_damage_sectors()

	# Evaluate hazards and determine safe position
	if current_hazards.size() > 0:
		_calculate_safe_position()
	else:
		if is_avoiding:
			is_avoiding = false
			hazard_cleared.emit()


func _scan_for_explosives() -> void:
	## Scan for nearby explosive projectiles
	var explosives: Array[Node] = []
	explosives.assign(get_tree().get_nodes_in_group("explosives"))

	for explosive: Node in explosives:
		if not is_instance_valid(explosive):
			continue

		var explosive_node: Node3D = explosive as Node3D
		if not explosive_node:
			continue

		var distance: float = enemy.global_position.distance_to(explosive_node.global_position)

		if distance <= hazard_scan_radius:
			var hazard: Dictionary = {
				"type": "explosive",
				"position": explosive_node.global_position,
				"danger_radius": explosive_danger_radius,
				"priority": 1.0,
				"node": explosive_node
			}
			current_hazards.append(hazard)
			hazard_detected.emit("explosive", explosive_node.global_position)


func _scan_for_damage_sectors() -> void:
	## Scan for nearby damage sectors
	var sectors: Array[Node] = []
	sectors.assign(get_tree().get_nodes_in_group("damage_sectors"))

	for sector: Node in sectors:
		if not is_instance_valid(sector):
			continue

		var sector_area: Area3D = sector as Area3D
		if not sector_area:
			continue

		# Check if sector is enabled
		if "enabled" in sector_area and not sector_area.enabled:
			continue

		# Get sector bounds
		var sector_pos: Vector3 = sector_area.global_position
		var sector_bounds: float = _get_area_bounds(sector_area)

		var distance: float = enemy.global_position.distance_to(sector_pos)

		if distance <= hazard_scan_radius + sector_bounds:
			var hazard: Dictionary = {
				"type": "damage_sector",
				"position": sector_pos,
				"danger_radius": sector_bounds,
				"priority": sector_avoidance_priority,
				"node": sector_area
			}
			current_hazards.append(hazard)
			hazard_detected.emit("damage_sector", sector_pos)


func _get_area_bounds(area: Area3D) -> float:
	## Get approximate bounds of area
	for child: Node in area.get_children():
		if child is CollisionShape3D:
			var collision: CollisionShape3D = child as CollisionShape3D
			var shape: Shape3D = collision.shape
			if shape is BoxShape3D:
				var box: BoxShape3D = shape as BoxShape3D
				return max(box.size.x, box.size.z) / 2.0

			if shape is SphereShape3D:
				var sphere: SphereShape3D = shape as SphereShape3D
				return sphere.radius

			if shape is CylinderShape3D:
				var cylinder: CylinderShape3D = shape as CylinderShape3D
				return cylinder.radius

	return 5.0


func _is_near_edge() -> bool:
	## Check if enemy is near platform edge
	if not enemy.is_on_floor():
		return false

	var space_state: PhysicsDirectSpaceState3D = enemy.get_world_3d().direct_space_state

	for i: int in range(edge_check_rays):
		var angle: float = (i / float(edge_check_rays)) * TAU
		var direction: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var check_pos: Vector3 = enemy.global_position + direction * edge_detection_distance

		# Raycast down to check for floor
		var from: Vector3 = check_pos + Vector3(0, 0.5, 0)
		var to: Vector3 = check_pos + Vector3(0, -2.0, 0)

		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [enemy]
		query.collision_mask = 1

		var result: Dictionary = space_state.intersect_ray(query)

		if result.is_empty():
			return true

	return false


func _handle_edge_avoidance() -> void:
	## Handle avoidance when near edge
	var safe_dir: Vector3 = _find_safe_direction_from_edge()

	if safe_dir != Vector3.ZERO:
		safe_position = enemy.global_position + safe_dir * min_safe_distance
		is_avoiding = true

		var hazard: Dictionary = {
			"type": "platform_edge",
			"position": enemy.global_position + safe_dir * -edge_detection_distance,
			"danger_radius": edge_detection_distance,
			"priority": edge_avoidance_priority,
			"node": null
		}
		current_hazards.append(hazard)
		hazard_detected.emit("platform_edge", hazard["position"])
		avoiding_hazard.emit(safe_position)


func _find_safe_direction_from_edge() -> Vector3:
	## Find direction away from edge
	var space_state: PhysicsDirectSpaceState3D = enemy.get_world_3d().direct_space_state
	var safe_directions: Array[Vector3] = []

	for i: int in range(edge_check_rays):
		var angle: float = (i / float(edge_check_rays)) * TAU
		var direction: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var check_pos: Vector3 = enemy.global_position + direction * edge_detection_distance

		var from: Vector3 = check_pos + Vector3(0, 0.5, 0)
		var to: Vector3 = check_pos + Vector3(0, -2.0, 0)

		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [enemy]
		query.collision_mask = 1

		var result: Dictionary = space_state.intersect_ray(query)

		if not result.is_empty():
			safe_directions.append(direction)

	if safe_directions.is_empty():
		return Vector3.ZERO

	var avg_direction: Vector3 = Vector3.ZERO
	for dir: Vector3 in safe_directions:
		avg_direction += dir

	return avg_direction.normalized()


func _calculate_safe_position() -> void:
	## Calculate safe position away from all hazards
	var avoidance_vector: Vector3 = Vector3.ZERO

	for hazard: Dictionary in current_hazards:
		var to_hazard: Vector3 = (hazard["position"] as Vector3) - enemy.global_position
		var distance: float = to_hazard.length()

		if distance < (hazard["danger_radius"] as float):
			var away_direction: Vector3 = -to_hazard.normalized()
			var strength: float = (
				(1.0 - distance / (hazard["danger_radius"] as float))
				* (hazard["priority"] as float)
			)
			avoidance_vector += away_direction * strength

	if avoidance_vector.length() > 0.01:
		avoidance_vector = avoidance_vector.normalized()
		safe_position = enemy.global_position + avoidance_vector * min_safe_distance

		if not _is_safe_position(safe_position):
			safe_position = _find_alternative_safe_position(avoidance_vector)

		is_avoiding = true
		avoiding_hazard.emit(safe_position)
	else:
		is_avoiding = false


func _is_safe_position(pos: Vector3) -> bool:
	## Check if position is safe from hazards
	for hazard: Dictionary in current_hazards:
		var distance: float = pos.distance_to(hazard["position"])
		if distance < hazard["danger_radius"]:
			return false

	if _is_position_near_edge(pos):
		return false

	return true


func _is_position_in_damage_sector(pos: Vector3) -> bool:
	## Check if position is inside a damage sector
	var sectors: Array[Node] = []
	sectors.assign(get_tree().get_nodes_in_group("damage_sectors"))

	for sector: Node in sectors:
		if not is_instance_valid(sector):
			continue

		var sector_area: Area3D = sector as Area3D
		if not sector_area:
			continue

		if "enabled" in sector_area and not sector_area.enabled:
			continue

		var sector_pos: Vector3 = sector_area.global_position
		var sector_bounds: float = _get_area_bounds(sector_area)
		var distance: float = pos.distance_to(sector_pos)

		if distance < sector_bounds:
			return true

	return false


func _is_position_near_explosive(pos: Vector3) -> bool:
	## Check if position is near explosive
	var explosives: Array[Node] = []
	explosives.assign(get_tree().get_nodes_in_group("explosives"))

	for explosive: Node in explosives:
		if not is_instance_valid(explosive):
			continue

		var explosive_node: Node3D = explosive as Node3D
		if not explosive_node:
			continue

		var distance: float = pos.distance_to(explosive_node.global_position)
		if distance < explosive_danger_radius:
			return true

	return false


func _is_position_near_edge(pos: Vector3) -> bool:
	## Check if position is near platform edge
	var space_state: PhysicsDirectSpaceState3D = enemy.get_world_3d().direct_space_state

	for i: int in range(4):
		var angle: float = (i / 4.0) * TAU
		var direction: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var check_pos: Vector3 = pos + direction * edge_detection_distance

		var from: Vector3 = check_pos + Vector3(0, 0.5, 0)
		var to: Vector3 = check_pos + Vector3(0, -2.0, 0)

		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [enemy]
		query.collision_mask = 1

		var result: Dictionary = space_state.intersect_ray(query)

		if result.is_empty():
			return true

	return false


func _find_alternative_safe_position(preferred_direction: Vector3) -> Vector3:
	## Find alternative safe position if preferred direction is unsafe
	var test_angles: Array[float] = [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2, PI]

	for angle_offset: float in test_angles:
		var test_direction: Vector3 = preferred_direction.rotated(Vector3.UP, angle_offset)
		var test_pos: Vector3 = enemy.global_position + test_direction * min_safe_distance

		if _is_safe_position(test_pos):
			return test_pos

	return enemy.global_position


func _on_pushed_by_enemy(_pusher: Node3D, push_direction: Vector3) -> void:
	## Handle being pushed by another enemy during infighting
	if not enemy.is_on_floor():
		return

	var push_target: Vector3 = enemy.global_position + push_direction * 2.0

	if _is_position_near_edge(push_target):
		var safe_dir: Vector3 = _find_safe_direction_from_edge()
		if safe_dir != Vector3.ZERO:
			safe_position = enemy.global_position + safe_dir * min_safe_distance
			is_avoiding = true
			avoiding_hazard.emit(safe_position)


func clear_hazards() -> void:
	## Clear all tracked hazards
	current_hazards.clear()
	is_avoiding = false
	safe_position = Vector3.ZERO


func get_hazard_count() -> int:
	## Get number of detected hazards
	return current_hazards.size()


func get_nearest_hazard() -> Dictionary:
	## Get nearest hazard to enemy
	if current_hazards.is_empty():
		return {}

	var nearest: Dictionary = current_hazards[0]
	var nearest_distance: float = enemy.global_position.distance_to(nearest["position"])

	for hazard: Dictionary in current_hazards:
		var distance: float = enemy.global_position.distance_to(hazard["position"])
		if distance < nearest_distance:
			nearest = hazard
			nearest_distance = distance

	return nearest
