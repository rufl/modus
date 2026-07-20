class_name StatusEffectManager
extends GameComponent

signal effect_applied(effect: StatusEffect)
signal effect_removed(effect_name: String)
signal effect_stacked(effect_name: String, new_stacks: int)

var active_effects: Array[StatusEffect] = []

var _parent: Node3D = null


func _ready() -> void:
	set_process(false)  # Only process when effects are active
	_parent = get_parent() as Node3D
	if not _parent:
		push_warning("[StatusEffectManager] Parent is not Node3D")


func _process(delta: float) -> void:
	if active_effects.is_empty():
		set_process(false)  # Disable when no effects active
		return

	# Only process on authority
	if _parent and _parent.has_method("is_multiplayer_authority"):
		if not _parent.is_multiplayer_authority():
			return

	var effects_to_remove: Array[StatusEffect] = []

	for effect: StatusEffect in active_effects:
		if not effect.update(delta, _parent):
			effects_to_remove.append(effect)

	for effect: StatusEffect in effects_to_remove:
		_remove_effect_internal(effect)

	# Update screen effects if local player
	_update_player_screen_effects()


func _update_player_screen_effects() -> void:
	if not _parent or not _parent.has_method("is_multiplayer_authority"):
		return
	# Only update screen effects for the local player authority
	if not _parent.is_multiplayer_authority():
		return

	# Check for PlayerHUDBridge access (via Player)
	# Assuming parent is Player
	var hud_bridge: Node = _parent.get_node_or_null("PlayerHUDBridge")
	if not hud_bridge:
		# Try accessing via script property if available
		if "hud_bridge" in _parent:
			hud_bridge = _parent.hud_bridge

	if not hud_bridge or not hud_bridge.has_method("update_screen_effects"):
		return

	var effects_data: Dictionary = {}

	for effect: StatusEffect in active_effects:
		var intensity: float = 0.0
		# Simple intensity based on duration or stacks
		var base_intensity: float = 0.5
		if effect.stacks:
			base_intensity = clampf(effect.current_stacks * 0.2, 0.2, 1.0)

		# Pulse intensity based on time
		var pulse: float = sin(Time.get_ticks_msec() / 200.0) * 0.1
		intensity = base_intensity + pulse

		match effect.effect_type:
			StatusEffect.EffectType.POISON:
				effects_data["poison"] = intensity
			StatusEffect.EffectType.BURN:
				effects_data["burn"] = intensity
			StatusEffect.EffectType.DROWNING:
				effects_data["drowning"] = intensity
			StatusEffect.EffectType.BLEED:
				effects_data["bleed"] = intensity

	hud_bridge.update_screen_effects(effects_data)


func apply_effect(effect: StatusEffect) -> void:
	# Check for existing effect of same type
	for existing: StatusEffect in active_effects:
		if existing.effect_type == effect.effect_type:
			if effect.stacks:
				existing.add_stack()
				effect_stacked.emit(existing.effect_name, existing.current_stacks)
				_sync_effect_stack.rpc(existing.effect_name, existing.current_stacks)
			else:
				# Refresh duration
				existing.remaining_duration = effect.duration
			return

	# Add new effect
	var new_effect: StatusEffect = effect.create_copy()
	new_effect.apply_to_target(_parent, effect.source_id)
	active_effects.append(new_effect)
	set_process(true)  # Enable processing for effect updates

	effect_applied.emit(new_effect)
	_spawn_effect_visual(new_effect)

	# Sync to other clients
	_sync_effect_applied.rpc(new_effect.to_dict())


func remove_effect(effect_type: StatusEffect.EffectType) -> void:
	var to_remove: Array[StatusEffect] = []

	for effect: StatusEffect in active_effects:
		if effect.effect_type == effect_type:
			to_remove.append(effect)

	for effect: StatusEffect in to_remove:
		_remove_effect_internal(effect)


func remove_all_effects() -> void:
	for effect: StatusEffect in active_effects:
		effect_removed.emit(effect.effect_name)
	active_effects.clear()
	_sync_effects_cleared.rpc()


