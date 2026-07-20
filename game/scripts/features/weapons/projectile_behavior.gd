extends RefCounted


func fire(
	origin: Vector3, direction: Vector3, weapon: WeaponData, _player: Node, _owner_player_id: int
) -> Dictionary:
	# Return spawn data for server to process
	# Safety check: ensure direction is valid for Basis.looking_at()
	var safe_direction: Vector3 = direction.normalized()
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector3.FORWARD  # Default to forward if direction is invalid

	var rot: Basis = Basis.looking_at(safe_direction)
	var vel: Vector3 = safe_direction * weapon.projectile_speed

	return {
		"scene_path": weapon.projectile_scene.resource_path if weapon.projectile_scene else "",
		"origin": origin,
		"rotation": rot,
		"velocity": vel,
		"damage": weapon.damage,
		"blast_radius": weapon.blast_radius
	}
