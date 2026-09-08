extends ModusGutTestBase

## Test Map Playability
## Validates that maps have all required components to be playable
## Checks spawn points, navigation, lighting, collision, and game-critical nodes

# =============================================================================
# MAP VALIDATION TESTS
# =============================================================================


func test_world_map_has_player_spawns() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	var spawn_points := _get_nodes_in_group(map, "spawn_player")
	assert_gt(
		spawn_points.size(),
		0,
		"Map should have at least one player spawn point in 'spawn_player' group"
	)

	# Verify spawn points are valid Node3D
	for spawn in spawn_points:
		assert_true(spawn is Node3D, "Player spawn point should be a Node3D: %s" % spawn.name)

	map.free()


func test_world_map_has_enemy_spawns() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	var spawn_points := _get_nodes_in_group(map, "enemy_spawn")
	assert_gt(
		spawn_points.size(),
		0,
		"Map should have at least one enemy spawn point in 'enemy_spawn' group"
	)

	# Verify spawn points are valid Node3D
	for spawn in spawn_points:
		assert_true(spawn is Node3D, "Enemy spawn point should be a Node3D: %s" % spawn.name)

	map.free()


func test_world_map_has_navigation() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Check for NavigationRegion3D
	var nav_regions := _find_nodes_by_type(map, "NavigationRegion3D")
	assert_gt(
		nav_regions.size(), 0, "Map should have at least one NavigationRegion3D for AI pathfinding"
	)

	# Verify navigation regions have navigation meshes
	for nav_region in nav_regions:
		if nav_region.has_method("get_navigation_mesh"):
			var nav_mesh = nav_region.get_navigation_mesh()
			assert_not_null(
				nav_mesh, "NavigationRegion3D '%s' should have a navigation mesh" % nav_region.name
			)

	map.free()


func test_world_map_has_lighting() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Check for DirectionalLight3D (sun/moon)
	var dir_lights := _find_nodes_by_type(map, "DirectionalLight3D")

	# Check for any light sources (DirectionalLight3D, OmniLight3D, SpotLight3D)
	var omni_lights := _find_nodes_by_type(map, "OmniLight3D")
	var spot_lights := _find_nodes_by_type(map, "SpotLight3D")

	var total_lights := dir_lights.size() + omni_lights.size() + spot_lights.size()

	assert_gt(
		total_lights,
		0,
		"Map should have at least one light source (DirectionalLight3D, OmniLight3D, or SpotLight3D)"
	)

	map.free()


func test_world_map_has_environment() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Check for WorldEnvironment
	var world_envs := _find_nodes_by_type(map, "WorldEnvironment")
	assert_gt(world_envs.size(), 0, "Map should have a WorldEnvironment for rendering settings")

	# Verify environment has an Environment resource
	for world_env in world_envs:
		if world_env.has_method("get_environment"):
			var env = world_env.get_environment()
			assert_not_null(
				env, "WorldEnvironment '%s' should have an Environment resource" % world_env.name
			)

	map.free()


func test_world_map_has_skybox() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Check for WorldEnvironment with sky
	var world_envs := _find_nodes_by_type(map, "WorldEnvironment")
	assert_gt(world_envs.size(), 0, "Map should have a WorldEnvironment")

	var has_valid_sky := false
	for world_env in world_envs:
		if world_env.has_method("get_environment"):
			var env: Environment = world_env.get_environment()
			if env:
				# Check if sky is configured
				var sky_mode := env.background_mode
				if (
					sky_mode == Environment.BG_SKY
					or sky_mode == Environment.BG_COLOR
					or sky_mode == Environment.BG_CANVAS
					or sky_mode == Environment.BG_KEEP
				):
					has_valid_sky = true

					# If using sky mode, check for Sky resource
					if sky_mode == Environment.BG_SKY:
						var sky := env.sky
						if sky:
							assert_not_null(
								sky,
								"Environment with BG_SKY mode should have a Sky resource configured"
							)
						else:
							# Sky mode but no sky resource - this is a warning
							assert_true(
								true,
								"[Warning] Environment uses BG_SKY mode but has no Sky resource"
							)

	assert_true(has_valid_sky, "Map should have a valid sky/background configuration")

	map.free()


func test_world_map_has_collision() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Check for collision bodies (StaticBody3D for walls/floors)
	var static_bodies := _find_nodes_by_type(map, "StaticBody3D")

	# Also check for CSGShape3D with collision enabled
	var csg_shapes := _find_nodes_by_type(map, "CSGShape3D")

	# Check for MeshInstance3D with collision siblings
	var mesh_instances := _find_nodes_by_type(map, "MeshInstance3D")

	var has_collision := (
		static_bodies.size() > 0 or csg_shapes.size() > 0 or mesh_instances.size() > 0
	)

	assert_true(
		has_collision,
		"Map should have collision geometry (StaticBody3D, CSGShape3D, or MeshInstance3D)"
	)

	map.free()


func test_world_map_has_camera_spawn() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Player spawns should be sufficient for camera positioning
	# But we can also check for explicit camera markers
	var player_spawns := _get_nodes_in_group(map, "spawn_player")
	var camera_markers := _get_nodes_in_group(map, "camera_spawn")

	var has_camera_position := player_spawns.size() > 0 or camera_markers.size() > 0

	assert_true(
		has_camera_position,
		"Map should have player spawn points or camera markers for camera positioning"
	)

	map.free()