func has_effect(effect_type: StatusEffect.EffectType) -> bool:
	for effect: StatusEffect in active_effects:
		if effect.effect_type == effect_type:
			return true
	return false


func get_movement_modifier() -> float:
	var modifier: float = 1.0
	for effect: StatusEffect in active_effects:
		modifier *= effect.movement_speed_modifier
	return modifier


func can_act() -> bool:
	for effect: StatusEffect in active_effects:
		if not effect.can_act:
			return false
	return true


func get_active_effect_names() -> Array[String]:
	var names: Array[String] = []
	for effect: StatusEffect in active_effects:
		names.append(effect.effect_name)
	return names


func _remove_effect_internal(effect: StatusEffect) -> void:
	active_effects.erase(effect)
	effect_removed.emit(effect.effect_name)
	_sync_effect_removed.rpc(effect.effect_name)


func _spawn_effect_visual(effect: StatusEffect) -> void:
	if not _parent:
		return

	# Create GPU particles based on effect type
	var particles := GPUParticles3D.new()
	particles.name = "StatusEffectParticles_%s" % effect.effect_name
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 1.5
	particles.explosiveness = 0.0  # Continuous emission

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.4

	# Configure based on effect type
	match effect.effect_type:
		StatusEffect.EffectType.POISON:
			_configure_poison_particles(material, effect.effect_color)
			particles.amount = 15
		StatusEffect.EffectType.BURN:
			_configure_burn_particles(material, effect.effect_color)
			particles.amount = 25
		StatusEffect.EffectType.BLEED:
			_configure_bleed_particles(material, effect.effect_color)
			particles.amount = 12
		StatusEffect.EffectType.FREEZE:
			_configure_freeze_particles(material, effect.effect_color)
			particles.amount = 20
		StatusEffect.EffectType.STUN:
			_configure_stun_particles(material, effect.effect_color)
			particles.amount = 10
		StatusEffect.EffectType.SLOW:
			_configure_slow_particles(material, effect.effect_color)
			particles.amount = 15
		StatusEffect.EffectType.DROWNING:
			_configure_drowning_particles(material, effect.effect_color)
			particles.amount = 30
		_:
			_configure_default_particles(material, effect.effect_color)

	particles.process_material = material

	# Create draw pass mesh
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh_mat.emission_enabled = true
	mesh_mat.emission = effect.effect_color
	mesh_mat.emission_energy_multiplier = 1.0
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh

	_parent.add_child(particles)
	particles.position = Vector3(0, 1.0, 0)  # At chest height

	# Remove when effect expires
	var cleanup := func() -> void:
		if not has_effect(effect.effect_type) and is_instance_valid(particles):
			particles.emitting = false
			# Delay cleanup to let remaining particles fade
			if particles.get_tree():
				var timer := particles.get_tree().create_timer(particles.lifetime)
				safe_connect(timer.timeout, particles.queue_free)

	safe_connect(
		effect_removed,
		func(removed_name: String) -> void:
			if removed_name == effect.effect_name:
				cleanup.call()
	)


func _configure_drowning_particles(mat: ParticleProcessMaterial, color: Color) -> void:
	# Bubbles rising
	mat.direction = Vector3.UP
	mat.spread = 20.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, 1, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.2
	mat.scale_max = 0.6

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.5, Color(color.r, color.g, color.b, 0.6))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex


