class_name EnemyAIFactory
extends RefCounted


static func create_states(controller: EnemyAIController, data: Dictionary) -> void:
	# Remove existing states if any
	for child in controller.get_children():
		if child is EnemyState:
			child.queue_free()

	# Add core states (always present)
	_add_core_states(controller)

	# Behavior-specific states
	var behavior: String = data.get("ai_config", {}).get("behavior", "aggressive")
	_add_behavior_states(controller, behavior)

	# Ability states
	if "abilities" in data:
		_add_ability_states(controller, data.abilities)

	# Flee state
	if "ai_config" in data:
		var flee_threshold: float = data.ai_config.get("flee_threshold", 0.0)
		if flee_threshold > 0.0:
			_add_flee_state(controller, flee_threshold)

	# Patrol State (if configured)
	if "patrol" in data:
		_add_patrol_state(controller, data.patrol)
	elif behavior == "scout":  # Fallback for backward compatibility
		_add_patrol_state(controller, {"type": "random", "radius": 15.0, "hold_time": 1.0})

	# Set initial state
	_set_initial_state(controller, behavior)


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


static func _add_behavior_states(_controller: EnemyAIController, _behavior: String) -> void:
	# Behavior-specific state additions can be implemented here
	pass


static func _add_ability_states(controller: EnemyAIController, abilities: Dictionary) -> void:
	# Healer Logic
	if abilities.get("heal_allies", false):
		var healer := EnemyHealerState.new()
		healer.name = "HealerState"
		healer.heal_range = abilities.get("heal_radius", 10.0)
		healer.heal_amount = abilities.get("heal_amount", 20.0)
		controller.add_child(healer)

	# Summoner Logic
	if abilities.get("summon_minions", false):
		var summoner := EnemySummonerState.new()
		summoner.name = "SummonerState"
		summoner.minion_type = abilities.get("minion_type", "swarmling")
		summoner.max_minions = abilities.get("summon_count", 3)
		summoner.summon_cooldown = abilities.get("summon_cooldown", 10.0)
		controller.add_child(summoner)

	# Teleport Logic (Bosses)
	if abilities.get("teleport", false):
		var teleport := EnemyTeleportState.new()
		teleport.name = "TeleportState"
		teleport.teleport_cooldown = abilities.get("teleport_cooldown", 6.0)
		controller.add_child(teleport)

	# Boss Specials (Charge/Stomp)
	if abilities.get("charge_attack", false) or abilities.get("ground_pound", false):
		var specials := EnemyBossSpecialsState.new()
		specials.name = "BossSpecialsState"
		if abilities.has("charge_cooldown"):
			specials.charge_cooldown = abilities.charge_cooldown
		if abilities.has("pound_radius"):
			specials.stomp_radius = abilities.pound_radius
		if abilities.has("pound_damage"):
			specials.stomp_damage = abilities.pound_damage
		controller.add_child(specials)


static func _add_flee_state(controller: EnemyAIController, _flee_threshold: float) -> void:
	var flee := EnemyFleeState.new()
	flee.name = "FleeState"
	flee.flee_distance = 15.0  # Could expose to config
	controller.add_child(flee)


static func _set_initial_state(controller: EnemyAIController, behavior: String) -> void:
	if behavior == "scout":
		var patrol := controller.get_node_or_null("PatrolState")
		if patrol:
			controller.initial_state = patrol
	if behavior == "scout":
		var patrol: Node = controller.get_node_or_null("PatrolState")
		if patrol:
			controller.initial_state = patrol
			return

	# If patrol is configured, prioritize it over idle
	if controller.has_node("PatrolState"):
		controller.initial_state = controller.get_node("PatrolState")
		return

	# Default to idle
	var idle: Node = controller.get_node_or_null("IdleState")
	if idle:
		controller.initial_state = idle
