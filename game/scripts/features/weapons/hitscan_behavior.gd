extends RefCounted


func fire(
	origin: Vector3,
	direction: Vector3,
	player: Node,
	spin_speed: float,
	weapon: WeaponData,
	_owner_player_id: int
) -> void:
	var total_pellets: int = _get_total_pellets(weapon)
	var spread_rad: float = _get_spread_angle(weapon, spin_speed)

	# Fire each pellet
	for i in range(total_pellets):
		var final_dir: Vector3 = direction

		# Apply spread if needed
		if total_pellets > 1 or spread_rad > 0:
			final_dir = _apply_spread(direction, spread_rad)

		# Raycast
		_raycast_hitscan(origin, final_dir, player, weapon, i)


func _raycast_hitscan(
	origin: Vector3, direction: Vector3, player: Node, _weapon: WeaponData, _pellet_index: int
) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * 1000.0, CollisionLayers.MASK_HITSCAN, [player.get_rid()]  # Max range
	)

	return space.intersect_ray(query)


func _get_total_pellets(weapon: WeaponData) -> int:
	var total: int = weapon.pellet_count
	var prefix: WeaponAffix = weapon.get_prefix_affix()
	var suffix: WeaponAffix = weapon.get_suffix_affix()

	if prefix:
		total += prefix.extra_pellets
	if suffix:
		total += suffix.extra_pellets

	return total


func _get_spread_angle(weapon: WeaponData, spin_speed: float) -> float:
	var spread: float = weapon.spread_angle
	if weapon.has_spin_up:
		spread += weapon.spin_spread_max * spin_speed

	return deg_to_rad(spread)


func _apply_spread(direction: Vector3, spread_rad: float) -> Vector3:
	if spread_rad <= 0.0:
		return direction

	var rand_angle: float = randf() * TAU
	var rand_radius: float = randf() * spread_rad

	var up := Vector3.UP if abs(direction.y) < 0.99 else Vector3.RIGHT
	var right: Vector3 = direction.cross(up).normalized()
	up = right.cross(direction).normalized()

	var offset: Vector3 = right * cos(rand_angle) * rand_radius + up * sin(rand_angle) * rand_radius

	return (direction + offset).normalized()