func _configure_poison_particles(mat: ParticleProcessMaterial, color: Color) -> void:
	# Green dripping particles falling down
	mat.direction = Vector3.DOWN
	mat.spread = 30.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, -2, 0)
	mat.damping_min = 0.5
	mat.damping_max = 1.0
	mat.scale_min = 0.5
	mat.scale_max = 1.0

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(color.r, color.g, color.b, 0.8))
	gradient.add_point(0.7, Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.5))
	gradient.add_point(1.0, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex


func _configure_burn_particles(mat: ParticleProcessMaterial, _color: Color) -> void:
	# Fire particles rising up with flicker
	mat.direction = Vector3.UP
	mat.spread = 45.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.5
	mat.gravity = Vector3(0, 1, 0)  # Rise up
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	mat.emission_sphere_radius = 0.5

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.ORANGE_RED)
	gradient.add_point(0.3, Color.ORANGE)
	gradient.add_point(0.6, Color.YELLOW)
	gradient.add_point(1.0, Color(1.0, 0.3, 0.0, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex


func _configure_bleed_particles(mat: ParticleProcessMaterial, _color: Color) -> void:
	# Red blood droplets falling
	mat.direction = Vector3.DOWN
	mat.spread = 20.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.0
	mat.gravity = Vector3(0, -5, 0)  # Fast fall
	mat.damping_min = 0.0
	mat.damping_max = 0.5
	mat.scale_min = 0.4
	mat.scale_max = 0.8

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.DARK_RED)
	gradient.add_point(0.5, Color(0.5, 0.0, 0.0, 0.8))
	gradient.add_point(1.0, Color(0.3, 0.0, 0.0, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex


func _configure_freeze_particles(mat: ParticleProcessMaterial, _color: Color) -> void:
	# Ice crystals floating around
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.8
	mat.gravity = Vector3(0, 0.2, 0)  # Slight float
	mat.damping_min = 2.0
	mat.damping_max = 3.0
	mat.scale_min = 0.3
	mat.scale_max = 0.7

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.3, Color.LIGHT_BLUE)
	gradient.add_point(0.7, Color.CYAN)
	gradient.add_point(1.0, Color(0.5, 0.8, 1.0, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex


func _configure_stun_particles(mat: ParticleProcessMaterial, _color: Color) -> void:
	# Stars/sparkles rotating around head
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 0.0
	mat.damping_max = 0.5
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 0.5
	mat.emission_ring_inner_radius = 0.4
	mat.emission_ring_height = 0.1
	mat.emission_ring_axis = Vector3.UP

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.YELLOW)
	gradient.add_point(0.5, Color.WHITE)
	gradient.add_point(1.0, Color(1.0, 1.0, 0.5, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex


func _configure_slow_particles(mat: ParticleProcessMaterial, _color: Color) -> void:
	# Cyan/blue swirl around feet
	mat.direction = Vector3.UP
	mat.spread = 90.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0, -0.5, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.4
	mat.scale_max = 0.8

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.CYAN)
	gradient.add_point(0.5, Color(0.3, 0.7, 1.0, 0.7))
	gradient.add_point(1.0, Color(0.2, 0.5, 0.8, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex


func _configure_default_particles(mat: ParticleProcessMaterial, color: Color) -> void:
	# Default generic effect
	mat.direction = Vector3.UP
	mat.spread = 60.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.0
	mat.gravity = Vector3(0, -1, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.5
	mat.scale_max = 1.0

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(color.r, color.g, color.b, 0.8))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex


# ============================================================================
# Network Sync
# ============================================================================

@rpc("authority", "call_remote", "reliable")
func _sync_effect_applied(effect_data: Dictionary) -> void:
	var effect := StatusEffect.from_dict(effect_data)

	# Don't re-apply, just add for visual tracking
	for existing: StatusEffect in active_effects:
		if existing.effect_type == effect.effect_type:
			return

	active_effects.append(effect)
	effect_applied.emit(effect)
	_spawn_effect_visual(effect)


@rpc("authority", "call_remote", "reliable")
func _sync_effect_removed(effect_name: String) -> void:
	for effect: StatusEffect in active_effects:
		if effect.effect_name == effect_name:
			active_effects.erase(effect)
			effect_removed.emit(effect_name)
			return


@rpc("authority", "call_remote", "reliable")
func _sync_effect_stack(effect_name: String, stacks: int) -> void:
	for effect: StatusEffect in active_effects:
		if effect.effect_name == effect_name:
			effect.current_stacks = stacks
			effect_stacked.emit(effect_name, stacks)
			return


@rpc("authority", "call_remote", "reliable")
func _sync_effects_cleared() -> void:
	for effect: StatusEffect in active_effects:
		effect_removed.emit(effect.effect_name)
	active_effects.clear()
