class_name PerceptionComponent
extends Node3D

signal target_spotted(target: Node3D)
signal target_lost(target: Node3D)
signal noise_heard(position: Vector3, volume: float)

@export var vision_range: float = 10.0
@export var detection_radius: float = 10.0
@export var sight_range: float:
	set(value):
		vision_range = value
		detection_radius = value
	get:
		return vision_range
@export var fov: float = 90.0
@export var hearing_range: float = 15.0
@export var check_interval: float = 0.2
@export var proximity_range: float = 3.0  # Base radius for sensing non-visible targets
@export var noise_sensitivity: float = 1.0
@export var is_blind: bool = false
@export var is_deaf: bool = false
@export var aggressive_against_all: bool = false  # If true, targets other enemies as well

var vision_mask: int = CollisionLayers.LAYER_WORLD | CollisionLayers.LAYER_PLAYERS
var head_node: Node3D = null  # Optional: Vision origin override

var _timer: float = 0.0
var _current_target: Node3D = null
var _last_known_pos: Vector3 = Vector3.ZERO
var _parent_enemy: CharacterBody3D


func _ready() -> void:
	# Assume parent is the enemy body
	_parent_enemy = get_parent()
	if not _parent_enemy:
		push_warning("PerceptionComponent needs a CharacterBody3D parent")
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		_timer = check_interval
		_scan_environment()


## Configures perception from a dictionary of parameters.


func configure(config: Dictionary) -> void:
	if "vision_range" in config:
		vision_range = config.vision_range
		if not "detection_radius" in config:
			detection_radius = vision_range
	if "detection_radius" in config:
		detection_radius = config.detection_radius
		if not "vision_range" in config and not "sight_range" in config:
			vision_range = detection_radius
	if "sight_range" in config:
		sight_range = config.sight_range
	if "fov" in config:
		fov = config.fov
	if "hearing_range" in config:
		hearing_range = config.hearing_range
	if "proximity_range" in config:
		proximity_range = config.proximity_range
	if "is_blind" in config:
		is_blind = config.is_blind
	if "is_deaf" in config:
		is_deaf = config.is_deaf
	if "aggressive_against_all" in config:
		aggressive_against_all = config.aggressive_against_all


## Self-configuring method with tier scaling


func configure_from_data(config: Dictionary, tier: int = 1) -> void:
	# Apply base config
	configure(config)

	# Apply tier scaling automatically
	match tier:
		1:  # Basic: Standard values
			fov = config.get("fov", 90.0)
			proximity_range = 3.0
		2:  # Improved: Better peripheral
			fov = config.get("fov", 110.0)
			proximity_range = 4.5
			vision_range *= 1.1
			detection_radius *= 1.1
		3:  # Elite: Good awareness
			fov = config.get("fov", 130.0)
			proximity_range = 6.0
			vision_range *= 1.25
			detection_radius *= 1.25
		4:  # Boss: Very hard to sneak up on
			fov = config.get("fov", 160.0)  # Nearly 180 degrees
			proximity_range = 8.0
			fov = config.get("fov", 160.0)  # Nearly 180 degrees
			proximity_range = 8.0
			vision_range *= 1.5
			detection_radius *= 1.5


func set_vision_config(range_val: float, fov_val: float) -> void:
	vision_range = range_val
	detection_radius = range_val
	fov = fov_val
	# Adjust hearing/proximity proportionally? For now keep separate unless specified.


func _scan_environment() -> void:
	# Prefer the entity registry. Group scans are only a fallback for
	# standalone scenes/tests that have not registered their entities.
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	var registry: Node = gs.get("entity_registry") if gs else null
	var registry_available: bool = is_instance_valid(registry)

	var potential_targets: Array[Node] = []
	if registry_available:
		_append_unique_targets(potential_targets, registry.get_all_players())
		if aggressive_against_all:
			_append_unique_targets(potential_targets, registry.get_all_enemies())
	else:
		_append_unique_targets(potential_targets, get_tree().get_nodes_in_group("player"))
		_append_unique_targets(potential_targets, get_tree().get_nodes_in_group("players"))
		if aggressive_against_all:
			_append_unique_targets(potential_targets, get_tree().get_nodes_in_group("enemies"))

	var best_target: Node3D = null
	var min_dist: float = vision_range * 1.5

	for target: Node in potential_targets:
		if not is_instance_valid(target) or target == _parent_enemy:
			continue

		# Skip dead targets
		if _target_flag(target, "is_dead"):
			_clear_target_if_current(target)
			continue

		# Skip invisible players (godmode until first shot)
		if _target_flag(target, "is_invisible"):
			_clear_target_if_current(target)
			continue

		if can_see(target):
			var dist: float = global_position.distance_to(target.global_position)
			if dist < min_dist:
				min_dist = dist
				best_target = target

	if best_target:
		if _current_target != best_target:
			if _current_target:
				target_lost.emit(_current_target)
			_current_target = best_target
			target_spotted.emit(best_target)
		# Update last known position
		_last_known_pos = best_target.global_position
	elif _current_target:
		# Keep current target if still valid but maybe another one is closer?
		# Actually we already check best_target.
		# If no one is seen, lose target.
		var lost_target: Node3D = _current_target
		_current_target = null
		target_lost.emit(lost_target)


