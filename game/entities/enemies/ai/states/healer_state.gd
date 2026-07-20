class_name EnemyHealerState
extends EnemyState

@export var heal_range: float = 10.0
@export var heal_amount: float = 20.0
@export var heal_cooldown: float = 5.0
@export var heal_threshold: float = 0.6  # Heal allies under 60% HP

var _timer: float = 0.0


func enter() -> void:
	if controller.movement:
		controller.movement.stop()


func update(delta: float) -> void:
	_timer -= delta

	if _timer <= 0.0:
		_try_heal_ally()


func _try_heal_ally() -> void:
	# Find allies in range
	var allies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var lowest_hp_pct: float = 1.0

	for ally: Node3D in allies:
		if ally == controller.parent_body:
			continue  # Don't self-heal in this simple logic

		if not is_instance_valid(ally):
			continue

		var dist_sq: float = controller.parent_body.global_position.distance_squared_to(
			ally.global_position
		)
		if dist_sq > heal_range * heal_range:
			continue

		# Check HP
		if ally.has_node("HealthComponent"):
			var hp_comp: HealthComponent = ally.get_node("HealthComponent")
			var pct: float = hp_comp.current_health / hp_comp.max_health
			if pct < heal_threshold and pct < lowest_hp_pct:
				lowest_hp_pct = pct
				best_target = ally

	if best_target:
		_perform_heal(best_target)
	else:
		# No one to heal, maybe attack player?
		if controller.target and is_instance_valid(controller.target):
			# If player is close, fight back
			var dist: float = controller.parent_body.global_position.distance_to(
				controller.target.global_position
			)
			if dist < 15.0:
				if controller.has_node("AttackState"):
					controller.change_state(controller.get_node("AttackState"))


func _perform_heal(target: Node3D) -> void:
	# Face target (with colinear vector check)
	var target_pos: Vector3 = target.global_position
	var my_pos: Vector3 = controller.parent_body.global_position

	if target_pos.distance_squared_to(my_pos) > 0.01:
		var direction: Vector3 = (target_pos - my_pos).normalized()
		if abs(direction.dot(Vector3.UP)) < 0.99:
			controller.parent_body.look_at(target_pos, Vector3.UP)
		else:
			controller.parent_body.look_at(target_pos, Vector3.FORWARD)

	# Apply heal (assumes HealthComponent has heal method or we modify verify directly)
	if target.has_node("HealthComponent"):
		var hp_comp: HealthComponent = target.get_node("HealthComponent")
		# Simple direct heal for now
		if hp_comp.has_method("heal"):
			hp_comp.heal(heal_amount)
		else:
			var new_hp: float = min(hp_comp.current_health + heal_amount, hp_comp.max_health)
			hp_comp.current_health = new_hp

	# Visuals (could spawn particle)
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info(
				"[Healer] Healed %s for %.1f" % [target.name, heal_amount], "Enemy"
			)

	_timer = heal_cooldown
