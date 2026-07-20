class_name WeaponEffects
extends GameComponent3D

@export var muzzle_flash_color: Color = Color.ORANGE
@export var muzzle_flash_scale: float = 1.0
@export var eject_cartridges: bool = true
@export var cartridge_eject_velocity: Vector3 = Vector3(1.0, 2.0, 0.5)
@export var cartridge_color: Color = Color(0.8, 0.6, 0.2)  # Brass default
@export var cartridge_radius: float = 0.01
@export var cartridge_height: float = 0.03
@export var muzzle_offset: Vector3 = Vector3(0, 0, -0.5)

var cartridge_mesh: Mesh


func _ready() -> void:
	# _find_effects_manager()
	_create_cartridge_mesh()

	# Connect to parent weapon signals if any
	# (custom signal handling might be needed depending on architecture)
	# The Player script calls play_shoot_effects, which we can hook into manually.


func _create_cartridge_mesh() -> void:
	# Create cartridge mesh using exported properties
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = cartridge_radius
	cylinder.bottom_radius = cartridge_radius
	cylinder.height = cartridge_height

	var material := StandardMaterial3D.new()
	material.albedo_color = cartridge_color
	material.metallic = 0.8
	material.roughness = 0.3

	cylinder.material = material
	cartridge_mesh = cylinder


func on_fire() -> void:
	if not is_inside_tree():
		return

	# Called when weapon is fired
	_spawn_muzzle_flash()
	if eject_cartridges:
		_eject_cartridge()


func _spawn_muzzle_flash() -> void:
	var flash_pos: Vector3
	var flash_rot: Vector3 = Vector3.ZERO

	# Try to find Muzzle node
	var muzzle: Node3D = get_node_or_null("../Muzzle")
	if muzzle:
		flash_pos = muzzle.global_position
		flash_rot = muzzle.global_rotation
	else:
		# Fallback
		flash_pos = global_position + global_transform.basis * muzzle_offset
		flash_rot = global_rotation

	# Use pooled muzzle flash if available
	var effects_service: Node = GameManager.get_core_system("effects") if GameManager else null
	if effects_service and effects_service.has_method("spawn_pooled_muzzle_flash"):
		effects_service.spawn_pooled_muzzle_flash(
			flash_pos, muzzle_flash_color, muzzle_flash_scale, 0.05
		)
	else:
		# Fallback to old method
		call_deferred("_finish_muzzle_flash", flash_pos, flash_rot)


func _finish_muzzle_flash(pos: Vector3, rot: Vector3) -> void:
	# 1. Light Effect
	var flash := OmniLight3D.new()
	flash.light_color = muzzle_flash_color
	flash.light_energy = 3.0 * muzzle_flash_scale
	flash.omni_range = 3.0 * muzzle_flash_scale
	flash.omni_attenuation = 2.0

	# 2. Visual Mesh (Billboard Quad)
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5) * muzzle_flash_scale

	var mat := StandardMaterial3D.new()
	mat.albedo_color = muzzle_flash_color
	mat.emission_enabled = true
	mat.emission = muzzle_flash_color
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Use star texture if available, else plain gradient/circle
	# Preload locally to avoid dependency issues if file missing
	# For now, just a bright quad
	quad.material = mat
	mesh_instance.mesh = quad
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	flash.add_child(mesh_instance)

	# Add to tree
	var tree := get_tree()
	if not tree:
		flash.free()
		return

	var root := tree.root
	if root:
		root.add_child(flash)
		flash.global_position = pos
		# Apply rotation (matters if billboard mode is disabled or constrained)
		flash.global_rotation = rot

		# Quick fade out
		var tween := flash.create_tween()
		tween.tween_property(flash, "light_energy", 0.0, 0.05)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.05)
		tween.tween_callback(flash.queue_free)


func _eject_cartridge() -> void:
	# Calculate transforms here (safe if we are in tree)
	var eject_pos_offset := Vector3(0.1, 0.1, 0)
	var pos := global_position + global_transform.basis * eject_pos_offset
	var rot := global_rotation
	var basis_transform := global_transform.basis

	# Use pooled shell casing if available
	var effects_service: Node = GameManager.get_core_system("effects") if GameManager else null
	if effects_service and effects_service.has_method("spawn_pooled_shell_casing"):
		var eject_vel := basis_transform * cartridge_eject_velocity
		eject_vel.x += randf_range(-0.5, 0.5)
		eject_vel.y += randf_range(-0.5, 0.5)

		var angular_vel := Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))

		var shell: RigidBody3D = effects_service.spawn_pooled_shell_casing(
			pos, eject_vel, angular_vel, "bullet", 3.0
		)
		if shell:
			shell.global_rotation = rot
	else:
		# Fallback to old method
		call_deferred("_finish_eject_cartridge", pos, rot, basis_transform)


func _finish_eject_cartridge(pos: Vector3, rot: Vector3, basis_transform: Basis) -> void:
	# Create cartridge as RigidBody3D
	var cartridge := RigidBody3D.new()
	cartridge.mass = 0.01

	# Add mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = cartridge_mesh
	cartridge.add_child(mesh_instance)

	# Add collision
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.01
	shape.height = 0.03
	collision.shape = shape
	cartridge.add_child(collision)

	# Add to tree first - using direct add since we're already deferred
	var tree := get_tree()
	if not tree:
		return
	var root := tree.root
	if not root:
		return
	root.add_child(cartridge)

	# Now set global position/rotation
	cartridge.global_position = pos
	cartridge.global_rotation = rot

	# Apply ejection velocity
	var eject_vel := basis_transform * cartridge_eject_velocity

	# Add some random variance
	eject_vel.x += randf_range(-0.5, 0.5)
	eject_vel.y += randf_range(-0.5, 0.5)

	cartridge.linear_velocity = eject_vel
	cartridge.angular_velocity = Vector3(
		randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)
	)

	# Clean up after a few seconds
	# Clean up after a few seconds using Tween (safer than timer)
	var tween := cartridge.create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(cartridge.queue_free)
