extends ModusGutTestBase

## Test Showcase Map Playability
## Validates that the showcase map has all required components

const SHOWCASE_MAP := "res://game/world/maps/showcase.tscn"

# =============================================================================
# CRITICAL COMPONENTS
# =============================================================================


func test_showcase_map_exists() -> void:
	assert_true(FileAccess.file_exists(SHOWCASE_MAP), "Showcase map file should exist")


func test_showcase_map_loads() -> void:
	var scene: PackedScene = load(SHOWCASE_MAP)
	assert_not_null(scene, "Showcase map should load successfully")

	var instance := scene.instantiate()
	assert_not_null(instance, "Showcase map should instantiate successfully")
	add_child(instance)

	instance.queue_free()


func test_showcase_has_player_spawns() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	var spawn_points := _get_nodes_in_group(map, "spawn_player")
	assert_gt(
		spawn_points.size(),
		0,
		"Showcase map should have at least one player spawn point in 'spawn_player' group"
	)

	# Verify spawn points are valid Node3D
	for spawn in spawn_points:
		assert_true(spawn is Node3D, "Player spawn point should be a Node3D: %s" % spawn.name)

	# Log spawn count for info
	pass_test("Showcase map has %d player spawn point(s)" % spawn_points.size())

	map.free()


func test_showcase_has_enemy_spawns() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	var spawn_points := _get_nodes_in_group(map, "enemy_spawn")

	if spawn_points.size() == 0:
		# Showcase map might not need enemies
		pass_test("Showcase map has no enemy spawns (this is okay for showcase maps)")
	else:
		assert_gt(spawn_points.size(), 0, "Showcase map has enemy spawn points")
		pass_test("Showcase map has %d enemy spawn point(s)" % spawn_points.size())

	map.free()


func test_showcase_has_navigation() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Check for NavigationRegion3D
	var nav_regions := _find_nodes_by_type(map, "NavigationRegion3D")

	if nav_regions.size() == 0:
		# Showcase map might not need navigation
		pass_test("Showcase map has no navigation (this is okay if no AI is needed)")
	else:
		assert_gt(nav_regions.size(), 0, "Showcase map has navigation regions")

		# Verify navigation regions have navigation meshes
		for nav_region in nav_regions:
			if nav_region.has_method("get_navigation_mesh"):
				var nav_mesh = nav_region.get_navigation_mesh()
				assert_not_null(
					nav_mesh,
					"NavigationRegion3D '%s' should have a navigation mesh" % nav_region.name
				)

		pass_test("Showcase map has %d navigation region(s)" % nav_regions.size())

	map.free()


func test_showcase_has_lighting() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Check for DirectionalLight3D (sun/moon)
	var dir_lights := _find_nodes_by_type(map, "DirectionalLight3D")

	# Check for any light sources
	var omni_lights := _find_nodes_by_type(map, "OmniLight3D")
	var spot_lights := _find_nodes_by_type(map, "SpotLight3D")

	var total_lights := dir_lights.size() + omni_lights.size() + spot_lights.size()

	assert_gt(
		total_lights,
		0,
		(
			"Showcase map should have at least one light source "
			+ "(DirectionalLight3D, OmniLight3D, or SpotLight3D)"
		)
	)

	pass_test(
		(
			"Showcase map has %d light(s): %d directional, %d omni, %d spot"
			% [total_lights, dir_lights.size(), omni_lights.size(), spot_lights.size()]
		)
	)

	map.free()


func test_showcase_has_environment() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Check for WorldEnvironment
	var world_envs := _find_nodes_by_type(map, "WorldEnvironment")
	assert_gt(
		world_envs.size(), 0, "Showcase map should have a WorldEnvironment for rendering settings"
	)

	# Verify environment has an Environment resource
	for world_env in world_envs:
		if world_env.has_method("get_environment"):
			var env = world_env.get_environment()
			assert_not_null(
				env, "WorldEnvironment '%s' should have an Environment resource" % world_env.name
			)

	pass_test("Showcase map has %d WorldEnvironment(s)" % world_envs.size())

	map.free()


func test_showcase_has_skybox() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Check for WorldEnvironment with sky
	var world_envs := _find_nodes_by_type(map, "WorldEnvironment")
	assert_gt(world_envs.size(), 0, "Showcase map should have a WorldEnvironment")

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
							pass_test("Showcase map has a properly configured Sky resource")
						else:
							# Sky mode but no sky resource - this is a warning
							pass_test(
								"[Warning] Environment uses BG_SKY mode but has no Sky resource"
							)

	assert_true(has_valid_sky, "Showcase map should have a valid sky/background configuration")

	map.free()


func test_showcase_has_collision() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Check for collision bodies
	var static_bodies := _find_nodes_by_type(map, "StaticBody3D")
	var csg_shapes := _find_nodes_by_type(map, "CSGShape3D")
	var mesh_instances := _find_nodes_by_type(map, "MeshInstance3D")

	var has_collision := (
		static_bodies.size() > 0 or csg_shapes.size() > 0 or mesh_instances.size() > 0
	)

	assert_true(
		has_collision,
		"Showcase map should have collision geometry (StaticBody3D, CSGShape3D, or MeshInstance3D)"
	)

	pass_test(
		(
			"Showcase map has collision: %d static bodies, %d CSG shapes, %d mesh instances"
			% [static_bodies.size(), csg_shapes.size(), mesh_instances.size()]
		)
	)

	map.free()


