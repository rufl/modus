class_name RocketProjectile
extends CharacterBody3D

const RocketTrailSetup = preload("res://game/entities/projectiles/rocket_trail_setup.gd")

@export var speed: float = 80.0  # ~1000 Quake units
@export var max_lifetime: float = 10.0
@export var damage: float = 100.0
@export var blast_radius: float = 5.0
@export var damage_type: int = DamageInfo.DamageType.EXPLOSIVE
@export var explosion_scene: PackedScene
@export var shooter_id: int = 0  # Synced via MultiplayerSynchronizer

var shooter: Node3D = null  # Owner/Source
var launch_time: float = 0.0
var pool_scene_path: String = ""

var _has_exploded: bool = false
var _spawn_generation: int = 0
var _trails_setup: bool = false


func _ready() -> void:
	if not explosion_scene:
		explosion_scene = load("res://game/entities/projectiles/explosion_quake.tscn")

	# Setup retro pixelated trails (only once)
	if not _trails_setup:
		RocketTrailSetup.setup_smoke_trail(self)
		RocketTrailSetup.setup_ember_trail(self)
		_trails_setup = true

	# Ensure this projectile doesn't collide with shooter immediately if spawned inside
	launch_time = Time.get_unix_time_from_system()

	# Safety timeout
	# Safety timeout - MOVED TO LAUNCH

	# CRITICAL FIX: Do NOT start trails in _ready (causes origin spawn issue)
	# Trails are started in launch() after position is set
	# Also hide projectile until it's properly launched (prevents origin flash)
	var smoke: GPUParticles3D = get_node_or_null("SmokeTrail")
	if smoke:
		smoke.emitting = false
	var ember: GPUParticles3D = get_node_or_null("EmberTrail")
	if ember:
		ember.emitting = false

	# Hide until launched
	visible = false
	# CRITICAL: Disable physics until launched to prevent interaction at 0,0
	set_physics_process(false)

	_resolve_shooter()


func _resolve_shooter() -> void:
	if shooter_id > 0 and not shooter:
		var tree := get_tree()
		if tree and tree.current_scene:
			shooter = tree.current_scene.get_node_or_null(str(shooter_id))

	if shooter:
		add_collision_exception_with(shooter)


func launch(global_pos: Vector3, direction: Vector3, owner_node: Node3D = null) -> void:
	global_position = global_pos
	velocity = direction.normalized() * speed
	shooter = owner_node

	if direction != Vector3.ZERO:
		var up_vec := Vector3.UP
		# Avoid colinear warning when firing straight up/down
		if abs(direction.normalized().dot(Vector3.UP)) > 0.99:
			up_vec = Vector3.RIGHT
		look_at(global_pos + direction, up_vec)

	# Activate physics
	set_physics_process(true)

	# Start safety timeout - TIMER SAFETY: Use bound method, not lambda
	_spawn_generation += 1
	var current_gen: int = _spawn_generation
	get_tree().create_timer(max_lifetime).timeout.connect(
		_on_safety_timeout.bind(current_gen), CONNECT_ONE_SHOT
	)

	# CRITICAL: Make visible and start trails AFTER position is set (fixes origin issue)
	visible = true
	var smoke: GPUParticles3D = get_node_or_null("SmokeTrail")
	if smoke:
		smoke.emitting = true
		smoke.restart()
	var ember: GPUParticles3D = get_node_or_null("EmberTrail")
	if ember:
		ember.emitting = true
		ember.restart()

	# Activate physics
	set_physics_process(true)

	# Ignore shooter collision?
	# CharacterBody3D doesn't have simple collision exceptions like RigidBody3D.
	# We rely on collision layers/masks.
	# Or we check collision result.


func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	# Move
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)

	if collision:
		# Check if we hit the shooter immediately (safety)
		var collider: Object = collision.get_collider()
		if collider == shooter:
			# Ignore collision with own shooter (prevent self-damage on spawn)
			return

		explode(collision.get_position(), collision.get_normal())


func explode(hit_pos: Vector3, impact_normal: Vector3 = Vector3.ZERO) -> void:
	if _has_exploded:
		return
	_has_exploded = true

	# Stop trails
	var smoke: GPUParticles3D = get_node_or_null("SmokeTrail")
	if smoke:
		smoke.emitting = false
	var ember: GPUParticles3D = get_node_or_null("EmberTrail")
	if ember:
		ember.emitting = false

	# Hide Rocket Mesh
	var mesh: Node3D = get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false

	# Disable collision immediately
	var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = true

	# Spawn Explosion
	# Authority spawns logical visuals/damage, calls RPC for clients
	if multiplayer.is_server():
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.effects:
			# spawn_explosion(position, explosion_type, damage, radius)
			gs.effects.spawn_explosion.rpc(hit_pos, 1, damage, blast_radius)

		# Logical explosion for server (damage, physics)
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
						exp_instance.splash_radius = blast_radius
					if "damage_source_id" in exp_instance:
						exp_instance.damage_source_id = shooter_id
					exp_instance.explode(hit_pos, impact_normal, -1.0)
	else:
		# Client prediction or just wait for server RPC?
		# Usually best to wait for server-authoritative explosion to avoid ghosts.
		pass

	# Wait for trails to finish then delete
	set_physics_process(false)

	# If no trails, delete immediately, otherwise wait
	if smoke or ember:
		get_tree().create_timer(2.0).timeout.connect(_on_finish, CONNECT_ONE_SHOT)
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


## Safety timeout callback - TIMER SAFETY: Validates self still exists
func _on_safety_timeout(gen: int) -> void:
	# Validate self still exists and generation matches
	if not is_instance_valid(self) or gen != _spawn_generation:
		return
	explode(global_position)


## Pooling Support


func reset() -> void:
	_has_exploded = false
	visible = false  # Keep hidden until launch

	# Reset physics state
	velocity = Vector3.ZERO
	global_position = Vector3.ZERO

	# Re-enable collision shape immediately (not deferred)
	var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = false

	var mesh: Node3D = get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = true  # Internal mesh visibility (parent hidden)

	# Ensure trails are off
	var smoke: GPUParticles3D = get_node_or_null("SmokeTrail")
	if smoke:
		smoke.emitting = false  # Ensure OFF

	var ember: GPUParticles3D = get_node_or_null("EmberTrail")
	if ember:
		ember.emitting = false  # Ensure OFF

	velocity = Vector3.ZERO
	shooter = null
	shooter_id = 0

	# Wait for launch to enable physics and timer
	set_physics_process(false)

	# Invalidate previous timers
	_spawn_generation += 1
