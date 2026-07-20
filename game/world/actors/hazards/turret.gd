@tool
class_name Turret
extends Node3D

signal destroyed(turret: Turret)

@export_group("Turret Stats")
@export var scan_range: float = 15.0
@export var turn_speed: float = 2.0
@export var fire_rate: float = 0.5
@export var damage: int = 10
@export var projectile_speed: float = 20.0
@export var projectile_scene: PackedScene  ## Projectile to spawn when firing
@export_group("Health")
@export var max_health: float = 100.0
@export var show_health_bar: bool = true

var current_health: float = 100.0
var is_destroyed: bool = false

@onready var head: Node3D = $Head
@onready var barrel_end: Node3D = $Head/BarrelEnd
@onready var scan_area: Area3D = $ScanArea
@onready var raycast: RayCast3D = $Head/RayCast3D

var _target: Node3D = null
var _fire_timer: float = 0.0
var _health_bar: ProgressBar = null
var _health_bar_container: Control = null
var _subviewport: SubViewport = null


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("turrets")

	current_health = max_health

	if show_health_bar:
		_create_health_bar()

	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		set_physics_process(false)
		return

	if scan_area:
		scan_area.body_entered.connect(_on_body_entered)
		scan_area.body_exited.connect(_on_body_exited)


func _create_health_bar() -> void:
	# Create 3D health bar using SubViewport
	_subviewport = SubViewport.new()
	_subviewport.size = Vector2i(100, 12)
	_subviewport.transparent_bg = true
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_create_synchronizer()  # Add sync for head rotation
	add_child(_subviewport)


func _create_synchronizer() -> void:
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"

	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property("Head:rotation")  # Sync head rotation
	sync.replication_config = config
	add_child(sync)

	# Container for bar
	_health_bar_container = Control.new()
	_health_bar_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_subviewport.add_child(_health_bar_container)

	# Background
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_bar_container.add_child(bg)

	# Progress bar
	_health_bar = ProgressBar.new()
	_health_bar.max_value = max_health
	_health_bar.value = current_health
	_health_bar.show_percentage = false
	_health_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_bar_container.add_child(_health_bar)

	# Style the bar
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.RED
	_health_bar.add_theme_stylebox_override("fill", style)

	# Create Sprite3D to display viewport
	var sprite: Sprite3D = Sprite3D.new()
	sprite.name = "HealthBarSprite"
	sprite.texture = _subviewport.get_texture()
	sprite.pixel_size = 0.01
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position = Vector3(0, 2.5, 0)
	sprite.no_depth_test = true
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return

	if _target:
		_track_target(delta)
		_process_firing(delta)
	else:
		_scan_idle(delta)


func _track_target(delta: float) -> void:
	if not head or not _target:
		return

	var target_pos: Vector3 = _target.global_position + Vector3(0, 1.0, 0)
	var current_transform: Transform3D = head.global_transform
	var target_transform: Transform3D = current_transform.looking_at(target_pos, Vector3.UP)

	head.global_transform = current_transform.interpolate_with(target_transform, turn_speed * delta)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-60), deg_to_rad(60))


func _process_firing(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer <= 0:
		if _can_see_target():
			_fire()
			_fire_timer = fire_rate


func _fire() -> void:
	var spawn_pos: Vector3 = barrel_end.global_position if barrel_end else head.global_position
	var spawn_rot: Basis = head.global_transform.basis
	var dir: Vector3 = -spawn_rot.z
	var vel: Vector3 = dir * projectile_speed

	_spawn_projectile.rpc(spawn_pos, spawn_rot, vel)


@rpc("call_local", "reliable")
func _spawn_projectile(pos: Vector3, rot: Basis, vel: Vector3) -> void:
	# Spawn projectile if scene is configured
	if not projectile_scene:
		# Fallback: simple hitscan damage if no projectile
		if multiplayer.is_server() and _target:
			if _target.has_method("take_damage"):
				var dmg_info := DamageInfo.new()
				dmg_info.base_amount = float(damage)
				dmg_info.damage_type = DamageInfo.DamageType.BULLET
				dmg_info.source_id = get_instance_id()
				_target.take_damage(dmg_info)
		return

	var projectile: Node3D = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = pos
	projectile.global_transform.basis = rot

	# Configure projectile if it has expected properties
	if "damage" in projectile:
		projectile.damage = damage
	if "velocity" in projectile:
		projectile.velocity = vel
	if projectile is RigidBody3D:
		projectile.linear_velocity = vel
	if "shooter" in projectile:
		projectile.shooter = self


func _can_see_target() -> bool:
	if not raycast:
		return true

	raycast.target_position = raycast.to_local(_target.global_position + Vector3(0, 1.0, 0))
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider: Object = raycast.get_collider()
		return collider == _target

	return false


func _scan_idle(delta: float) -> void:
	if head:
		head.rotate_y(0.5 * delta)


func _on_body_entered(body: Node) -> void:
	if is_destroyed:
		return
	if body.is_in_group("player"):
		if not _target:
			_target = body


func _on_body_exited(body: Node) -> void:
	if body == _target:
		_target = null
		if scan_area:
			var bodies: Array[Node3D] = scan_area.get_overlapping_bodies()
			for b: Node3D in bodies:
				if b.is_in_group("player"):
					_target = b
					break


## Take damage from attacks


func take_damage(info: DamageInfo) -> void:
	if is_destroyed:
		return

	# Only server processes damage
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return

	current_health -= info.base_amount

	# Sync health to all clients
	_sync_health.rpc(current_health)

	if current_health <= 0:
		_destroy()


@rpc("authority", "call_local", "reliable")
func _sync_health(new_health: float) -> void:
	current_health = new_health

	# Update health bar
	if _health_bar:
		_health_bar.value = current_health


func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	_sync_destroyed.rpc()


@rpc("authority", "call_local", "reliable")
func _sync_destroyed() -> void:
	is_destroyed = true
	_target = null

	# Visual destruction
	if head:
		# Tilt head down
		var tween: Tween = create_tween()
		tween.tween_property(head, "rotation:x", deg_to_rad(45), 0.3)

	# Hide health bar
	var sprite: Node = get_node_or_null("HealthBarSprite")
	if sprite:
		sprite.hide()

	# Spawn destruction effects
	_spawn_destruction_effects()

	destroyed.emit(self)


func _spawn_destruction_effects() -> void:
	# Smoke particles
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 1.5
	particles.explosiveness = 0.8

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3.UP
	material.spread = 120.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, 1, 0)
	material.scale_min = 0.2
	material.scale_max = 0.5

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.3, 0.3, 0.3, 0.8))
	gradient.add_point(1.0, Color(0.2, 0.2, 0.2, 0.0))
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	particles.process_material = material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	particles.draw_pass_1 = quad

	add_child(particles)
	particles.position = Vector3(0, 1.5, 0)

	# Cleanup
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)
