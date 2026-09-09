class_name CombatSvc
extends GameService

const MAX_DAMAGE: float = 1000.0


static func get_instance() -> CombatSvc:
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameManager")
	if not gm or not gm.has_method("get_core_system"):
		return null
	var gameplay_svc: Node = gm.get_core_system("gameplay")
	return gameplay_svc.combat as CombatSvc if gameplay_svc else null


## CombatService - Server-authoritative combat validation and handling
##
## Handles damage requests, hit validation, and kill attribution.
## All combat actions should go through this service.

# Service preloads to resolve lints


func _ready() -> void:
	name = "CombatService"


func get_init_priority() -> int:
	return 30  # After NetworkManager (20)


## Initialize the service

## Validate hit (Anti-cheat hook with lag compensation)
var lag_compensation: Node = null  # LagCompensationSystem
const LagCompScript = preload("res://game/core/network/lag_compensation_system.gd")
var hit_validator: Node = null  # HitValidator
const HitValidatorScript = preload("res://game/scripts/features/combat/hit_validator.gd")


func initialize() -> void:
	_initialized = true
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info("[Combat] Initialized", "Combat")

	# Initialize Lag Compensation
	if LagCompScript:
		lag_compensation = LagCompScript.new()
		lag_compensation.name = "LagCompensationSystem"
		add_child(lag_compensation)

	# Initialize Hit Validator
	if HitValidatorScript:
		hit_validator = HitValidatorScript.new({})
		hit_validator.name = "HitValidator"
		add_child(hit_validator)

		# Connect lag compensation to hit validator
		if lag_compensation:
			hit_validator.initialize(lag_compensation)


## Validate hit (Anti-cheat hook with lag compensation)


func validate_hit(attacker_pos: Vector3, target_pos: Vector3, weapon_id: String) -> bool:
	# Delegate to HitValidator if available
	if hit_validator and hit_validator.has_method("validate_hit"):
		return hit_validator.validate_hit(attacker_pos, target_pos, weapon_id)

	# Fallback to legacy implementation if HitValidator not available
	var gm_check: Node = get_node_or_null("/root/GameManager")
	if gm_check:
		var logger_check: Node = gm_check.get_core_system("logger")
		if logger_check:
			logger_check.trace(
				(
					"Validating hit: Attacker=%v Target=%v Weapon=%s"
					% [attacker_pos, target_pos, weapon_id]
				),
				"Combat"
			)

	# Server-side raycast validation for hit detection
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var _manager: Node = tree.root.get_node_or_null("GameManager") if tree else null
	if not tree:
		return false
	var root: Node = tree.root
	if not root:
		return false
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	if not space:
		var gm_space: Node = get_node_or_null("/root/GameManager")
		if gm_space:
			var logger: Node = gm_space.get_core_system("logger")
			if logger:
				logger.trace("Validation failed: No space state", "Combat")
		return false

	# Create raycast query
	var query := PhysicsRayQueryParameters3D.create(attacker_pos, target_pos)
	query.collision_mask = CollisionLayers.MASK_HITSCAN  # World + Players + Enemies

	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		var gm_ray: Node = get_node_or_null("/root/GameManager")
		if gm_ray:
			var logger_ray: Node = gm_ray.get_core_system("logger")
			if logger_ray:
				logger_ray.trace("Validation failed: No raycast hit", "Combat")
		return false  # No hit detected

	# Validate distance (anti-cheat: prevent shooting through walls or too far)
	var distance: float = attacker_pos.distance_to(target_pos)
	var gm_dist: Node = get_node_or_null("/root/GameManager")
	var data_service: Node = gm_dist.get_core_system("data") if gm_dist else null
	var weapon_data: Dictionary = {}
	if data_service and "weapons" in data_service:
		weapon_data = data_service.weapons.get(weapon_id, {})

	if weapon_data.has("max_range"):
		var max_range: float = weapon_data.max_range
		if distance > max_range * 1.15:  # 15% tolerance for latency
			if gm_dist:
				var logger_range: Node = gm_dist.get_core_system("logger")
				if logger_range:
					logger_range.warning(
						(
							"[Combat] Hit rejected: distance %.1fm exceeds max range %.1fm"
							% [distance, max_range]
						),
						"Combat"
					)
			return false

	# Check if raycast hit the target (not a wall)
	var hit_collider: Object = result.get("collider", null)
	if not hit_collider:
		var gm_coll: Node = get_node_or_null("/root/GameManager")
		if gm_coll:
			var logger: Node = gm_coll.get_core_system("logger")
			if logger:
				logger.trace("Validation failed: Hit nothing (null collider)", "Combat")
		return false

	# Valid hit
	var gm_valid: Node = get_node_or_null("/root/GameManager")
	if gm_valid:
		var logger_valid: Node = gm_valid.get_core_system("logger")
		if logger_valid:
			logger_valid.trace(
				"Hit validated successfully against %s" % hit_collider.name, "CombatService"
			)
	return true


