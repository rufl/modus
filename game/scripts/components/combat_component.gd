class_name CombatComponent
extends GameComponent3D

signal attack_performed(target: Node3D)

@export var attack_damage: float = 10.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var projectile_scene: PackedScene

var _timer: float = 0.0
var _parent_body: CharacterBody3D


func _ready() -> void:
	_parent_body = get_parent()


func _physics_process(delta: float) -> void:
	if _timer > 0:
		_timer -= delta


## Configures the component with specified combat parameters.
## [param damage]: Base damage dealt per attack.
## [param attack_rng]: Maximum range for attacks.
## [param cooldown]: Time in seconds between attacks.


func configure_from_data(damage: float, attack_rng: float, cooldown: float) -> void:
	attack_damage = damage
	attack_range = attack_rng
	attack_cooldown = cooldown


## Returns [code]true[/code] if the component can attack the given target.
## Checks cooldown timer and distance to target.


func can_attack(target: Node3D) -> bool:
	if _timer > 0:
		return false

	var dist_sq: float = global_position.distance_squared_to(target.global_position)
	return dist_sq <= attack_range * attack_range


## Performs an attack on the specified target.
## If [member projectile_scene] is set, spawns a projectile. Otherwise, performs melee.
## Emits [signal attack_performed] on success.


func attack(target: Node3D) -> void:
	if not can_attack(target):
		return

	_timer = attack_cooldown

	# Perform attack logic (hitscan or projectile)
	var is_hitscan: bool = _parent_body.get("attack_type") == "hitscan" if _parent_body else false

	if projectile_scene:
		_spawn_projectile(target)
	elif is_hitscan:
		_perform_hitscan(target)
	else:
		_perform_melee(target)

	# Spawn muzzle flash for visual feedback
	if not multiplayer.has_multiplayer_peer():
		_sync_muzzle_flash()
	elif multiplayer.is_server():
		_sync_muzzle_flash.rpc()

	attack_performed.emit(target)


@rpc("authority", "call_local", "unreliable")
func _sync_muzzle_flash() -> void:
	_spawn_muzzle_flash()


func _get_muzzle_position() -> Vector3:
	if _parent_body and "visuals" in _parent_body and _parent_body.visuals:
		if _parent_body.visuals.has_method("get_muzzle_position"):
			return _parent_body.visuals.get_muzzle_position()

	# Fallback
	return global_position + (-global_transform.basis.z * 0.8) + Vector3(0, 1.2, 0)


func _spawn_muzzle_flash() -> void:
	# Create a quick flash effect at muzzle position
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.3)  # Orange-yellow
	flash.light_energy = 3.0
	flash.omni_range = 4.0
	flash.name = "MuzzleFlash"

	# Position at muzzle
	var muzzle_pos: Vector3 = _get_muzzle_position()
	# Local offset if added as child? No, get_muzzle_position returns GLOBAL position.

	add_child(flash)
	flash.global_position = muzzle_pos

	# Optional: Add a visual mesh too (bright quad)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.mesh.size = Vector2(0.3, 0.3)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.7, 0.2, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material_override = mat
	add_child(mesh)
	mesh.global_position = muzzle_pos

	# Tween flash and cleanup
	var tween: Tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.1)
	# Tween material alpha instead of modulate (MeshInstance3D doesn't have modulate)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(
		func() -> void:
			flash.queue_free()
			mesh.queue_free()
	)


