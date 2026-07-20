class_name GrenadeProjectile
extends RigidBody3D

const RocketTrailSetup = preload("res://game/entities/projectiles/rocket_trail_setup.gd")

@export var speed: float = 20.0
@export var up_impulse: float = 8.0
@export var damage: float = 120.0
@export var splash_radius: float = 5.5
@export var damage_type: int = DamageInfo.DamageType.EXPLOSIVE
@export var explosion_scene: PackedScene
@export var shooter_id: int = 0

var shooter: Node3D = null
var launch_time: float = 0.0
var pool_scene_path: String = ""
var _spawn_generation: int = 0

var _has_exploded: bool = false
var _trails_setup: bool = false


func _ready() -> void:
	if not explosion_scene:
		explosion_scene = load("res://game/entities/projectiles/explosion_quake.tscn")

	# Setup retro pixelated trails (only once)
	if not _trails_setup:
		RocketTrailSetup.setup_smoke_trail(self)
		_trails_setup = true

	contact_monitor = false  # Disabled until launch
	max_contacts_reported = 4
	freeze = true  # Frozen until launch

	# SIGNAL HYGIENE: Check if already connected before connecting
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Create detection area for enemies (body_entered won't work due to layer mismatch)
	_setup_detection_area()

	# 2.5s fuse - MOVED TO LAUNCH()

	# Start trails - MOVED TO LAUNCH()
	var smoke: GPUParticles3D = get_node_or_null("SmokeTrail")
	if smoke:
		smoke.emitting = false

	_resolve_shooter()


func _setup_detection_area() -> void:
	var area: Area3D = get_node_or_null("DetectionArea")
	if not area:
		area = Area3D.new()
		area.name = "DetectionArea"
		area.collision_layer = 0
		area.collision_mask = CollisionLayers.LAYER_ENEMIES | CollisionLayers.LAYER_PLAYERS
		area.monitoring = true
		area.monitorable = false

		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.25
		shape.shape = sphere
		area.add_child(shape)

		add_child(area)

	if not area.body_entered.is_connected(_on_detection_area_body_entered):
		area.body_entered.connect(_on_detection_area_body_entered)


func _on_detection_area_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
	if body.is_in_group("enemies") or body.is_in_group("players"):
		call_deferred("explode")


func _resolve_shooter() -> void:
	if shooter_id > 0 and not shooter:
		var tree := get_tree()
		if tree and tree.current_scene:
			shooter = tree.current_scene.get_node_or_null(str(shooter_id))

	if shooter:
		add_collision_exception_with(shooter)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.linear_velocity.length() < 1.0:
		state.angular_velocity = state.angular_velocity.lerp(Vector3.ZERO, 0.1)


func launch(global_pos: Vector3, direction: Vector3, owner_node: Node3D = null) -> void:
	visible = true
	global_position = global_pos
	shooter = owner_node

	look_at(global_pos + direction, Vector3.UP)

	var fwd: Vector3 = direction.normalized()
	var sway: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), 0)

	linear_velocity = fwd * speed + Vector3.UP * up_impulse + sway
	angular_velocity = Vector3(5.2, 5.2, 5.2)

	freeze = false
	contact_monitor = true

	# Start fuse - TIMER SAFETY: Use bound method, not lambda
	_spawn_generation += 1
	var current_gen: int = _spawn_generation
	get_tree().create_timer(2.5).timeout.connect(
		_on_fuse_timeout.bind(current_gen), CONNECT_ONE_SHOT
	)

	# Start trails
	var smoke: GPUParticles3D = get_node_or_null("SmokeTrail")
	if smoke:
		smoke.emitting = true
		smoke.restart()

	var mesh: Node3D = get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = true


func explode() -> void:
	if _has_exploded:
		return
	_has_exploded = true

	# Stop trails
	var smoke: GPUParticles3D = get_node_or_null("SmokeTrail")
	if smoke:
		smoke.emitting = false

	# Hide Mesh
	var mesh: Node3D = get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false

	# Disable physics
	set_physics_process(false)
	freeze = true

	# Spawn Explosion
	if multiplayer.is_server():
		var net_effects: Node = GameManager.get_core_system("effects")
		if net_effects:
			# spawn_explosion(position, explosion_type, damage, radius)
			# ExplosionType.MEDIUM
			net_effects.spawn_explosion.rpc(global_position, 1, damage, splash_radius)

		if explosion_scene:
			var exp_instance: Node3D = explosion_scene.instantiate()
			var scene_root: Node = get_tree().current_scene if get_tree() else null
			if not scene_root and get_tree():
				scene_root = get_tree().root

			if scene_root:
				scene_root.add_child(exp_instance)
				if "explosion_scene_owner" in exp_instance:
					exp_instance.explosion_scene_owner = shooter

				if exp_instance.has_method("explode"):
					if "damage_splash" in exp_instance:
						exp_instance.damage_splash = int(damage)
					if "splash_radius" in exp_instance:
						exp_instance.splash_radius = splash_radius
					if "size_scale" in exp_instance:
						exp_instance.size_scale = 0.8
					if "damage_type" in exp_instance:
						exp_instance.damage_type = damage_type
					if "damage_source_id" in exp_instance:
						exp_instance.damage_source_id = shooter_id
					var pos: Vector3 = global_position
					exp_instance.explode(pos, Vector3.ZERO, -1.0)

	# Cleanup - wait for trails then return to pool or free
	if smoke:
		get_tree().create_timer(1.0).timeout.connect(_on_finish, CONNECT_ONE_SHOT)
	else:
		_on_finish()


func _on_finish() -> void:
	if pool_scene_path != "":
		var pool_service: Node = GameManager.get_core_system("pools")
		if pool_service and pool_service.has_method("return_instance"):
			pool_service.return_instance(self)
		else:
			queue_free()
	else:
		queue_free()


## Fuse timeout callback - TIMER SAFETY: Validates self still exists
func _on_fuse_timeout(gen: int) -> void:
	# Validate self still exists and generation matches
	if not is_instance_valid(self) or gen != _spawn_generation:
		return
	explode()


func reset() -> void:
	# SIGNAL HYGIENE: Disconnect signals when returning to pool
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

	var area: Area3D = get_node_or_null("DetectionArea")
	if area and area.body_entered.is_connected(_on_detection_area_body_entered):
		area.body_entered.disconnect(_on_detection_area_body_entered)

	# Reset state
	_has_exploded = false
	visible = false
	_spawn_generation += 1

	freeze = true  # Reset to frozen state
	contact_monitor = false  # Reset contact monitor

	# Reset physics state
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = Vector3.ZERO

	var mesh: Node3D = get_node_or_null("MeshInstance3D")
	# Fuse timer is started in launch() now
	# Effects are started in launch() now

	# Ensure dormant state
	var smoke: GPUParticles3D = get_node_or_null("SmokeTrail")
	if smoke:
		smoke.emitting = false
	if mesh:
		mesh.visible = false


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return

	# Bounce sound on world collision (enemy detection handled by Area3D)
	if multiplayer.is_server():
		play_bounce_sound.rpc()


@rpc("call_local", "unreliable")
func play_bounce_sound() -> void:
	var audio: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")
	if audio and not audio.playing:
		audio.pitch_scale = randf_range(0.9, 1.1)
		audio.play()
