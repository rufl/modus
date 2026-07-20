@tool
extends StaticBody3D
class_name BreakableProp

signal prop_destroyed(prop_type: String, position: Vector3)
signal prop_damaged(current_health: float, max_health: float)

@export_group("Prop Settings")
@export var prop_type: String = "crate"
@export var prop_name: String = "Wooden Crate"
@export var loot_table_id: String = ""  # Empty = no loot
@export_group("Health")
@export var max_health: float = 50.0
@export var damage_resistance: float = 0.0  # 0-1 damage reduction
@export_group("Visual Feedback")
@export var show_damage_cracks: bool = true
@export var wobble_on_damage: bool = true
@export var wobble_intensity: float = 0.1
@export var wobble_duration: float = 0.2
@export_group("Break Effects")
@export var break_particle_color: Color = Color(0.6, 0.4, 0.2)
@export var break_sound_pitch_min: float = 0.9
@export var break_sound_pitch_max: float = 1.1
@export var debris_count: int = 5
@export var debris_lifetime: float = 3.0

var sync_health: float = 50.0
var is_destroyed: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _original_color: Color = Color.WHITE


func _ready() -> void:
	# Skip initialization in editor
	if Engine.is_editor_hint():
		return

	sync_health = max_health

	# Setup multiplayer synchronizer
	_setup_multiplayer_sync()

	# Store original material color
	var material: Material = _get_visual_material()
	if material is StandardMaterial3D:
		_original_color = material.albedo_color

	# Add to groups for targeting/detection
	add_to_group("breakable_props")
	add_to_group("damageable")
	add_to_group("props")


func _setup_multiplayer_sync() -> void:
	## Add MultiplayerSynchronizer for health state
	if has_node("MultiplayerSynchronizer"):
		return

	var synchronizer: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MultiplayerSynchronizer"
	synchronizer.replication_interval = 0.1

	# Create replication config for sync_health
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(":sync_health")
	config.add_property(":is_destroyed")
	synchronizer.replication_config = config

	add_child(synchronizer)


# =============================================================================
# DAMAGE INTERFACE
# =============================================================================

## Public damage method - called by weapons, explosions, etc.


func take_damage(amount: float, damage_type: String = "generic", source: Node3D = null) -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	if is_destroyed:
		return

	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

	# Client: Request damage from server
	if not is_server_or_sp:
		_request_damage.rpc_id(1, amount, damage_type)
		return

	# Server/Singleplayer: Apply damage
	_apply_damage(amount, damage_type, source)


## Client -> Server damage request

@rpc("any_peer", "reliable")
func _request_damage(amount: float, damage_type: String) -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

	if not is_server_or_sp:
		return

	var peer_id: int = multiplayer.get_remote_sender_id()

	# Validate through NetworkService.network_manager if available
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var ns: Node = gm.get_core_system("network")
		var network_manager: Node = ns.network_manager if ns else null
		if network_manager and network_manager.has_method("validate_rpc"):
			if not network_manager.validate_rpc(peer_id, "_request_damage", [amount]):
				return

	_apply_damage(amount, damage_type, null)


func _apply_damage(amount: float, _damage_type: String, source: Node3D) -> bool:
	## Apply damage (server-side)
	if is_destroyed or amount <= 0.0:
		return false

	# Damage never heals, even when an invalid negative amount or resistance is supplied.
	var final_damage: float = maxf(0.0, amount) * (1.0 - clampf(damage_resistance, 0.0, 1.0))
	sync_health = max(0.0, sync_health - final_damage)

	# Emit damage event
	prop_damaged.emit(sync_health, max_health)

	# Play damage feedback locally in single-player or on all peers in multiplayer.
	if multiplayer.has_multiplayer_peer():
		_play_damage_feedback.rpc()
	else:
		_play_damage_feedback()

	# Check for death
	if sync_health <= 0.0:
		_die(source)

	return true


## Play visual/audio feedback for damage (all clients)

