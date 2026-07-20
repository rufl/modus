class_name WeaponHitDetector
extends GameComponent

## Handles hitscan raycast logic and basic hit processing
## Extracted from WeaponManager for better separation of concerns

var player: CharacterBody3D
var _weapon_inventory: WeaponInventory


func _log(message: String, category: String = "WeaponHitDetector") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


func setup(p_player: CharacterBody3D, inventory: WeaponInventory) -> void:
	player = p_player
	_weapon_inventory = inventory


func fire_hitscan(weapon: WeaponData, origin: Vector3, direction: Vector3) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var total_pellets: int = weapon.pellet_count
	var prefix: WeaponAffix = weapon.get_prefix_affix()
	var suffix: WeaponAffix = weapon.get_suffix_affix()

	if prefix:
		total_pellets += prefix.extra_pellets
	if suffix:
		total_pellets += suffix.extra_pellets

	var spread_rad: float = deg_to_rad(weapon.spread_angle)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state

	# Pre-calculate spread basis
	var up: Vector3 = Vector3.UP if abs(direction.y) < 0.99 else Vector3.RIGHT
	var right: Vector3 = direction.cross(up).normalized()
	var real_up: Vector3 = right.cross(direction).normalized()

	for i in range(total_pellets):
		var final_dir: Vector3 = direction
		if total_pellets > 1 or spread_rad > 0:
			var rand_angle: float = randf() * TAU
			var rand_radius: float = randf() * spread_rad
			var offset_u: float = cos(rand_angle) * rand_radius
			var offset_v: float = sin(rand_angle) * rand_radius
			final_dir = (direction + right * offset_u + real_up * offset_v).normalized()

		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin, origin + final_dir * 1000.0, CollisionLayers.MASK_HITSCAN, [player.get_rid()]
		)
		var result: Dictionary = space.intersect_ray(query)

		if result:
			result["direction"] = final_dir
			result["weapon"] = weapon
			hits.append(result)

	return hits


func calculate_damage(weapon: WeaponData) -> Dictionary:
	var base_damage: int = weapon.damage
	var is_crit: bool = false
	var final_damage: int = base_damage

	# DEBUG: Log weapon damage
	_log(
		"[WeaponHitDetector] Weapon: %s Base damage: %d" % [weapon.weapon_name, base_damage],
		"Player"
	)

	var prefix: WeaponAffix = weapon.get_prefix_affix()
	var suffix: WeaponAffix = weapon.get_suffix_affix()

	# Calculate crit
	var crit_chance: float = 0.0
	var crit_mult: float = 2.0
	if prefix:
		crit_chance += prefix.crit_chance
		if prefix.crit_mult > crit_mult:
			crit_mult = prefix.crit_mult
	if suffix:
		crit_chance += suffix.crit_chance
		if suffix.crit_mult > crit_mult:
			crit_mult = suffix.crit_mult

	if crit_chance > 0 and randf() < crit_chance:
		is_crit = true
		final_damage = int(base_damage * crit_mult)

	_log("[WeaponHitDetector] Final damage: %d Is crit: %s" % [final_damage, is_crit], "Player")

	return {"base": base_damage, "final": final_damage, "is_crit": is_crit, "crit_mult": crit_mult}


func find_enemy_from_collider(collider: Object) -> Node:
	if collider is Node and collider.is_in_group("enemies"):
		return collider

	if collider is Node:
		var current: Node = collider
		while current and current != get_tree().root:
			if current.is_in_group("enemies"):
				return current
			current = current.get_parent()

	return null


func get_affix_effects(weapon: WeaponData) -> Dictionary:
	var effects: Dictionary = {
		"chain_count": 0,
		"chain_falloff": 0.7,
		"splash_radius": 0.0,
		"splash_mult": 0.5,
		"lifesteal": 0.0
	}

	var prefix: WeaponAffix = weapon.get_prefix_affix()
	var suffix: WeaponAffix = weapon.get_suffix_affix()

	if prefix:
		if prefix.chain_count > 0:
			effects.chain_count = maxi(effects.chain_count, prefix.chain_count)
			effects.chain_falloff = prefix.chain_damage_falloff
		if prefix.splash_radius > 0:
			effects.splash_radius = maxf(effects.splash_radius, prefix.splash_radius)
			effects.splash_mult = prefix.splash_damage_mult
		effects.lifesteal += prefix.lifesteal_percent

	if suffix:
		if suffix.chain_count > 0:
			effects.chain_count = maxi(effects.chain_count, suffix.chain_count)
			effects.chain_falloff = suffix.chain_damage_falloff
		if suffix.splash_radius > 0:
			effects.splash_radius = maxf(effects.splash_radius, suffix.splash_radius)
			effects.splash_mult = suffix.splash_damage_mult
		effects.lifesteal += suffix.lifesteal_percent

	return effects