## Helper: Check if a player is in a special mode (Spectator, Editor, Downed)


func _is_player_in_special_mode(peer_id: int) -> bool:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return false
	var gameplay_svc := gm.get_core_system("gameplay") as GameplaySvc
	if not gameplay_svc or not gameplay_svc.match_service:
		return false

	if not gameplay_svc.match_service.player_scores.has(peer_id):
		return false

	var state: String = gameplay_svc.match_service.player_scores[peer_id].get("state", "ALIVE")
	return state in ["DEAD", "SPEC", "EDIT", "DOWNED"]


## Client -> Server: Request damage application

@rpc("any_peer", "call_remote", "reliable")
func request_damage(
	target_id: int,
	amount: float,
	source_id: int,
	_source_pos: Vector3,
	damage_type: int = 0,
	hit_position: Vector3 = Vector3.ZERO
) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	# Server authority check (in singleplayer, we ARE the server)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Validate via NetworkService.network_manager
	var gm_net: Node = get_node_or_null("/root/GameManager")
	if not gm_net:
		return
	var ns := gm_net.get_core_system("network") as NetworkSvc
	var mgr: Node = ns.network_manager if ns else null
	if mgr and not mgr.validate_rpc(sender_id, "request_damage", [25.0, sender_id, _source_pos]):
		return

	# Validate sender state (Spectators/Dead players can't deal damage)
	if _is_player_in_special_mode(sender_id):
		# Allow downed players to potentially deal damage? Usually no.
		# If you want separate rules for DOWNED, modify helper or check specifically here.
		var logger_mode: Node = gm_net.get_core_system("logger")
		if logger_mode:
			logger_mode.warning(
				"[Combat] Damage request ignored from special mode player: %d" % sender_id, "Combat"
			)
		return

	# Security: Cap maximum damage
	if amount > MAX_DAMAGE:
		push_warning("[Combat] Rejected excessive val: %.1f from %d" % [amount, sender_id])
		return
	if amount < 0:
		push_warning("[Combat] Rejected negative val: %.1f from %d" % [amount, sender_id])
		return

	# Find entities
	var target_node: Node = instance_from_id(target_id)
	var source_node: Node = _find_player_by_id(sender_id)
	if (
		not is_instance_valid(source_node)
		or source_node.get_multiplayer_authority() != sender_id
		or damage_type != DamageInfo.DamageType.MELEE
	):
		return
	# This endpoint serves the unarmed melee input, never client-authored damage.
	amount = 25.0
	if (
		target_node is not Node3D
		or source_node.global_position.distance_to(target_node.global_position) > 3.5
	):
		return

	if not is_instance_valid(target_node):
		var gm_target: Node = get_node_or_null("/root/GameManager")
		if gm_target:
			var logger_check: Node = gm_target.get_core_system("logger")
			if logger_check:
				logger_check.warning("[Combat] Invalid target ID: %d" % target_id, "Combat")
		return

	# Apply damage on server
	var gm_apply: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm_apply.get_core_system("logger") if gm_apply else null
	if logger and logger.current_level <= 0:  # TRACE
		logger.trace(
			(
				"Applying damage request: %.1f from %s -> %s"
				% [amount, str(source_node.name) if source_node else "Env", target_node.name]
			),
			"Combat"
		)

	# Pass hit_position to apply_damage
	apply_damage(target_node, amount, source_node, damage_type, null, false, -1, hit_position)


## Apply damage to an entity (Server only)


