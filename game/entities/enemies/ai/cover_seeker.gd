class_name CoverSeeker
extends Node

signal cover_found(cover_position: Vector3)
signal cover_lost
signal moving_to_cover(position: Vector3)

@export_group("Cover Settings")
@export var search_radius: float = 15.0
@export var min_cover_distance: float = 3.0
@export var max_cover_distance: float = 20.0
@export var sample_count: int = 16
@export var cover_height: float = 1.5
@export_group("Timing")
@export var search_cooldown: float = 2.0
@export var cover_timeout: float = 10.0  # Max time in one cover spot

var current_cover_position: Vector3 = Vector3.ZERO
var has_cover: bool = false

var _last_search_time: float = 0.0
var _cover_start_time: float = 0.0
var _parent: Node3D = null


func _ready() -> void:
	_parent = get_parent() as Node3D


func find_cover(threat_position: Vector3, from_position: Vector3 = Vector3.ZERO) -> Vector3:
	var current_time := Time.get_ticks_msec() / 1000.0

	# Cooldown check
	if current_time - _last_search_time < search_cooldown:
		return current_cover_position if has_cover else Vector3.ZERO

	_last_search_time = current_time

	var search_origin := from_position if from_position != Vector3.ZERO else _get_parent_position()
	if search_origin == Vector3.ZERO:
		return Vector3.ZERO

	var best_cover := Vector3.ZERO
	var best_score := -1.0

	# Sample positions in a circle
	for i: int in range(sample_count):
		var angle := (TAU / sample_count) * i
		var distance := randf_range(min_cover_distance, search_radius)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * distance
		var sample_pos := search_origin + offset

		var score := _evaluate_cover_position(sample_pos, search_origin, threat_position)

		if score > best_score:
			best_score = score
			best_cover = sample_pos

	# Additional samples near previous cover if valid
	if has_cover and current_cover_position != Vector3.ZERO:
		for i: int in range(4):
			var angle := (TAU / 4) * i
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * 2.0
			var sample_pos := current_cover_position + offset

			var score := _evaluate_cover_position(sample_pos, search_origin, threat_position)
			if score > best_score:
				best_score = score
				best_cover = sample_pos

	if best_score > 0.0:
		current_cover_position = best_cover
		has_cover = true
		_cover_start_time = current_time
		cover_found.emit(best_cover)
		return best_cover

	has_cover = false
	cover_lost.emit()
	return Vector3.ZERO


func is_in_cover(threat_position: Vector3, position: Vector3 = Vector3.ZERO) -> bool:
	var check_pos := position if position != Vector3.ZERO else _get_parent_position()
	if check_pos == Vector3.ZERO:
		return false

	return not _has_line_of_sight(check_pos + Vector3(0, cover_height, 0), threat_position)


func is_cover_expired() -> bool:
	if not has_cover:
		return true

	var current_time := Time.get_ticks_msec() / 1000.0
	return current_time - _cover_start_time > cover_timeout


func get_current_cover() -> Vector3:
	return current_cover_position if has_cover else Vector3.ZERO


func clear_cover() -> void:
	has_cover = false
	current_cover_position = Vector3.ZERO
	cover_lost.emit()


func move_to_cover(nav_agent: NavigationAgent3D = null) -> void:
	if not has_cover or not _parent:
		return

	moving_to_cover.emit(current_cover_position)

	if nav_agent:
		nav_agent.target_position = current_cover_position


func _evaluate_cover_position(cover_pos: Vector3, from_pos: Vector3, threat_pos: Vector3) -> float:
	var distance_to_cover := from_pos.distance_to(cover_pos)

	# Distance checks
	if distance_to_cover < min_cover_distance or distance_to_cover > max_cover_distance:
		return -1.0

	# Validate position is on ground
	if not _is_position_valid(cover_pos):
		return -1.0

	# Check if position blocks line of sight to threat
	var blocks_los := not _has_line_of_sight(cover_pos + Vector3(0, cover_height, 0), threat_pos)

	if not blocks_los:
		return -1.0

	# Score factors
	var distance_to_threat := cover_pos.distance_to(threat_pos)

	# Prefer cover that's not too close to threat
	var distance_score := clampf(distance_to_threat / max_cover_distance, 0.0, 1.0)

	# Prefer cover that's close to current position
	var proximity_score := 1.0 - (distance_to_cover / search_radius)

	# Bonus for flanking positions
	var to_threat := (threat_pos - from_pos).normalized()
	var to_cover := (cover_pos - from_pos).normalized()
	var flank_angle := absf(to_threat.dot(to_cover))
	var flank_score := 1.0 - flank_angle  # Higher if perpendicular

	# Weighted combination
	var score := (distance_score * 0.4) + (proximity_score * 0.35) + (flank_score * 0.25)

	return score


func _is_position_valid(position: Vector3) -> bool:
	var space_state := get_tree().root.get_world_3d().direct_space_state
	if not space_state:
		return false

	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3(0, 2.0, 0), position - Vector3(0, 1.0, 0)
	)
	query.collision_mask = CollisionLayers.MASK_WORLD_ONLY

	var result := space_state.intersect_ray(query)

	return not result.is_empty()


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var space_state := get_tree().root.get_world_3d().direct_space_state
	if not space_state:
		return true  # Assume LOS if can't check

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = CollisionLayers.MASK_WORLD_ONLY

	var result := space_state.intersect_ray(query)

	return result.is_empty()


func _get_parent_position() -> Vector3:
	if _parent and is_instance_valid(_parent):
		return _parent.global_position
	return Vector3.ZERO


func get_peek_position(threat_position: Vector3) -> Vector3:
	if not has_cover:
		return Vector3.ZERO

	var to_threat := (threat_position - current_cover_position).normalized()
	var peek_offset := to_threat * 1.5  # Step out slightly

	return current_cover_position + peek_offset


func should_change_cover(threat_position: Vector3) -> bool:
	if not has_cover:
		return true

	if is_cover_expired():
		return true

	# Check if cover is still effective
	if not is_in_cover(threat_position, current_cover_position):
		return true

	return false
