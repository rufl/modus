class_name EnemyTeleportState
extends EnemyState

@export var teleport_cooldown: float = 6.0
@export var min_dist: float = 10.0
@export var max_dist: float = 20.0

var _timer: float = 0.0


func enter() -> void:
	_timer = 0.0  # Ready to teleport if hurt

	# Listen for damage (could be connected via controller or signals)
	if controller.health:
		if not controller.health.damage_received.is_connected(_on_damage_received):
			controller.health.damage_received.connect(_on_damage_received)


func exit() -> void:
	if controller.health:
		if controller.health.damage_received.is_connected(_on_damage_received):
			controller.health.damage_received.disconnect(_on_damage_received)


func update(delta: float) -> void:
	if _timer > 0:
		_timer -= delta


func _on_damage_received(_amount: float, _attacker: Node3D) -> void:
	if _timer <= 0.0:
		_perform_teleport()


func _perform_teleport() -> void:
	var body: CharacterBody3D = controller.parent_body
	if not body:
		return

	# Find valid position on navmesh
	var nav_map: RID = body.get_world_3d().navigation_map
	if not nav_map.is_valid():
		return

	# Try random directions
	for i in range(10):
		var dir: Vector3 = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()

		var dist: float = randf_range(min_dist, max_dist)
		var target_pos: Vector3 = body.global_position + dir * dist

		var closest: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, target_pos)

		# Verify it's far enough and on the same level (approx)
		if closest.distance_to(body.global_position) > min_dist * 0.5:
			if abs(closest.y - body.global_position.y) < 2.0:
				_teleport_to(closest)
				return


func _teleport_to(dest: Vector3) -> void:
	var body: CharacterBody3D = controller.parent_body

	# Feedback BEFORE
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var effects: Node = gm.get_core_system("effects")
		if effects:
			# spawn_explosion(position, explosion_type, damage, radius)
			effects.spawn_explosion.rpc(body.global_position, 0, 0.0, 0.5)

	# Move
	body.global_position = dest + Vector3.UP * 0.5

	# Feedback AFTER
	if gm:
		var effects2: Node = gm.get_core_system("effects")
		if effects2:
			# spawn_explosion(position, explosion_type, damage, radius)
			effects2.spawn_explosion.rpc(body.global_position, 0, 0.0, 0.5)

	_timer = teleport_cooldown
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info("[Teleport] %s blinked to %s" % [body.name, dest], "Enemy")