func can_see(target: Node3D) -> bool:
	var dist_sq: float = global_position.distance_squared_to(target.global_position)
	var max_range: float = max(vision_range, detection_radius)
	if dist_sq > max_range * max_range:
		return false

	var to_target: Vector3 = (target.global_position - global_position).normalized()
	# Optional: use eye position instead of root
	var eye_pos: Vector3 = (
		head_node.global_position if head_node else (global_position + Vector3(0, 1.5, 0))
	)

	var target_center: Vector3 = target.global_position + Vector3(0, 1.0, 0)  # Approximation

	# Get space state once for all raycasts
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return false

	# 1. Proximity / Hearing Check (360 degrees)
	# Detect targets close behind or if they are loud
	# Works even if blind (unless proximity range is 0)
	var dist: float = sqrt(dist_sq)
	var effective_prox: float = proximity_range

	# Scale based on target Movement State
	if "is_sprinting" in target and target.is_sprinting:
		effective_prox *= 2.5  # Sprinting is loud/obvious
	elif "is_crouching" in target and target.is_crouching:
		effective_prox *= 0.3  # Crouching is very stealthy
		# If also moving slowly? standard crouch speed is slow enough
	elif "velocity" in target:
		# Check if moving at all
		var vel: Vector3 = target.velocity
		if vel.length_squared() < 0.1:
			effective_prox *= 0.5  # Standing still is stealthier than walking

	if dist < effective_prox:
		# Proximity triggered, but still need line-of-sight (walls block detection).
		if _has_line_of_sight(space_state, eye_pos, target_center, target):
			return true

	if dist <= detection_radius:
		return _has_line_of_sight(space_state, eye_pos, target_center, target)

	# 2. Vision Check (Cone + LOS)
	if is_blind:
		return false

	# Check Angle
	var forward: Vector3 = -global_transform.basis.z  # forward is -z in Godot
	var angle: float = rad_to_deg(forward.angle_to(to_target))

	if angle > fov / 2.0:
		return false

	return _has_line_of_sight(space_state, eye_pos, target_center, target)


func _has_line_of_sight(
	space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, target: Node3D
) -> bool:
	# Some AI targets are logical nodes with no physics collider; they cannot block a ray,
	# so a range/FOV match is enough for visibility.
	if not target is CollisionObject3D:
		return true

	var excludes: Array[RID] = []
	if _parent_enemy and _parent_enemy is CollisionObject3D:
		excludes.append((_parent_enemy as CollisionObject3D).get_rid())

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, vision_mask, excludes
	)

	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return true
	if result.collider == target:
		return true

	return false


func _target_flag(target: Node, flag_name: String) -> bool:
	if flag_name in target:
		return bool(target.get(flag_name))
	if target.has_meta(flag_name):
		return bool(target.get_meta(flag_name))
	return false


func _clear_target_if_current(target: Node) -> void:
	var ai_controller: Node = (
		_parent_enemy.get_node_or_null("EnemyAIController") if _parent_enemy else null
	)
	var controller_has_target: bool = ai_controller and "target" in ai_controller
	if _current_target == target:
		_current_target = null
		target_lost.emit(target)
	elif controller_has_target and ai_controller.target == target:
		target_lost.emit(target)


func _append_unique_targets(targets: Array[Node], candidates: Array) -> void:
	for candidate: Variant in candidates:
		if candidate is Node and not targets.has(candidate):
			targets.append(candidate)


func on_noise_emitted(pos: Vector3, volume: float) -> void:
	if is_deaf:
		return

	var dist_sq: float = global_position.distance_squared_to(pos)
	if dist_sq <= (hearing_range * volume) * (hearing_range * volume):
		noise_heard.emit(pos, volume)