func _perform_melee(target: Node3D) -> void:
	# Line of Sight Check to prevent wallhacks
	if _parent_body:
		var world_3d: World3D = _parent_body.get_world_3d()
		var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
		var eye_pos: Vector3 = _parent_body.global_position + Vector3(0, 1.5, 0)  # Approx eye level
		# Approx chest level
		var target_center: Vector3 = target.global_position + Vector3(0, 1.0, 0)

		# Check for world geometry blocking the view
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			eye_pos, target_center, CollisionLayers.MASK_WORLD_ONLY
		)

		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			# Hit a wall/floor between enemy and target
			return

	# Check if target is a player - use CombatSvc for authority
	if target.is_in_group("player"):
		var source_id: int = _parent_body.get_instance_id() if _parent_body else 0

		# Use CombatSvc to apply damage
		var combat_service: CombatSvc = CombatSvc.get_instance()
		if combat_service and multiplayer.is_server():
			# Server applies damage directly (works in both singleplayer and multiplayer)
			combat_service.apply_damage(
				target, attack_damage, _parent_body, DamageInfo.DamageType.MELEE
			)
		else:
			# Fallback: call take_damage directly on player
			if target.has_method("take_damage"):
				var damage_info: DamageInfo = DamageInfo.new()
				damage_info.base_amount = attack_damage
				damage_info.source = _parent_body
				damage_info.source_id = _parent_body.get_instance_id()
				damage_info.damage_type = DamageInfo.DamageType.MELEE
				target.take_damage(damage_info)
	elif target.has_method("take_damage"):
		# Non-player entities (enemies, destructibles)
		var damage_info: DamageInfo = DamageInfo.new()
		damage_info.base_amount = attack_damage
		damage_info.source = _parent_body  # Set source Node3D for infighting
		damage_info.source_id = _parent_body.get_instance_id()
		damage_info.damage_type = DamageInfo.DamageType.MELEE
		target.take_damage(damage_info)


func _spawn_projectile(target: Node3D) -> void:
	# Server spawns and syncs to all clients
	var spawn_pos: Vector3 = _get_muzzle_position()
	var target_pos: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	var direction: Vector3 = (target_pos - spawn_pos).normalized()
	var shooter_id: int = _parent_body.get_instance_id() if _parent_body else 0

	if not multiplayer.has_multiplayer_peer():
		_sync_spawn_projectile(spawn_pos, direction, shooter_id)
	elif multiplayer.is_server():
		_sync_spawn_projectile.rpc(spawn_pos, direction, shooter_id)


@rpc("authority", "call_local", "reliable")
func _sync_spawn_projectile(spawn_pos: Vector3, direction: Vector3, shooter_id: int) -> void:
	if not projectile_scene:
		return

	var proj: Node3D = projectile_scene.instantiate()

	# Add to tree FIRST so global transform operations work
	get_tree().current_scene.add_child(proj)

	proj.global_position = spawn_pos
	# Set properties after adding to tree (assuming they are safe to set after _ready)
	# If properties need to be set before _ready, use a configure() method or separate init
	if "direction" in proj:
		proj.direction = direction
	if "shooter_id" in proj:
		proj.shooter_id = shooter_id

	# Rotate to face direction
	if direction.length() > 0.01:
		proj.look_at(spawn_pos + direction)


func _perform_hitscan(target: Node3D) -> void:
	var spawn_pos: Vector3 = _get_muzzle_position()
	var target_pos: Vector3 = target.global_position + Vector3(0, 1.0, 0)

	# Raycast to target to check for hits (with LoS)
	var world_3d: World3D = _parent_body.get_world_3d()
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		spawn_pos,
		target_pos + (target_pos - spawn_pos).normalized() * 1.0,  # Slight overshoot
		CollisionLayers.MASK_HITSCAN
	)
	query.add_exception(_parent_body)

	var result: Dictionary = space_state.intersect_ray(query)
	var hit_pos: Vector3 = target_pos

	if not result.is_empty():
		hit_pos = result.position
		var hit_collider: Object = result.collider

		if (
			hit_collider == target
			or (hit_collider.has_method("get_parent") and hit_collider.get_parent() == target)
		):
			# Hit target!
			var combat_service: CombatSvc = CombatSvc.get_instance()
			if combat_service and multiplayer.is_server():
				combat_service.apply_damage(
					target, attack_damage, _parent_body, DamageInfo.DamageType.BULLET
				)

	# Spawn tracer (visual)
	if not multiplayer.has_multiplayer_peer():
		_sync_tracer(spawn_pos, hit_pos)
	elif multiplayer.is_server():
		_sync_tracer.rpc(spawn_pos, hit_pos)


@rpc("authority", "call_local", "unreliable")
func _sync_tracer(from: Vector3, to: Vector3) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs_api: Node = gm.get_core_system("gameplay") if gm else null
	if gs_api and gs_api.effects and gs_api.effects.has_method("spawn_tracer"):
		gs_api.effects.spawn_tracer(from, to)
