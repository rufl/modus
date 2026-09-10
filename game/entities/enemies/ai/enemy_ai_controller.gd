class_name EnemyAIController
extends Node

@export var initial_state: EnemyState

var movement: MovementComponent
var perception: PerceptionComponent
var combat: CombatComponent
var health: HealthComponent
var current_state: EnemyState
var target: Node3D
var start_position: Vector3
var parent_body: CharacterBody3D
var _target_threat: Dictionary = {}

var _dodge_cooldown: float = 0.0

func _ready() -> void:
	parent_body = get_parent()
	start_position = parent_body.global_position

	# Find Components
	movement = parent_body.get_node_or_null("MovementComponent")
	perception = parent_body.get_node_or_null("PerceptionComponent")
	combat = parent_body.get_node_or_null("CombatComponent")
	health = parent_body.get_node_or_null("HealthComponent")

	if perception:
		perception.target_spotted.connect(_on_target_spotted)
		perception.target_lost.connect(_on_target_lost)
		perception.noise_heard.connect(_on_noise_heard)

	if initial_state:
		ensure_initial_state()
	else:
		ensure_initial_state()


func ensure_initial_state() -> void:
	if current_state:
		return

	if not parent_body:
		parent_body = get_parent()

	if initial_state:
		change_state(initial_state)
		return

	# Auto-find first child state.
	for child in get_children():
		if child is EnemyState:
			change_state(child)
			return


func _physics_process(delta: float) -> void:
	# Cooldowns
	if _dodge_cooldown > 0:
		_dodge_cooldown -= delta
	for tracked in _target_threat.keys():
		_target_threat[tracked] = maxf(0.0, float(_target_threat[tracked]) - delta * 0.5)

	# Check if AI is active (toggled by parent/showcase)
	if parent_body and "is_ai_active" in parent_body:
		if not parent_body.is_ai_active:
			return

	# The parent owns AI LOD cadence and returns the full elapsed interval so
	# throttling does not slow state timers, steering, or combat decisions.
	var update_delta: float = delta
	if parent_body and parent_body.has_method("consume_ai_update_delta"):
		update_delta = parent_body.consume_ai_update_delta(delta)
		if update_delta <= 0.0:
			return

	if current_state:
		current_state.physics_update(update_delta)
		current_state.update(update_delta)

	# Check for incoming projectiles/grenades
	_check_danger()


func change_state(new_state: EnemyState) -> void:
	if current_state:
		current_state.exit()

	current_state = new_state
	# Ensure state knows about controller
	current_state.controller = self

	# Sync state name to parent for HUD replication
	if parent_body and "ai_state_name" in parent_body:
		var raw_name: String = new_state.name.replace("Enemy", "").replace("State", "")
		parent_body.ai_state_name = raw_name

	current_state.enter()
	# print("Enemy AI State Changed to: ", new_state.name)
func _on_target_spotted(new_target: Node3D) -> void:
	target = new_target
	_target_threat[new_target] = maxf(float(_target_threat.get(new_target, 0.0)), 1.0)
	if has_node("ChaseState"):
		change_state(get_node("ChaseState"))


func _on_target_lost(old_target: Node3D) -> void:
	if old_target:
		_target_threat.erase(old_target)
	target = null

	# Return to appropriate default state
	# Priority: Patrol > Idle > stay in current state
	if has_node("PatrolState"):
		change_state(get_node("PatrolState"))
	elif has_node("IdleState"):
		change_state(get_node("IdleState"))
	# Else: stay in current state (e.g., Flee or special behavior)


func _on_noise_heard(pos: Vector3, _vol: float) -> void:
	# If idle, turn to face noise
	if current_state is EnemyIdleState:
		var look_pos: Vector3 = pos
		look_pos.y = parent_body.global_position.y

		# Avoid colinear vectors warning
		if look_pos.distance_squared_to(parent_body.global_position) > 0.01:
			var direction: Vector3 = (look_pos - parent_body.global_position).normalized()
			if abs(direction.dot(Vector3.UP)) < 0.99:
				parent_body.look_at(look_pos, Vector3.UP)
			else:
				parent_body.look_at(look_pos, Vector3.FORWARD)

	# If patrolling, investigate noise
	elif current_state is EnemyPatrolState:
		if movement:
			movement.set_target_position(pos)


func interrupt_for_pain() -> void:
	## Interrupt current AI action for pain state
	## Called when enemy takes significant damage and enters pain state

	# Stop current movement
	if movement:
		movement.stop()

	# If in attack state, interrupt the attack
	if current_state and current_state.has_method("interrupt"):
		current_state.interrupt()

	# Brief pause before resuming AI (pain duration is handled by pain system)
	# The AI will naturally resume after pain state ends
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info(
			(
				"[AI] Interrupted for pain - enemy: "
				+ str(String(parent_body.name) if parent_body else "unknown")
			),
			"Enemy"
		)


