class_name EnemySpawnCoordinator
extends Node

const STUCK_CHECK_INTERVAL: float = 0.5

var _enemy: Node
var _last_valid_position: Vector3 = Vector3.ZERO
var _stuck_check_timer: float = 0.0


func _wait_for_map_sync() -> void:
	# Wait for NavigationServer to sync (initially or after baking)
	var tree: SceneTree = _enemy.get_tree()
	if not tree:
		return

	# Check if map is possibly unsynced (iteration 0)
	var map: RID = _enemy.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		# Wait for first sync
		await NavigationServer3D.map_changed

	# Extra safety: Wait one physics frame to ensure queryable state
	await tree.physics_frame


func setup(enemy: Node) -> void:
	_enemy = enemy


func validate_spawn_position() -> void:
	# Wait for NavigationServer to sync map (prevents "query failed before sync" errors)
	await _wait_for_map_sync()

	if not is_instance_valid(_enemy):
		return

	## Check if spawned inside geometry and correct position
	## Uses navmesh and ray checks to find valid ground position
	var space_state: PhysicsDirectSpaceState3D = _enemy.get_world_3d().direct_space_state
	if not space_state:
		return

	# Get GameManager once for all logging in this function
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null

	# Check 1: Capsule collision test (matches enemy body size)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 2.0

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, _enemy.global_position + Vector3(0, 1.0, 0))
	query.collision_mask = CollisionLayers.MASK_WORLD_ONLY

	var collisions: Array[Dictionary] = space_state.intersect_shape(query, 1)
	var inside_geometry: bool = collisions.size() > 0

	# Check 2: Multi-directional wall proximity (detect enclosed spaces like containers)
	if not inside_geometry:
		var wall_dirs: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
		var walls_nearby: int = 0

		for dir in wall_dirs:
			var wall_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				_enemy.global_position + Vector3(0, 1.0, 0),
				_enemy.global_position + Vector3(0, 1.0, 0) + dir * 1.5,
				CollisionLayers.MASK_WORLD_ONLY
			)
			var result: Dictionary = space_state.intersect_ray(wall_query)
			if not result.is_empty():
				walls_nearby += 1

		# If blocked on 3+ sides, we're enclosed (container, etc.)
		if walls_nearby >= 3:
			inside_geometry = true

		# Check 3: Ceiling Check (Cargo Containers usually have low ceilings ~2.5m)
		if not inside_geometry:
			var ceiling_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				_enemy.global_position + Vector3(0, 0.5, 0),
				_enemy.global_position + Vector3(0, 2.5, 0),
				CollisionLayers.MASK_WORLD_ONLY
			)

			var ceiling_result: Dictionary = space_state.intersect_ray(ceiling_query)
			if not ceiling_result.is_empty():
				# We hit a ceiling! likely inside a container or under a low bridge.
				# Combined with any wall nearby, it's very risky.
				# Let's be strict: If we spawn with a low ceiling, try to move.
				if logger:
					logger.warning(
						"[Enemy] %s blocked by low ceiling, repositioning..." % _enemy.name, "Enemy"
					)
				inside_geometry = true

	if inside_geometry:
		# We're inside geometry! Find valid position
		if logger:
			logger.warning(
				"[Enemy] %s spawned inside geometry, repositioning..." % _enemy.name, "Enemy"
			)

		# Method 1: Try to find closest point on navigation mesh
		var nav_map: RID = _enemy.get_world_3d().navigation_map
		if nav_map.is_valid():
			var closest_nav: Vector3 = NavigationServer3D.map_get_closest_point(
				nav_map, _enemy.global_position
			)

			if closest_nav.distance_to(_enemy.global_position) < 15.0:
				# Validate the navmesh point isn't also in an enclosed area
				var test_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
				test_query.shape = capsule
				test_query.transform = Transform3D(Basis.IDENTITY, closest_nav + Vector3(0, 1.0, 0))
				test_query.collision_mask = CollisionLayers.MASK_WORLD_ONLY

				var test_collisions: Array[Dictionary] = space_state.intersect_shape(test_query, 1)
				if test_collisions.is_empty():
					_enemy.global_position = closest_nav + Vector3(0, 0.1, 0)
					_enemy.velocity = Vector3.ZERO  # CRITICAL: Reset velocity after teleport
					logger.info(
						"[Enemy] Repositioned to navmesh point: %s" % _enemy.global_position,
						"Enemy"
					)
					return

		# Method 2: Push upward and raycast down to find ground
		for height_offset: float in [2.0, 4.0, 6.0, 10.0]:
			var ray_start: Vector3 = _enemy.global_position + Vector3(0, height_offset, 0)
			var ray_end: Vector3 = ray_start - Vector3(0, height_offset + 5.0, 0)

			var ray_query: PhysicsRayQueryParameters3D
			ray_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			ray_query.collision_mask = CollisionLayers.MASK_WORLD_ONLY

			var result: Dictionary = space_state.intersect_ray(ray_query)
			if not result.is_empty():
				_enemy.global_position = result.position + Vector3(0, 0.5, 0)
				_enemy.velocity = Vector3.ZERO  # CRITICAL: Reset velocity after teleport
				logger.info("[Enemy] Repositioned to ground: %s" % _enemy.global_position, "Enemy")
				return

		# Method 3: Last resort - push up significantly
		_enemy.global_position.y += 5.0
		_enemy.velocity = Vector3.ZERO  # CRITICAL: Reset velocity after teleport
		logger.warning("[Enemy] Pushed upward as fallback: %s" % _enemy.global_position, "Enemy")

	# Capture valid position after all checks/adjustments are done
	init_last_valid_position()


