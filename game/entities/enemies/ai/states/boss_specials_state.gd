class_name EnemyBossSpecialsState
extends EnemyState

@export var charge_cooldown: float = 8.0
@export var charge_speed_mult: float = 3.0
@export var stomp_cooldown: float = 12.0
@export var stomp_radius: float = 6.0
@export var stomp_damage: float = 40.0

var _charge_timer: float = 5.0  # Initial delay
var _stomp_timer: float = 10.0
var _is_charging: bool = false
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_duration_timer: float = 0.0
var _combat_service: Node = null


func update(delta: float) -> void:
	var gm_update: Node = get_node_or_null("/root/GameManager")
	var gs := gm_update.get_core_system("gameplay") as GameplaySvc if gm_update else null
	_combat_service = gs.combat if gs else null
	if not _combat_service:
		push_warning("[BossSpecials] Combat Service not available")
		return

	if _charge_timer > 0:
		_charge_timer -= delta
	if _stomp_timer > 0:
		_stomp_timer -= delta

	if _is_charging:
		_process_charge(delta)
		return

	# Priorities: Stomp > Charge
	if _stomp_timer <= 0:
		_try_stomp()
		return

	if _charge_timer <= 0:
		_try_charge()


func _try_stomp() -> void:
	var target: Node3D = controller.target
	if not target:
		return

	var dist: float = controller.parent_body.global_position.distance_to(target.global_position)
	if dist < stomp_radius:
		_perform_stomp()


func _perform_stomp() -> void:
	var body: CharacterBody3D = controller.parent_body

	# Feedback
	if body.visuals and body.visuals.has_method("play_stomp"):
		body.visuals.play_stomp()

	var gm_stomp: Node = get_node_or_null("/root/GameManager")
	var gs := gm_stomp.get_core_system("gameplay") as GameplaySvc if gm_stomp else null
	if gs and gs.effects:
		# spawn_explosion(position, explosion_type, damage, radius)
		gs.effects.spawn_explosion.rpc(body.global_position, 2, 50.0, 1.5)  # LARGE explosion

	# Damage players in radius
	if gs and gs.combat:
		for player in get_tree().get_nodes_in_group("player"):
			if body.global_position.distance_to(player.global_position) < stomp_radius:
				gs.combat.apply_damage(player, stomp_damage, body, DamageInfo.DamageType.EXPLOSION)

	_stomp_timer = stomp_cooldown
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info(
				"[Boss] %s performed Ground Pound!" % body.name, "Enemy"
			)


func _try_charge() -> void:
	var target: Node3D = controller.target
	if not target:
		return

	var dist: float = controller.parent_body.global_position.distance_to(target.global_position)
	if dist > 10.0 and dist < 25.0:  # Optimal charge distance
		_start_charge(target.global_position)


func _start_charge(target_pos: Vector3) -> void:
	_is_charging = true
	_charge_duration_timer = 2.0  # Max charge time
	_charge_dir = (target_pos - controller.parent_body.global_position).normalized()
	_charge_dir.y = 0

	if controller.movement:
		controller.movement.stop()

	var gm2: Node = get_node_or_null("/root/GameManager")
	if gm2:
		var logger2: Node = gm2.get_core_system("logger")
		if logger2:
			logger2.info(
				"[Boss] %s is charging!" % controller.parent_body.name, "Enemy"
			)


func _process_charge(delta: float) -> void:
	_charge_duration_timer -= delta
	if _charge_duration_timer <= 0.0:
		_stop_charge()
		return

	var body: CharacterBody3D = controller.parent_body
	body.velocity = _charge_dir * (controller.movement.speed * charge_speed_mult)
	body.move_and_slide()

	# Check for hit
	for i in range(body.get_slide_collision_count()):
		var collision: KinematicCollision3D = body.get_slide_collision(i)
		var collider: Node = collision.get_collider()
		if collider.is_in_group("player"):
			if _combat_service:
				_combat_service.apply_damage(collider, 50.0, body, DamageInfo.DamageType.MELEE)
			_stop_charge()
			return

	# If hit wall
	if body.is_on_wall():
		_stop_charge()


func _stop_charge() -> void:
	_is_charging = false
	_charge_timer = charge_cooldown
	if controller.movement:
		controller.movement.resume()
