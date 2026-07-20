extends Node
class_name BloodImpactHandler

## Handles blood effects for weapon impacts
## Use with weapon systems to spawn blood on hits

@export var enabled: bool = true
@export var base_intensity: float = 1.0
@export var damage_multiplier: float = 0.02  ## Intensity per damage point
@export var use_splatter: bool = true  ## Use splatter pattern vs single drop


## Handle weapon hit with blood effect
func handle_hit(hit_position: Vector3, damage: float, hit_normal: Vector3 = Vector3.DOWN) -> void:
	if not enabled:
		return

	var effects_service: Node = GameManager.get_core_system("effects")
	if not effects_service:
		return

	# Calculate intensity based on damage
	var intensity: float = base_intensity + (damage * damage_multiplier)
	intensity = clamp(intensity, 0.5, 2.0)

	# Spawn blood pool effect
	if use_splatter and effects_service.has_method("spawn_blood_pool_splatter"):
		effects_service.spawn_blood_pool_splatter(hit_position, intensity)
	elif effects_service.has_method("spawn_blood_pool"):
		effects_service.spawn_blood_pool(hit_position)

	# Also spawn traditional blood effects (particles, decals)
	if effects_service.has_method("spawn_blood_synced"):
		effects_service.spawn_blood_synced(hit_position, hit_normal, intensity)


## Handle melee hit (usually more blood)
func handle_melee_hit(hit_position: Vector3, damage: float) -> void:
	if not enabled:
		return

	var effects_service: Node = GameManager.get_core_system("effects")
	if not effects_service:
		return

	var intensity: float = base_intensity + (damage * damage_multiplier * 1.5)
	intensity = clamp(intensity, 1.0, 2.5)

	if effects_service.has_method("spawn_blood_pool_splatter"):
		effects_service.spawn_blood_pool_splatter(hit_position, intensity)


## Handle explosion hit (blood splatter in radius)
func handle_explosion_hit(center: Vector3, radius: float, damage: float) -> void:
	if not enabled:
		return

	var effects_service: Node = GameManager.get_core_system("effects")
	if not effects_service or not effects_service.has_method("spawn_blood_pool_splatter"):
		return

	# Spawn multiple splatters in explosion radius
	var splatter_count: int = int(clamp(radius / 2.0, 3, 8))

	for i in range(splatter_count):
		var angle: float = (TAU / splatter_count) * i
		var offset: Vector3 = Vector3(cos(angle), 0, sin(angle)) * radius * randf_range(0.3, 0.8)
		var splatter_pos: Vector3 = center + offset

		var intensity: float = base_intensity + (damage * damage_multiplier * 0.5)
		effects_service.spawn_blood_pool_splatter(splatter_pos, intensity)


## Handle death (large blood pool)
func handle_death(death_position: Vector3, death_direction: Vector3 = Vector3.ZERO) -> void:
	if not enabled:
		return

	var effects_service: Node = GameManager.get_core_system("effects")
	if not effects_service:
		return

	# Spawn large blood splatter
	if effects_service.has_method("spawn_blood_pool_splatter"):
		effects_service.spawn_blood_pool_splatter(death_position, 2.0)

	# Spawn gore effect (includes blood pools)
	if effects_service.has_method("spawn_gore_effect"):
		effects_service.spawn_gore_effect(death_position, death_direction, 2.0)


## Create blood trail between two positions (for projectiles, slashes, etc)
func create_blood_trail(start_pos: Vector3, end_pos: Vector3, intensity: float = 1.0) -> void:
	if not enabled:
		return

	var effects_service: Node = GameManager.get_core_system("effects")
	if effects_service and effects_service.has_method("spawn_blood_pool_trail"):
		effects_service.spawn_blood_pool_trail(start_pos, end_pos, intensity)