@rpc("authority", "call_local", "reliable")
func _play_damage_feedback() -> void:
	if wobble_on_damage:
		_play_wobble_animation()

	if show_damage_cracks:
		_update_damage_visuals()


func _on_health_changed() -> void:
	## Called when sync_health changes (including from sync)
	if show_damage_cracks:
		_update_damage_visuals()


# =============================================================================
# DEATH / DESTRUCTION
# =============================================================================


func _die(source: Node3D) -> void:
	## Handle prop destruction (server-side)
	if is_destroyed:
		return

	is_destroyed = true

	# Notify all clients, or invoke the same effect path directly in single-player.
	if multiplayer.has_multiplayer_peer():
		_play_destruction.rpc()
	else:
		_play_destruction()

	# Spawn loot via GameplayService.loot
	var gm: Node = get_node_or_null("/root/GameManager")
	if loot_table_id != "" and not Engine.is_editor_hint() and gm:
		var gs: Node = gm.get_core_system("gameplay")
		if gs and gs.loot:
			# Anyone can pick up
			gs.loot.spawn_loot_from_table(global_position, loot_table_id, get_path(), -1)

	# Emit events
	if gm and not Engine.is_editor_hint():
		gm.emit_event(
			"prop_destroyed",
			{"prop": self, "position": global_position, "prop_type": prop_type, "killer": source}
		)


## Play destruction effects on all clients

@rpc("authority", "call_local", "reliable")
func _play_destruction() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	is_destroyed = true

	# Emit local signal
	prop_destroyed.emit(prop_type, global_position)

	# Play break effects via GameManager.get_core_system("effects")
	var gm: Node = get_node_or_null("/root/GameManager")
	var effects_service: Node = null
	if gm:
		var gs: Node = gm.get_core_system("gameplay")
		effects_service = gs.effects if gs else null
	if effects_service:
		# Spawn break particles
		if effects_service.has_method("spawn_break_particles"):
			effects_service.spawn_break_particles(global_position, break_particle_color)
		# Spawn debris
		if effects_service.has_method("spawn_debris"):
			effects_service.spawn_debris(global_position, debris_count, break_particle_color)
	else:
		# Fallback: Local effects
		_create_break_particles()
		_spawn_debris()

	# Play break sound
	_play_break_sound()

	# Disable collision
	if collision_shape:
		collision_shape.disabled = true

	# Hide mesh
	if mesh_instance:
		mesh_instance.visible = false

	# Queue free after short delay
	get_tree().create_timer(0.5).timeout.connect(queue_free)


# =============================================================================
# VISUAL EFFECTS
# =============================================================================


func _play_wobble_animation() -> void:
	## Play wobble animation when damaged
	if not mesh_instance or is_destroyed:
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Wobble rotation
	var wobble_angle: float = wobble_intensity * 10.0
	(
		tween
		. tween_property(mesh_instance, "rotation_degrees:z", wobble_angle, wobble_duration * 0.25)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)

	(
		tween
		. tween_property(
			mesh_instance, "rotation_degrees:z", -wobble_angle * 0.5, wobble_duration * 0.25
		)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
		. set_delay(wobble_duration * 0.25)
	)

	(
		tween
		. tween_property(mesh_instance, "rotation_degrees:z", 0.0, wobble_duration * 0.5)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
		. set_delay(wobble_duration * 0.5)
	)


func _update_damage_visuals() -> void:
	## Update visual damage based on health percentage
	if not mesh_instance or is_destroyed:
		return

	var health_percent: float = sync_health / max_health

	# Darken material based on damage
	var material: Material = _get_visual_material()
	if material is StandardMaterial3D:
		var damage_factor: float = 0.7 + (health_percent * 0.3)
		material.albedo_color = _original_color * damage_factor