func apply_damage(
	target: Node,
	amount: float,
	source: Node,
	damage_type: int,
	weapon_source: Variant = null,
	is_critical: bool = false,
	source_id_override: int = -1,
	hit_position: Vector3 = Vector3.ZERO,
	hit_normal: Vector3 = Vector3.UP
) -> void:
	# Server authority (in singleplayer, we ARE the server)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_instance_valid(target) or not is_finite(amount) or amount <= 0.0:
		return
	# Evaluate only server-owned status state, once, before dispatch to any target type.
	if is_instance_valid(source) and source.has_method("get_outgoing_damage_modifier"):
		amount *= source.get_outgoing_damage_modifier()

	# Create damage info
	var damage_info := DamageInfo.new()
	damage_info.base_amount = amount
	damage_info.source = source

	if source_id_override != -1:
		damage_info.source_id = source_id_override
	else:
		damage_info.source_id = source.get_instance_id() if source else 0

	damage_info.damage_type = damage_type as DamageInfo.DamageType
	damage_info.is_critical = is_critical
	damage_info.hit_position = hit_position
	damage_info.hit_normal = hit_normal

	# Calculate knockback direction if possible
	if hit_position != Vector3.ZERO and source:
		damage_info.knockback_direction = (hit_position - source.global_position).normalized()

	if weapon_source is Resource:
		damage_info.weapon_source = weapon_source
		if "id" in weapon_source:
			damage_info.weapon_id = weapon_source.id
	elif weapon_source is String:
		damage_info.weapon_id = weapon_source

	# Apply to target
	if target.has_method("take_damage"):
		var gm_dmg: Node = get_node_or_null("/root/GameManager")
		if gm_dmg:
			var logger_dmg: Node = gm_dmg.get_core_system("logger")
			if logger_dmg:
				logger_dmg.info(
					"[Combat] Applying damage to %s via take_damage: %.1f" % [target.name, amount],
					"Combat"
				)
		if target is StaticBody3D:
			target.take_damage(amount, DamageInfo.DamageType.keys()[damage_type].to_lower(), source)
		else:
			target.take_damage(damage_info)

		# Emit damage_dealt event for stats tracking
		if gm_dmg:
			gm_dmg.emit_event(
				"damage_dealt",
				{
					"amount": amount,
					"target": target,
					"source": source,
					"source_id": damage_info.source_id,
					"is_critical": is_critical
				}
			)

		# Play audio
		# We need to access AudioService via GameManager
		var audio_svc: Node = gm_dmg.get_core_system("audio") if gm_dmg else null
		if audio_svc:
			if is_critical:
				audio_svc.play_synthesized_crit(target.global_position)
			else:
				audio_svc.play_synthesized_hit(target.global_position)

		# Register hit (Stats)
		if source and source.is_in_group("player"):
			# Use source_id from damage info as it's reliable
			var gameplay_svc := (
				gm_dmg.get_core_system("gameplay") as GameplaySvc if gm_dmg else null
			)
			if (
				gameplay_svc
				and gameplay_svc.match_service
				and gameplay_svc.match_service.has_method("register_shot_hit")
			):
				gameplay_svc.match_service.register_shot_hit(damage_info.source_id)

		# Emit critical_hit event separately if applicable
		if is_critical and gm_dmg:
			gm_dmg.emit_event(
				"critical_hit", {"amount": amount, "target": target, "source": source}
			)
	elif target.has_method("receive_damage"):
		# Alternative damage interface for simpler entities
		var gm_recv: Node = get_node_or_null("/root/GameManager")
		var logger: Node = gm_recv.get_core_system("logger") if gm_recv else null
		if logger:
			logger.info(
				"[Combat] Applying damage to %s via receive_damage: %.1f" % [target.name, amount],
				"Combat"
			)
		target.receive_damage(
			int(amount), damage_info.source_id, source.global_position if source else Vector3.ZERO
		)

		if gm_recv:
			gm_recv.emit_event(
				"damage_dealt",
				{
					"amount": amount,
					"target": target,
					"source": source,
					"source_id": damage_info.source_id,
					"is_critical": is_critical
				}
			)
	else:
		# Only warn for objects that should have damage methods (not debris/gibs)
		if not target is RigidBody3D:
			push_warning("[Combat] Target %s has no damage method!" % target.name)


