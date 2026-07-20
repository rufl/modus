extends Area3D
class_name EnemyProjectile

@export var speed: float = 20.0
@export var damage: int = 1
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.FORWARD
var shooter_id: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Auto-destroy after lifetime
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	# Only server moves projectiles (in singleplayer, we ARE the server)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	global_position += direction * speed * delta


func _on_body_entered(body: Node3D) -> void:
	call_deferred("_deferred_on_body_entered", body)


func _deferred_on_body_entered(body: Node3D) -> void:
	# Only server handles collision (in singleplayer, we ARE the server)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if not is_instance_valid(self) or is_queued_for_deletion():
		return

	if body is CharacterBody3D:
		if body is Enemy:
			return

		# Deal damage to player via GameplayService.combat for consistency
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.combat:
			# Source is the projectile/environment, Or projectile type
			# Weapon Source, Is Critical, Source ID Override
			gs.combat.apply_damage(
				body, damage, null, DamageInfo.DamageType.EXPLOSION, null, false, shooter_id
			)
		else:
			# Fallback if service missing
			if body.has_method("receive_damage"):
				body.receive_damage.rpc_id(
					body.get_multiplayer_authority(), damage, shooter_id, global_position
				)

		queue_free()
	else:
		queue_free()