func init_last_valid_position() -> void:
	## Called after spawn validation to capture initial valid position
	_last_valid_position = _enemy.global_position


## Get last known valid position (for recovery from invalid states)


func get_last_valid_position() -> Vector3:
	return _last_valid_position


func check_stuck_in_geometry(_delta: float) -> void:
	_stuck_check_timer += _delta
	if _stuck_check_timer < STUCK_CHECK_INTERVAL:
		return

	_stuck_check_timer = 0.0

	if _enemy.is_dead:
		return

	var space_state: PhysicsDirectSpaceState3D = _enemy.get_world_3d().direct_space_state
	if not space_state:
		return

	# Get GameManager for logging
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null

	# Quick sphere test at center of mass
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.3

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, _enemy.global_position + Vector3(0, 1.0, 0))
	query.collision_mask = CollisionLayers.MASK_WORLD_ONLY

	var collisions: Array[Dictionary] = space_state.intersect_shape(query, 1)
	if collisions.size() > 0:
		# We're stuck inside geometry! Recover
		if logger:
			logger.warning(
				(
					"[Enemy] %s stuck in geometry at %s, recovering..."
					% [_enemy.name, _enemy.global_position]
				),
				"Enemy"
			)

		if _last_valid_position != Vector3.ZERO:
			# Prefer last known valid position
			_enemy.global_position = _last_valid_position
			_enemy.velocity = Vector3.ZERO  # CRITICAL: Reset velocity after teleport
			logger.warning(
				(
					"[Enemy] %s recovered to last valid position: %s"
					% [_enemy.name, _enemy.global_position]
				),
				"Enemy"
			)
		else:
			# Fallback: Try to find nearest navmesh point
			var nav_map: RID = _enemy.get_world_3d().navigation_map
			if nav_map.is_valid():
				var closest_nav: Vector3 = NavigationServer3D.map_get_closest_point(
					nav_map, _enemy.global_position
				)
				if closest_nav.distance_to(_enemy.global_position) < 20.0:
					_enemy.global_position = closest_nav + Vector3(0, 0.5, 0)
					_enemy.velocity = Vector3.ZERO  # CRITICAL: Reset velocity after teleport
					logger.warning(
						(
							"[Enemy] %s recovered to navmesh: %s"
							% [_enemy.name, _enemy.global_position]
						),
						"Enemy"
					)
				else:
					# Last resort: push up
					_enemy.global_position.y += 3.0
					_enemy.velocity = Vector3.ZERO  # CRITICAL: Reset velocity after teleport
					logger.warning("[Enemy] %s pushed up as last resort" % _enemy.name, "Enemy")
	else:
		# Not stuck - update last valid position
		_last_valid_position = _enemy.global_position