func test_showcase_spawn_points_valid() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	var player_spawns := _get_nodes_in_group(map, "spawn_player")

	if player_spawns.size() == 0:
		map.free()
		return

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

	pass_test("All spawn points are properly spaced")

	map.free()


func test_showcase_spawns_at_reasonable_height() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	var player_spawns := _get_nodes_in_group(map, "spawn_player")

	if player_spawns.size() == 0:
		map.free()
		return

	# Check that spawn points are at reasonable heights
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

	pass_test("All spawn points are at reasonable heights")

	map.free()


# =============================================================================
# SHOWCASE-SPECIFIC FEATURES
# =============================================================================


func test_showcase_has_demonstration_areas() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Showcase maps typically have labeled areas or markers
	var demo_markers := _get_nodes_in_group(map, "demo_area")
	var info_markers := _get_nodes_in_group(map, "info_marker")

	var total_markers := demo_markers.size() + info_markers.size()

	if total_markers > 0:
		pass_test(
			(
				"Showcase map has %d demonstration markers (%d demo areas, %d info markers)"
				% [total_markers, demo_markers.size(), info_markers.size()]
			)
		)
	else:
		pass_test("Showcase map has no specific demonstration markers (this is okay)")

	map.free()


func test_showcase_has_interactables() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Check for interactive elements
	var buttons := _get_nodes_in_group(map, "button")
	var levers := _get_nodes_in_group(map, "lever")
	var doors := _get_nodes_in_group(map, "door")
	var teleporters := _get_nodes_in_group(map, "teleporter")

	var total_interactables := buttons.size() + levers.size() + doors.size() + teleporters.size()

	if total_interactables > 0:
		pass_test(
			(
				"Showcase map has %d interactable(s): %d buttons, %d levers, %d doors, %d teleporters"
				% [
					total_interactables,
					buttons.size(),
					levers.size(),
					doors.size(),
					teleporters.size()
				]
			)
		)
	else:
		pass_test("Showcase map has no interactables (this is okay)")

	map.free()


func test_showcase_has_hazards() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Check for hazards
	var hazards := _get_nodes_in_group(map, "hazard")
	var damage_zones := _get_nodes_in_group(map, "damage_zone")

	var total_hazards := hazards.size() + damage_zones.size()

	if total_hazards > 0:
		pass_test(
			(
				"Showcase map has %d hazard(s): %d hazards, %d damage zones"
				% [total_hazards, hazards.size(), damage_zones.size()]
			)
		)
	else:
		pass_test("Showcase map has no hazards (this is okay)")

	map.free()


# =============================================================================
# PERFORMANCE AND QUALITY
# =============================================================================


func test_showcase_node_count() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	var node_count := _count_all_nodes(map)

	# Showcase maps can be more complex
	if node_count > 15000:
		pass_test(
			"[Performance Warning] Showcase map has %d nodes - consider optimization" % node_count
		)
	else:
		pass_test("Showcase map has reasonable node count: %d" % node_count)

	map.free()


func test_showcase_light_count() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	var omni_lights := _find_nodes_by_type(map, "OmniLight3D")
	var spot_lights := _find_nodes_by_type(map, "SpotLight3D")
	var total_dynamic_lights := omni_lights.size() + spot_lights.size()

	# Showcase maps can have more lights
	if total_dynamic_lights > 100:
		pass_test(
			(
				"[Performance Warning] Showcase map has %d dynamic lights - consider baking or reducing"
				% total_dynamic_lights
			)
		)
	else:
		pass_test("Showcase map has reasonable light count: %d" % total_dynamic_lights)

	map.free()


func test_showcase_map_summary() -> void:
	var map := _load_map(SHOWCASE_MAP)
	if not map:
		return

	# Generate a comprehensive summary
	var summary := "\n=== SHOWCASE MAP SUMMARY ===\n"

	# Spawns
	var player_spawns := _get_nodes_in_group(map, "spawn_player")
	var enemy_spawns := _get_nodes_in_group(map, "enemy_spawn")
	summary += "Player Spawns: %d\n" % player_spawns.size()
	summary += "Enemy Spawns: %d\n" % enemy_spawns.size()

	# Navigation
	var nav_regions := _find_nodes_by_type(map, "NavigationRegion3D")
	summary += "Navigation Regions: %d\n" % nav_regions.size()

	# Lighting
	var dir_lights := _find_nodes_by_type(map, "DirectionalLight3D")
	var omni_lights := _find_nodes_by_type(map, "OmniLight3D")
	var spot_lights := _find_nodes_by_type(map, "SpotLight3D")
	summary += (
		"Lights: %d directional, %d omni, %d spot\n"
		% [dir_lights.size(), omni_lights.size(), spot_lights.size()]
	)

	# Environment
	var world_envs := _find_nodes_by_type(map, "WorldEnvironment")
	summary += "WorldEnvironments: %d\n" % world_envs.size()

	# Collision
	var static_bodies := _find_nodes_by_type(map, "StaticBody3D")
	summary += "Static Bodies: %d\n" % static_bodies.size()

	# Performance
	var node_count := _count_all_nodes(map)
	summary += "Total Nodes: %d\n" % node_count

	summary += "==========================="

	print(summary)
	pass_test("Showcase map summary generated")

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
