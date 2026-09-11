class_name EnemyAIFactory
extends RefCounted


static func create_states(controller: EnemyAIController, data: Dictionary) -> void:
	# Remove existing states if any
	for child in controller.get_children():
		if child is EnemyState:
			child.queue_free()

	# Add core states (always present)
	_add_core_states(controller)

	var behavior: String = _resolve_behavior(data)
	controller.set_meta("configured_behavior", behavior)
	var abilities: Dictionary = data.get("abilities", {})

	# Ability states
	if not abilities.is_empty():
		_add_ability_states(controller, abilities)
	_add_behavior_states(controller, behavior, abilities)

	# Flee state
	var ai_config: Dictionary = data.get("ai_config", {})
	var flee_threshold: float = float(ai_config.get("flee_threshold", 0.0))
	if flee_threshold > 0.0:
		_add_flee_state(controller, flee_threshold)

	# Patrol State (if configured)
	if "patrol" in data:
		_add_patrol_state(controller, data.patrol)
	elif behavior == "scout":
		_add_patrol_state(controller, {"type": "random", "radius": 15.0, "hold_time": 1.0})

	# Set initial state
	_set_initial_state(controller, behavior)


static func _resolve_behavior(data: Dictionary) -> String:
	var ai_config: Dictionary = data.get("ai_config", {})
	var behavior := str(ai_config.get("behavior", "")).strip_edges().to_lower()
	var role := str(data.get("role", "")).strip_edges().to_lower()

	# EnemyData historically emits "aggressive" for every role. Prefer the
	# authored support role in that case so support enemies do not attack by
	# silently falling through the aggressive default.
	if (
		behavior.is_empty()
		or (behavior == "aggressive" and role in ["support", "healer", "summoner", "rally"])
	):
		behavior = role
	return behavior if not behavior.is_empty() else "aggressive"


static func _add_core_states(controller: EnemyAIController) -> void:
	var idle := EnemyIdleState.new()
	idle.name = "IdleState"
	controller.add_child(idle)

	var return_state := EnemyReturnState.new()
	return_state.name = "ReturnState"
	controller.add_child(return_state)

	var chase := EnemyChaseState.new()
	chase.name = "ChaseState"
	controller.add_child(chase)

	var attack := EnemyAttackState.new()
	attack.name = "AttackState"
	controller.add_child(attack)


static func _add_patrol_state(controller: EnemyAIController, config: Dictionary) -> void:
	var patrol := EnemyPatrolState.new()
	patrol.name = "PatrolState"
	controller.add_child(patrol)

	patrol.configure(
		config.get("type", "random"), config.get("radius", 10.0), config.get("hold_time", 2.0)
	)

	# Enable patrol on idle state if present
	var idle: Node = controller.get_node_or_null("IdleState")
	if idle and "can_patrol" in idle:
		idle.set("can_patrol", true)


static func _add_behavior_states(
	controller: EnemyAIController, behavior: String, abilities: Dictionary
) -> void:
	match behavior:
		"healer":
			if not controller.has_node("HealerState"):
				_add_ability_states(
					controller,
					{
						"heal_allies": true,
						"heal_radius": abilities.get("heal_radius", 10.0),
						"heal_amount": abilities.get("heal_amount", 20.0)
					}
				)
		"summoner":
			if not controller.has_node("SummonerState"):
				_add_ability_states(
					controller,
					{
						"summon_minions": true,
						"minion_type": abilities.get("minion_type", "swarmling"),
						"summon_count":
						abilities.get("summon_count", abilities.get("max_summons", 3)),
						"summon_cooldown": abilities.get("summon_cooldown", 10.0)
					}
				)
		"aggressive", "basic", "damage", "swarm", "scout", "defensive", "support":
			# These behaviors use the core states; defensive/support start in
			# idle or patrol rather than an implicit aggressive state.
			pass
		"rally":
			push_error(
				"[EnemyAIFactory] Rally behavior is unsupported: no rally state exists; using idle"
			)
		_:
			push_error("[EnemyAIFactory] Unsupported enemy behavior '%s'; using idle" % behavior)


static func _add_ability_states(controller: EnemyAIController, abilities: Dictionary) -> void:
	# Healer Logic
	if abilities.get("heal_allies", false):
		var healer := EnemyHealerState.new()
		healer.name = "HealerState"
		healer.heal_range = float(abilities.get("heal_radius", 10.0))
		healer.heal_amount = float(abilities.get("heal_amount", 20.0))
		controller.add_child(healer)

	# Summoner Logic (accept both current and EnemyData's legacy keys)
	if abilities.get("summon_minions", abilities.get("summon", false)):
		var summoner := EnemySummonerState.new()
		summoner.name = "SummonerState"
		summoner.minion_type = str(abilities.get("minion_type", "swarmling"))
		summoner.max_minions = int(abilities.get("summon_count", abilities.get("max_summons", 3)))
		summoner.summon_cooldown = float(abilities.get("summon_cooldown", 10.0))
		controller.add_child(summoner)

	# Teleport Logic (Bosses)
	if abilities.get("teleport", false):
		var teleport := EnemyTeleportState.new()
		teleport.name = "TeleportState"
		teleport.teleport_cooldown = float(abilities.get("teleport_cooldown", 6.0))
		controller.add_child(teleport)

	# Boss Specials (Charge/Stomp)
	if abilities.get("charge_attack", false) or abilities.get("ground_pound", false):
		var specials := EnemyBossSpecialsState.new()
		specials.name = "BossSpecialsState"
		if abilities.has("charge_cooldown"):
			specials.charge_cooldown = float(abilities.charge_cooldown)
		if abilities.has("pound_radius"):
			specials.stomp_radius = float(abilities.pound_radius)
		if abilities.has("pound_damage"):
			specials.stomp_damage = float(abilities.pound_damage)
		controller.add_child(specials)

	if abilities.get("rally_allies", false):
		push_error(
			"[EnemyAIFactory] rally_allies is unsupported: no rally state exists; ally buffs disabled"
		)


static func _add_flee_state(controller: EnemyAIController, _flee_threshold: float) -> void:
	var flee := EnemyFleeState.new()
	flee.name = "FleeState"
	flee.flee_distance = 15.0  # Could expose to config
	controller.add_child(flee)


static func _set_initial_state(controller: EnemyAIController, behavior: String) -> void:
	if behavior in ["healer", "support"] and controller.has_node("HealerState"):
		controller.initial_state = controller.get_node("HealerState")
		return
	if behavior in ["summoner", "support"] and controller.has_node("SummonerState"):
		controller.initial_state = controller.get_node("SummonerState")
		return
	if behavior == "scout" and controller.has_node("PatrolState"):
		controller.initial_state = controller.get_node("PatrolState")
		return

	# Defensive and support roles deliberately remain idle/patrolling until
	# their dedicated ability state has work to do.
	if controller.has_node("PatrolState"):
		controller.initial_state = controller.get_node("PatrolState")
		return

	var idle: Node = controller.get_node_or_null("IdleState")
	if idle:
		controller.initial_state = idle