func _create_break_particles() -> void:
	## Create particle effect for prop breaking (fallback)
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "BreakParticles"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.8
	particles.explosiveness = 1.0

	# Create process material
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3

	# Color gradient
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, break_particle_color)
	gradient.add_point(0.5, break_particle_color * 0.8)
	gradient.add_point(
		1.0, Color(break_particle_color.r, break_particle_color.g, break_particle_color.b, 0.0)
	)

	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	particles.process_material = material

	# Create draw pass
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.15, 0.15)

	var draw_material: StandardMaterial3D = StandardMaterial3D.new()
	draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_material.albedo_color = break_particle_color

	quad_mesh.material = draw_material
	particles.draw_pass_1 = quad_mesh

	# Add to the active scene, or to the prop's parent when embedded in a fixture/tool scene.
	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		particles.free()
		return
	effect_parent.add_child(particles)
	particles.global_position = global_position

	# Auto-cleanup
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)


func _spawn_debris() -> void:
	## Spawn physics debris pieces (fallback)
	for i: int in range(debris_count):
		_create_debris_piece()


func _create_debris_piece() -> void:
	## Create a single debris piece with physics
	var debris: RigidBody3D = RigidBody3D.new()
	debris.name = "Debris"
	var debris_position: Vector3 = (
		global_position
		+ Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.5), randf_range(-0.3, 0.3))
	)

	# Add mesh
	var debris_mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(randf_range(0.1, 0.3), randf_range(0.1, 0.3), randf_range(0.1, 0.3))

	var debris_material: StandardMaterial3D = StandardMaterial3D.new()
	debris_material.albedo_color = break_particle_color
	box.material = debris_material

	debris_mesh.mesh = box
	debris.add_child(debris_mesh)

	# Add collision
	var debris_collision: CollisionShape3D = CollisionShape3D.new()
	var debris_shape: BoxShape3D = BoxShape3D.new()
	debris_shape.size = box.size
	debris_collision.shape = debris_shape
	debris.add_child(debris_collision)

	# Apply random impulse
	var impulse: Vector3 = Vector3(
		randf_range(-3.0, 3.0), randf_range(3.0, 6.0), randf_range(-3.0, 3.0)
	)

	# Add to scene
	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		debris.free()
		return
	effect_parent.add_child(debris)
	debris.global_position = debris_position
	debris.apply_central_impulse(impulse)

	# Fade out and cleanup
	_cleanup_debris(debris, debris_mesh)


func _cleanup_debris(debris: RigidBody3D, debris_mesh: MeshInstance3D) -> void:
	## Fade out and remove debris
	await get_tree().create_timer(debris_lifetime * 0.7).timeout

	if not is_instance_valid(debris):
		return

	var tween: Tween = debris.create_tween()
	tween.tween_property(debris_mesh, "transparency", 1.0, debris_lifetime * 0.3)

	await tween.finished
	if is_instance_valid(debris):
		debris.queue_free()


func _play_break_sound() -> void:
	## Play break sound effect
	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.name = "BreakSound"
	audio.bus = "SFX"
	audio.pitch_scale = randf_range(break_sound_pitch_min, break_sound_pitch_max)

	# Try to load sound based on prop type
	var sound_path: String = "res://game/assets/audio/sfx/prop_break_%s.ogg" % prop_type
	if ResourceLoader.exists(sound_path):
		audio.stream = load(sound_path)

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		audio.free()
		return
	effect_parent.add_child(audio)
	audio.global_position = global_position

	if audio.stream:
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)


# =============================================================================
# UTILITY
# =============================================================================


func _get_effect_parent() -> Node:
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		return tree.current_scene
	return get_parent()


func _get_visual_material() -> Material:
	if not mesh_instance:
		return null
	if mesh_instance.material_override:
		return mesh_instance.material_override
	if mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 0:
		return mesh_instance.get_active_material(0)
	return null


func get_health_percent() -> float:
	return sync_health / max_health if max_health > 0 else 0.0


func is_alive() -> bool:
	return not is_destroyed and sync_health > 0
