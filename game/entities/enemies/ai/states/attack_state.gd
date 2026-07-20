class_name EnemyAttackState
extends EnemyState

var _telegraphing: bool = false
var _telegraph_timer: float = 0.0
var _crouch_cooldown: float = 0.0
var _evasion_cooldown: float = 0.0


func enter() -> void:
	if controller.movement:
		controller.movement.stop()

	# Start telegraph
	_telegraphing = true
	_telegraph_timer = 0.4  # Telegraph duration

	# Trigger visual
	var enemy: Node = controller.parent_body
	if enemy and "visuals" in enemy and enemy.visuals:
		if enemy.visuals.has_method("play_telegraph"):
			enemy.visuals.play_telegraph()

	# Sync telegraph (visuals usually handling sync themselves or need manual RPC)
	if is_instance_valid(enemy) and enemy.has_method("rpc_telegraph"):
		enemy.rpc_telegraph()


func physics_update(delta: float) -> void:
	var target: Node3D = controller.target
	if not target or not is_instance_valid(target):
		_return_to_chase()
		return

	# Face target
	var target_look_pos: Vector3 = target.global_position + Vector3(0, 1, 0)
	var my_pos: Vector3 = controller.parent_body.global_position

	# Avoid colinear vectors warning - check if target is at same position
	if target_look_pos.distance_squared_to(my_pos) > 0.01:
		# Check if direction and up vector would be colinear
		var direction: Vector3 = (target_look_pos - my_pos).normalized()
		if abs(direction.dot(Vector3.UP)) < 0.99:  # Not parallel to UP
			controller.parent_body.look_at(target_look_pos, Vector3.UP)
		else:
			# Use alternative up vector when looking straight up/down
			controller.parent_body.look_at(target_look_pos, Vector3.FORWARD)

	controller.parent_body.rotation.x = 0  # Keep upright

	# Handle Telegraph Delay
	if _telegraphing:
		_telegraph_timer -= delta
		if _telegraph_timer <= 0:
			_telegraphing = false
		else:
			return  # Wait for telegraph

	if controller.combat:
		if controller.combat.can_attack(target):
			controller.combat.attack(target)
		else:
			# If target moved out of range, chase
			var body: Node3D = controller.parent_body
			var dist_sq: float = body.global_position.distance_squared_to(target.global_position)
			var range_sq: float = controller.combat.attack_range ** 2 * 1.2
			if dist_sq > range_sq:
				_return_to_chase()
			else:
				# Evasion Chance (Roll while waiting/fighting)
				# Evasion Chance (Roll while waiting/fighting)
				# Evasion with cooldown
				if _evasion_cooldown <= 0.0:
					if randf() < 0.005:  # Reduced from 0.02
						_try_evasive_roll()
						_evasion_cooldown = randf_range(4.0, 10.0)  # Increased cooldown
				else:
					_evasion_cooldown -= delta

				_update_combat_posture(delta)


func _update_combat_posture(_delta: float) -> void:
	# Random crouching to throw off aim
	# Or check if we need to crouch to see target? (e.g. low obstacle)
	# For now, just random toggling during combat
	var enemy: Node = controller.parent_body
	if not enemy:
		return

	# Random Crouch Toggle with cooldown - only if enemy supports crouching
	if "is_crouching" in enemy:
		if _crouch_cooldown <= 0.0:
			# Only roll for crouch occasionally (once per sec approx, via 0.01 per frame)
			if not enemy.is_crouching and randf() < 0.01:
				enemy.is_crouching = true
				_crouch_cooldown = randf_range(3.0, 6.0)  # Stay down for 3-6s
			elif enemy.is_crouching:
				# Auto-stand after cooldown
				enemy.is_crouching = false
				_crouch_cooldown = randf_range(5.0, 15.0)  # Wait 5-15s before next crouch
		else:
			_crouch_cooldown -= _delta  # Decr cooldown (already in physics_update)

	# Cover Peeking (Lean)
	# Raycast from center, left, right to target
	var target: Node3D = controller.target
	if not target:
		return

	var space_state: PhysicsDirectSpaceState3D = enemy.get_world_3d().direct_space_state
	var my_head: Vector3 = enemy.global_position + Vector3(0, 1.5, 0)  # Approx head
	var target_head: Vector3 = target.global_position + Vector3(0, 1.0, 0)

	# Center Check
	var center_blocked: bool = _is_line_blocked(space_state, my_head, target_head, enemy, target)

	var lean_target: float = 0.0

	if center_blocked:
		# Check Left Lean
		var left_origin: Vector3 = my_head - enemy.global_transform.basis.x * 0.5
		if not _is_line_blocked(space_state, left_origin, target_head, enemy, target):
			lean_target = -1.0  # Lean Left
		else:
			# Check Right Lean
			var right_origin: Vector3 = my_head + enemy.global_transform.basis.x * 0.5
			if not _is_line_blocked(space_state, right_origin, target_head, enemy, target):
				lean_target = 1.0  # Lean Right

	# Smoothly apply lean (only if Enemy has lean_amount property)
	if "lean_amount" in enemy:
		enemy.lean_amount = lerp(enemy.lean_amount, lean_target, 5.0 * _delta)

	# Switch Hand if Leaning
	if enemy.visuals and enemy.visuals.has_method("attach_weapon_to_hand"):
		if lean_target < -0.1:
			enemy.visuals.attach_weapon_to_hand("left")
		elif lean_target > 0.1:
			enemy.visuals.attach_weapon_to_hand("right")
		else:
			# Default to right if center? Or keep last? Keep last is better to avoid flip-flop.
			# But user might want standard right hand when neutral.
			enemy.visuals.attach_weapon_to_hand("right")


func _is_line_blocked(
	space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, self_node: Node, target_node: Node
) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self_node.get_rid()]
	# query.collision_mask = 1 # World only?
	var result: Dictionary = space.intersect_ray(query)

	if result:
		if result.collider == target_node:
			return false  # Clear line to target
		return true  # Hit something else (wall)
	return false  # Clear (or out of range)


func _try_evasive_roll() -> void:
	var enemy: Node = controller.parent_body
	if enemy and "visuals" in enemy and enemy.visuals:
		if enemy.visuals.has_method("play_roll"):
			# Don't roll if already playing (simple check)
			enemy.visuals.play_roll()
			# Apply some velocity?
			if enemy is CharacterBody3D:
				# Roll sideways
				var right: Vector3 = enemy.global_transform.basis.x
				var roll_dir: Vector3 = right if randf() > 0.5 else -right
				enemy.velocity += roll_dir * 5.0


func _return_to_chase() -> void:
	if controller.has_node("ChaseState"):
		controller.change_state(controller.get_node("ChaseState"))
	else:
		# Fallback
		if controller.has_node("IdleState"):
			controller.change_state(controller.get_node("IdleState"))
