class_name EnemyChaseState
extends EnemyState

@export var give_up_distance: float = 30.0
@export var give_up_time: float = 5.0

var _lost_timer: float = 0.0


func enter() -> void:
	# Chase has no entry side effects; target steering runs in physics_update.
	pass


func exit() -> void:
	# Disable fighting stance when leaving chase
	var enemy: Node = controller.parent_body
	if is_instance_valid(enemy) and "visuals" in enemy and enemy.visuals:
		if enemy.visuals.has_method("set_fighting_stance"):
			enemy.visuals.set_fighting_stance(false)


func physics_update(delta: float) -> void:
	var target: Node3D = controller.target
	if not target or not is_instance_valid(target):
		_return_to_idle()
		return

	var dist: float = controller.parent_body.global_position.distance_to(target.global_position)

	# Enable fighting stance for melee enemies when close
	var enemy: Node = controller.parent_body
	if is_instance_valid(enemy) and "visuals" in enemy and enemy.visuals:
		# Check if this is a melee enemy
		var is_melee: bool = false
		if "attack_type" in enemy and enemy.attack_type == "melee":
			is_melee = true

		# Enable stance when within ~8m of target for melee enemies
		if is_melee and dist < 8.0:
			if enemy.visuals.has_method("set_fighting_stance"):
				enemy.visuals.set_fighting_stance(true)
		else:
			# Disable stance when far away or non-melee
			if enemy.visuals.has_method("set_fighting_stance"):
				enemy.visuals.set_fighting_stance(false)

	# Movement Logic
	if controller.movement:
		controller.movement.set_target_position(target.global_position)

	# Attack Logic
	if controller.combat and controller.combat.can_attack(target):
		if controller.has_node("AttackState"):
			controller.change_state(controller.get_node("AttackState"))
			return
		controller.combat.attack(target)

	# Give up logic
	if dist > give_up_distance:
		_lost_timer += delta

		# Try to dash if falling behind
		if controller.movement and controller.movement.can_dash:
			var to_target: Vector3 = (
				(target.global_position - controller.parent_body.global_position).normalized()
			)
			controller.movement.dash(to_target)

	else:
		_lost_timer = 0.0

		# Offensive Dash (Gap Closer)
		# If within range but outside attack range, dash in
		var attack_range: float = 2.0
		if controller.combat:
			attack_range = controller.combat.attack_range

		if dist > attack_range + 2.0 and dist < 10.0:
			if controller.movement and controller.movement.can_dash:
				var to_target: Vector3 = (
					(target.global_position - controller.parent_body.global_position).normalized()
				)
				controller.movement.dash(to_target)

	if _lost_timer > give_up_time:
		controller.target = null
		_return_to_idle()


func _return_to_idle() -> void:
	if controller.has_node("ReturnState"):
		controller.change_state(controller.get_node("ReturnState"))
	elif controller.has_node("IdleState"):
		controller.change_state(controller.get_node("IdleState"))
