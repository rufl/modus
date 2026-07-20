class_name WeaponBehavior
extends RefCounted

var weapon_data: WeaponData
var owner_id: int


func fire(_origin: Vector3, _direction: Vector3, _manager: Node) -> void:
	push_error("WeaponBehavior.fire() must be overridden in subclass")


## Calculate effective recoil based on weapon state


func get_recoil() -> float:
	if not weapon_data:
		return 0.0
	return weapon_data.recoil


## Check if weapon can fire with current ammo


func can_fire(current_ammo: int) -> bool:
	return current_ammo > 0


## Get pellet count including affixes


func get_total_pellets() -> int:
	if not weapon_data:
		return 1

	var total: int = weapon_data.pellet_count
	var prefix: WeaponAffix = weapon_data.get_prefix_affix()
	var suffix: WeaponAffix = weapon_data.get_suffix_affix()

	if prefix:
		total += prefix.extra_pellets
	if suffix:
		total += suffix.extra_pellets

	return total


## Calculate spread angle including spin-up


func get_spread_angle(spin_speed: float = 0.0) -> float:
	if not weapon_data:
		return 0.0

	var spread: float = weapon_data.spread_angle
	if weapon_data.has_spin_up:
		spread += weapon_data.spin_spread_max * spin_speed

	return spread


## Apply spread to direction vector


func apply_spread(direction: Vector3, spread_rad: float) -> Vector3:
	if spread_rad <= 0.0:
		return direction

	var rand_angle: float = randf() * TAU
	var rand_radius: float = randf() * spread_rad

	var up := Vector3.UP if abs(direction.y) < 0.99 else Vector3.RIGHT
	var right: Vector3 = direction.cross(up).normalized()
	up = right.cross(direction).normalized()

	var offset: Vector3 = right * cos(rand_angle) * rand_radius + up * sin(rand_angle) * rand_radius

	return (direction + offset).normalized()