func on_damage_received(attacker: Node3D, damage_amount: float) -> void:
	if not attacker:
		return

	_target_threat[attacker] = float(_target_threat.get(attacker, 0.0)) + maxf(damage_amount, 1.0)
	var current_threat: float = float(_target_threat.get(target, 0.0)) if target and is_instance_valid(target) else -1.0
	var should_switch: bool = not target or not is_instance_valid(target) or _target_threat[attacker] >= current_threat
	if not should_switch:
		return

	target = attacker
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info("[AI] Retaliating against: %s" % attacker.name, "Enemy")
	# Low Health Check (Crisis Mode)
	if health and health.max_health > 0:
		var health_percent: float = health.current_health / health.max_health
		if health_percent < 0.3:
			if "is_downed" in parent_body:
				parent_body.is_downed = true
			if has_node("FleeState"):
				change_state(get_node("FleeState"))
				return

	# Transition to combat/chase immediately
	if has_node("ChaseState"):
		change_state(get_node("ChaseState"))
	elif has_node("AttackState"):
		change_state(get_node("AttackState"))


func _check_danger() -> void:
	if not parent_body:
		return

	# Only scan occasionally or if in combat? For now, always scan (radius is small)

	# Scan for projectiles in radius
	# var space_state: PhysicsDirectSpaceState3D = parent_body.get_world_3d().direct_space_state
	var detection_radius: float = 6.0

	# Optimization: Instead of expensive sphere query every frame,
	# iterate known projectiles group if small, OR use a Area3D sensor.
	# For now, let's iterate the "projectiles" group as it's usually < 20 active.

	var danger_node: Node3D = null
	var min_dist: float = 999.0

	for node in get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(node):
			continue
		if node is Node3D:
			var dist: float = parent_body.global_position.distance_to(node.global_position)
			if dist < detection_radius:
				# Check if moving towards us?
				# For simplified logic: avoid any close projectile.
				if dist < min_dist:
					min_dist = dist
					danger_node = node

	if danger_node:
		# SWARMLING LOGIC: Reflect Grenade
		if parent_body.enemy_id == "swarmling" and danger_node.is_in_group("grenades"):
			if min_dist < 2.5:  # Close enough to grab
				_try_reflect_grenade(danger_node)
				return

		# EVASION LOGIC: Roll Away
		# Only evade if we have stamina/cooldown
		if _dodge_cooldown <= 0.0 and min_dist < 4.0:
			_try_evade_projectile(danger_node)


func _try_evade_projectile(projectile: Node3D) -> void:
	# Reaction time and Cooldown check
	if _dodge_cooldown > 0 or randf() > 0.3:
		return

	_dodge_cooldown = randf_range(1.5, 4.0)  # Prevent roll spam

	# Roll away from projectile velocity or position
	var dir_away: Vector3 = (parent_body.global_position - projectile.global_position).normalized()

	# If projectile has velocity, dodge perpendicular
	if "linear_velocity" in projectile:
		var vel: Vector3 = projectile.linear_velocity
		if vel.length_squared() > 1.0:
			# Cross product for perpendicular dodge
			var right: Vector3 = vel.cross(Vector3.UP).normalized()
			if randf() > 0.5:
				dir_away = right
			else:
				dir_away = -right

	# Trigger roll via Visuals (if supported) or State
	# We can override velocity directly for a moment
	if parent_body is CharacterBody3D:
		parent_body.velocity += dir_away * 10.0

	# Play roll anim
	if parent_body.visuals and parent_body.visuals.has_method("play_roll"):
		parent_body.visuals.play_roll()


func _try_reflect_grenade(grenade: Node3D) -> void:
	# 50% chance to reflect
	if randf() > 0.5:
		# Flee instead
		_try_evade_projectile(grenade)
		return

	# print("Swarmling reflecting grenade!")

	# Play pickup/throw animation (using generic interact or attack)
	if parent_body.visuals and parent_body.visuals.has_method("play_telegraph"):
		parent_body.visuals.play_telegraph()  # Raise arm

	# Delete old grenade
	grenade.queue_free()

	# Feedback: Play sound and spawn floating text
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	if gs and gs.effects:
		gs.effects.spawn_floating_text(
			parent_body.global_position + Vector3.UP * 2.0, "CAUGHT!", Color.YELLOW
		)

	var audio: Node = gm.get_core_system("audio") if gm else null
	if audio and parent_body:
		audio.play_sfx_at_position("grabbed", parent_body.global_position)


func set_active(active: bool) -> void:
	if not active and current_state:
		current_state.exit()
		# Optionally switch to idle or just stop processing

	set_physics_process(active)
	set_process(active)