## Client -> Server: Request melee hit (Anti-cheat validated)

@rpc("any_peer", "call_remote", "reliable")
func request_melee_hit(target_name: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Rate Limit via NetworkManager
	var gm_rate: Node = get_node_or_null("/root/GameManager")
	var ns := gm_rate.get_core_system("network") as NetworkSvc if gm_rate else null

	var player: Node = _find_player_by_id(sender_id)
	if not is_instance_valid(player) or _is_player_in_special_mode(sender_id):
		return
	var damage: float = 35.0
	var weapons: WeaponManager = player.get_node_or_null("WeaponManager") as WeaponManager
	if not weapons or not weapons.inventory:
		return
	var knife_index: int = weapons.inventory.find_knife_index()
	if knife_index != -1:
		damage = weapons.inventory.weapons[knife_index].damage
	if (
		ns
		and ns.network_manager
		and not ns.network_manager.validate_rpc(
			sender_id, "request_damage", [damage, sender_id, player.global_position]
		)
	):
		return

	# Find target (Search in current scene)
	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	var target: Node = null

	if scene_root:
		# Try fast find first
		target = scene_root.find_child(target_name, true, false)

	if not target:
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.warning("[Combat] Melee target not found: %s" % target_name, "Combat")
		return

	# Validate Distance (Melee Range: ~2.5m tolerance)
	var max_melee_dist: float = 3.5
	var dist: float = player.global_position.distance_to(target.global_position)
	if dist > max_melee_dist:
		var gm_melee: Node = get_node_or_null("/root/GameManager")
		if gm_melee:
			var logger_melee: Node = gm_melee.get_core_system("logger")
			if logger_melee:
				logger_melee.warning(
					"[Combat] Melee hit rejected (too far): %.2fm peer %d" % [dist, sender_id],
					"Combat"
				)
		return

	# Apply Damage
	apply_damage(
		target,
		damage,
		player,
		DamageInfo.DamageType.MELEE,
		"Melee",
		false,
		sender_id,
		target.global_position,  # Hit pos approx
		(player.global_position - target.global_position).normalized()  # Hit normal approx
	)


func _find_player_by_id(peer_id: int) -> Node:
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player.get_multiplayer_authority() == peer_id:
			return player
	return null


## Client -> Server: Request weapon fire

@rpc("any_peer", "call_remote", "reliable")
func request_fire(origin: Vector3, direction: Vector3, weapon_index: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Validation via NetworkService.network_manager
	var gm_fire: Node = get_node_or_null("/root/GameManager")
	if not gm_fire:
		return
	var ns_inst := gm_fire.get_core_system("network") as NetworkSvc
	if ns_inst and ns_inst.network_manager:
		if not ns_inst.network_manager.validate_rpc(
			sender_id, "request_shoot", [origin, direction, weapon_index]
		):
			return

	# Validate sender state
	if _is_player_in_special_mode(sender_id):
		var logger_fire: Node = gm_fire.get_core_system("logger")
		if logger_fire:
			logger_fire.warning(
				"[Combat] Fire request ignored from special mode player: %d" % sender_id, "Combat"
			)
		return

	var player: Node = _find_player_by_id(sender_id)

	if not player:
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.warning("[Combat] Unknown player ID: %d" % sender_id, "Combat")
		return

	var weapon_manager: Node = player.get_node_or_null("WeaponManager")
	if weapon_manager and weapon_manager.has_method("perform_server_fire"):
		var logger2: Node = GameManager.get_core_system("logger")
		if logger2:
			logger2.trace("Firing weapon for player %d" % sender_id, "Combat")
		weapon_manager.perform_server_fire(origin, direction, weapon_index)


## Process a validated kill


func register_kill(victim_id: int, killer_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Dispatch event
	var gm_kill: Node = get_node_or_null("/root/GameManager")
	if gm_kill:
		gm_kill.emit_event("player_died", {"peer_id": victim_id, "killer_id": killer_id})

	# Update score via MatchService
	var gameplay_svc := gm_kill.get_core_system("gameplay") as GameplaySvc if gm_kill else null
	if gameplay_svc and gameplay_svc.match_service:
		gameplay_svc.match_service.add_score(killer_id, 100)  # KILL_SCORE
