class_name WeaponMeleeSystem
extends GameComponent

## Handles quick melee attacks (off-hand knife)
## Extracted from WeaponManager for better separation of concerns

var player: CharacterBody3D
var camera: Camera3D

var _weapon_inventory: WeaponInventory
var _is_quick_melee: bool = false


func setup(p_player: CharacterBody3D, cam: Camera3D, inventory: WeaponInventory) -> void:
	player = p_player
	camera = cam
	_weapon_inventory = inventory


func quick_melee() -> void:
	if _is_quick_melee:
		return

	_is_quick_melee = true

	# 1. Visuals: Show off-hand knife
	var player_vis: Node = player.get_node_or_null("Visuals")
	if not player_vis:
		player_vis = player.find_child("PlayerVisuals", false, false)

	if player_vis and player_vis.has_method("equip_offhand_knife"):
		player_vis.equip_offhand_knife(true)
		if player_vis.anim_player and player_vis.anim_player.has_animation("Punch_Cross"):
			player_vis.anim_player.play("Punch_Cross")

	# 2. Wait for impact
	await get_tree().create_timer(0.2).timeout

	# 3. Hit detection
	var damage: float = 35.0
	var range_dist: float = 2.0

	var knife_idx: int = _weapon_inventory.find_knife_index()
	if knife_idx != -1:
		var w_data: WeaponData = _weapon_inventory.weapons[knife_idx]
		damage = w_data.damage
		if w_data.attack_range > 0:
			range_dist = w_data.attack_range

	var melee_origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = 0.5
	query.transform = Transform3D(Basis(), melee_origin + forward * (range_dist * 0.5))
	query.collision_mask = CollisionLayers.MASK_HITSCAN
	query.exclude = [player.get_rid()]

	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var results: Array[Dictionary] = space.intersect_shape(query)

	for result in results:
		var collider: Node = result.collider
		if collider == player:
			continue

		var estimated_hit_pos: Vector3 = melee_origin + forward * 1.0
		_handle_hit_melee(collider, estimated_hit_pos, forward, damage)
		break

	# 4. Cleanup
	await get_tree().create_timer(0.3).timeout

	if player_vis and player_vis.has_method("equip_offhand_knife"):
		player_vis.equip_offhand_knife(false)

	_is_quick_melee = false


func _handle_hit_melee(collider: Node, hit_pos: Vector3, dir: Vector3, dmg: float) -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc

	# Apply damage
	if collider.has_method("take_damage"):
		var info: DamageInfo = DamageInfo.new()
		info.base_amount = dmg
		info.damage_type = DamageInfo.DamageType.MELEE
		info.source_id = player.name.to_int()
		info.source = player
		info.hit_position = hit_pos

		# Check if this is a BreakableProp or similar that expects a float
		if collider is StaticBody3D:
			# BreakableProp and similar objects expect just the damage amount
			collider.take_damage(dmg)
		else:
			# Enemies and players expect DamageInfo
			collider.take_damage(info)

		# Server sync
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			if gs and gs.combat:
				gs.combat.request_melee_hit.rpc_id(1, collider.name, dmg)

	# Blood effects
	if gs and gs.effects:
		if gs.effects.has_method("spawn_blood_synced"):
			gs.effects.spawn_blood_synced.rpc(hit_pos, -dir, 0.5)
		if gs.effects.has_method("spawn_gore_effect"):
			gs.effects.spawn_gore_effect.rpc(hit_pos, dir, 3.0)