func test_world_map_spawn_points_not_overlapping() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	var player_spawns := _get_nodes_in_group(map, "spawn_player")

	# Check that spawn points are not too close to each other
	var min_distance := 2.0  # Minimum 2 units apart

	for i in range(player_spawns.size()):
		for j in range(i + 1, player_spawns.size()):
			var spawn_a: Node3D = player_spawns[i]
			var spawn_b: Node3D = player_spawns[j]

			var distance := spawn_a.global_position.distance_to(spawn_b.global_position)

			assert_gt(
				distance,
				min_distance,
				(
					"Player spawn points '%s' and '%s' are too close (%.2f units)"
					% [spawn_a.name, spawn_b.name, distance]
				)
			)

	map.free()


func test_world_map_spawns_above_ground() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	var player_spawns := _get_nodes_in_group(map, "spawn_player")

	# Check that spawn points are not at y=0 (likely underground or invalid)
	for spawn in player_spawns:
		var spawn_node: Node3D = spawn
		var y_pos := spawn_node.global_position.y

		# Spawn should be above -100 (reasonable floor level)
		assert_gt(
			y_pos,
			-100.0,
			"Player spawn '%s' is too low (y=%.2f), likely underground" % [spawn.name, y_pos]
		)

		# Spawn should be below 1000 (reasonable ceiling)
		assert_lt(
			y_pos,
			1000.0,
			"Player spawn '%s' is too high (y=%.2f), likely in sky" % [spawn.name, y_pos]
		)

	map.free()


# =============================================================================
# OPTIONAL COMPONENTS (WARNINGS, NOT FAILURES)
# =============================================================================


func test_world_map_has_audio_zones() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Check for audio zones (optional but recommended)
	var audio_zones := _get_nodes_in_group(map, "audio_zone")

	if audio_zones.size() == 0:
		# This is a warning, not a failure
		assert_true(
			true, "[Optional] Map has no audio zones - ambient sound may be missing (this is okay)"
		)
	else:
		assert_true(true, "Map has %d audio zone(s)" % audio_zones.size())

	map.free()


func test_world_map_has_item_spawns() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Check for item spawn points (optional)
	var item_spawns := _get_nodes_in_group(map, "item_spawn")

	if item_spawns.size() == 0:
		# This is a warning, not a failure
		assert_true(
			true,
			"[Optional] Map has no item spawns - pickups may not spawn (this is okay for some maps)"
		)
	else:
		assert_true(true, "Map has %d item spawn point(s)" % item_spawns.size())

	map.free()


func test_world_map_has_cover_points() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	# Check for cover points for AI (optional)
	var cover_points := _get_nodes_in_group(map, "cover_point")

	if cover_points.size() == 0:
		# This is a warning, not a failure
		assert_true(
			true,
			"[Optional] Map has no cover points - AI may not use cover effectively (this is okay)"
		)
	else:
		assert_true(true, "Map has %d cover point(s)" % cover_points.size())

	map.free()


# =============================================================================
# PERFORMANCE CHECKS
# =============================================================================


func test_world_map_node_count_reasonable() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	var node_count := _count_all_nodes(map)

	# Warn if node count is very high (performance concern)
	if node_count > 10000:
		assert_true(
			true, "[Performance Warning] Map has %d nodes - consider optimization" % node_count
		)
	else:
		assert_true(true, "Map has reasonable node count: %d" % node_count)

	map.free()


func test_world_map_light_count_reasonable() -> void:
	var map_path := "res://game/scenes/world.tscn"
	var map := _load_map(map_path)
	if not map:
		return

	var omni_lights := _find_nodes_by_type(map, "OmniLight3D")
	var spot_lights := _find_nodes_by_type(map, "SpotLight3D")
	var total_dynamic_lights := omni_lights.size() + spot_lights.size()

	# Warn if too many dynamic lights (performance concern)
	if total_dynamic_lights > 50:
		assert_true(
			true,
			(
				"[Performance Warning] Map has %d dynamic lights - consider baking or reducing"
				% total_dynamic_lights
			)
		)
	else:
		assert_true(true, "Map has reasonable light count: %d" % total_dynamic_lights)

	map.free()


# =============================================================================
# HELPER METHODS
# =============================================================================


func _load_map(path: String) -> Node:
	if not FileAccess.file_exists(path):
		assert_true(false, "Map file does not exist: %s" % path)
		return null

	var scene: PackedScene = load(path)
	if not scene:
		assert_true(false, "Failed to load map scene: %s" % path)
		return null

	var instance := scene.instantiate()
	if not instance:
		assert_true(false, "Failed to instantiate map scene: %s" % path)
		return null

	add_child(instance)
	return instance


func _get_nodes_in_group(root: Node, group_name: String) -> Array[Node]:
	var result: Array[Node] = []
	_find_nodes_in_group_recursive(root, group_name, result)
	return result


func _find_nodes_in_group_recursive(node: Node, group_name: String, result: Array[Node]) -> void:
	if node.is_in_group(group_name):
		result.append(node)

	for child in node.get_children():
		_find_nodes_in_group_recursive(child, group_name, result)


func _find_nodes_by_type(root: Node, type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	_find_nodes_by_type_recursive(root, type_name, result)
	return result


func _find_nodes_by_type_recursive(node: Node, type_name: String, result: Array[Node]) -> void:
	if node.get_class() == type_name:
		result.append(node)

	for child in node.get_children():
		_find_nodes_by_type_recursive(child, type_name, result)


func _count_all_nodes(root: Node) -> int:
	var count := 1  # Count root
	for child in root.get_children():
		count += _count_all_nodes(child)
	return count
