class_name EnemyDamageHandler
extends Node

signal died(source_id: int)

const BloodSprayScript = preload("res://game/entities/effects/blood_spray.gd")

var pain_debounce_time: float = 0.0
var last_damage_taken: int = 0

var _enemy: Node
var _health_component: HealthComponent
var _pain_system: PainSystem
var _blood_hit_spawner: BloodHitSpawner
var _bullet_decals: Node  # EnemyBulletDecals


# Helper function to safely get GameManager
func _get_gm() -> Node:
	return get_node_or_null("/root/GameManager")


# Helper function to safely log messages
func _log(message: String, category: String = "Enemy") -> void:
	var gm: Node = _get_gm()
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger and logger.has_method("info"):
		logger.info(message, category)


func setup(
	enemy: Node, health_comp: HealthComponent, pain_sys: PainSystem, blood_spawner: BloodHitSpawner
) -> void:
	_enemy = enemy
	_health_component = health_comp
	_pain_system = pain_sys
	_blood_hit_spawner = blood_spawner

	# Setup bullet decals component (deferred to ensure it exists)
	call_deferred("_setup_bullet_decals")


func _setup_bullet_decals() -> void:
	_bullet_decals = _enemy.get_node_or_null("BulletDecals")
	if _bullet_decals:
		_log("[EnemyDamageHandler] Bullet decals component found: " + " " + str(_bullet_decals))
	else:
		_log("[EnemyDamageHandler] WARNING: Bullet decals component NOT found!")


func handle_damage(
	info_or_damage: Variant,
	source_id_or_hit_pos: Variant = 0,
	dir: Vector3 = Vector3.ZERO,
	knockback: float = 1.0,
	_damage_mod: String = "bullet",
	attacker: Node3D = null
) -> void:
	# Server Authority Check
	if _enemy.multiplayer.has_multiplayer_peer() and not _enemy.multiplayer.is_server():
		return

	# CRITICAL: Don't process damage if enemy is already dead (but not ragdolled)
	# Ragdolled enemies can still take damage for gibbing
	if _enemy.is_dead and not _enemy.is_ragdolled:
		_log("[EnemyDamageHandler] Enemy already dead, ignoring damage")
		return

	# NEW: Handle ragdoll damage separately
	if _enemy.is_ragdolled:
		_handle_ragdoll_damage(
			info_or_damage, source_id_or_hit_pos, dir, knockback, _damage_mod, attacker
		)
		return

	var dmg: float = 0.0
	var source_id: int = 0
	var hit_pos: Vector3 = Vector3.ZERO
	var bullet_dir: Vector3 = dir
	var kb_force: float = knockback
	var source_node: Node3D = attacker

	# Parse arguments
	if info_or_damage is DamageInfo:
		var info: DamageInfo = info_or_damage
		dmg = info.base_amount
		source_id = info.source_id
		hit_pos = info.hit_position
		bullet_dir = info.knockback_direction
		kb_force = info.knockback_force
		source_node = info.source
		if source_node and attacker == null:
			attacker = source_node
	else:
		dmg = float(info_or_damage)
		if typeof(source_id_or_hit_pos) == TYPE_INT:
			source_id = source_id_or_hit_pos
			hit_pos = _enemy.global_position + Vector3(0, 1.0, 0)  # Fallback
		elif typeof(source_id_or_hit_pos) == TYPE_VECTOR3:
			hit_pos = source_id_or_hit_pos

	if attacker == _enemy:
		return  # Ignore self-damage

	last_damage_taken = int(dmg)
	var src_name: String = String(source_node.name) if source_node else "Unknown"
	_log("[Enemy] %s taking damage: %.1f from %s" % [_enemy.name, dmg, src_name])

	# Critical Hit Calculation
	var is_critical: bool = false
	var is_backstab: bool = false
	var is_headshot: bool = false

	if bullet_dir != Vector3.ZERO:
		var forward: Vector3 = -_enemy.global_transform.basis.z
		if bullet_dir.dot(forward) > 0.5:
			is_backstab = true

	if hit_pos != Vector3.ZERO and _damage_mod != "explosive":
		var relative_height: float = hit_pos.y - _enemy.global_position.y
		if relative_height > 1.5 and relative_height < 2.2:
			is_headshot = true

	if is_headshot:
		dmg *= 2.0
		is_critical = true
	elif is_backstab:
		dmg *= 2.0
		is_critical = true

	# Update/Create DamageInfo
	var final_info: DamageInfo
	if info_or_damage is DamageInfo:
		final_info = info_or_damage
		final_info.base_amount = dmg
		if is_critical:
			final_info.is_critical = true
			final_info.damage_type = DamageInfo.DamageType.CRITICAL
	else:
		final_info = DamageInfo.create(dmg, DamageInfo.DamageType.GENERIC, attacker)
		if is_critical:
			final_info.is_critical = true

	# Apply to Health Component
	var prev_health: float = 0.0
	if _health_component:
		prev_health = _health_component.current_health
		_health_component.take_damage(final_info)

	var potential_health: float = prev_health - dmg

	# Death/Gib Logic
	if potential_health <= 0:
		_handle_death(potential_health, final_info, bullet_dir, kb_force, source_id)

	# Knockback
	_apply_knockback(bullet_dir, kb_force)

	# Pain Feedback
	_handle_pain(dmg, kb_force, attacker)

	# Visuals (Blood)
	if hit_pos != Vector3.ZERO:
		var surf_normal: Vector3 = (hit_pos - _enemy.global_position).normalized()
		_enemy.sync_blood_hit.rpc(hit_pos, bullet_dir, int(dmg), surf_normal)

		# Spawn blood pool on floor (NEW!)
		if (
			GameManager.get_core_system("blood_effects")
			and GameManager.get_core_system("blood_effects").is_available()
		):
			GameManager.get_core_system("blood_effects").spawn_blood(hit_pos)

		# Spawn bullet hit decal on enemy body
		if _damage_mod == "bullet" or _damage_mod == "energy":
			_spawn_bullet_decal(hit_pos, surf_normal)

		# Visuals (Damage Numbers)
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.effects and gs.effects.has_method("spawn_floating_text"):
			var color: Color = Color.WHITE
			if is_critical:
				color = Color(1.0, 0.3, 0.1)
			gs.effects.spawn_floating_text.rpc(hit_pos, str(int(dmg)), color)


func _handle_death(
	potential_health: float, info: DamageInfo, death_dir_raw: Vector3, force: float, source_id: int
) -> void:
	_log("[EnemyDamageHandler] _handle_death called for " + " " + str(_enemy.name))
	_log("  - potential_health: " + " " + str(potential_health))
	_log("  - damage_type: " + " " + str(info.damage_type))
	_log("  - is_critical: " + " " + str(info.is_critical))
	_log("  - force: " + " " + str(force))
	_log("  - enemy.is_dead: " + " " + str(_enemy.is_dead))
	_log("  - enemy.visible: " + " " + str(_enemy.visible))

	var has_force: bool = death_dir_raw != Vector3.ZERO
	var death_dir: Vector3 = death_dir_raw.normalized() if has_force else Vector3.DOWN
	var death_force: float = force if has_force else 0.0
	var is_crit: bool = info.is_critical
	var d_type: int = info.damage_type

	# DOOM-STYLE: Immediate death state change
	_enemy.is_dead = true
	_log("[EnemyDamageHandler] Set enemy.is_dead = true")

	# Enhanced death audio feedback
	_play_death_sound(d_type, is_crit, potential_health)

	# Screen shake for dramatic impact
	_trigger_death_screen_shake(death_force, _enemy.global_position)

	# Emit unified death event
	GameManager.emit_event(
		"enemy_died",
		{
			"enemy_id": String(_enemy.enemy_id) if _enemy.get("enemy_id") else String(_enemy.name),
			"position": _enemy.global_position,
			"killer_id": source_id,
			"damage_type": d_type,
			"is_crit": is_crit,
			"overkill_damage": abs(potential_health) if potential_health < 0 else 0.0
		}
	)

	# Drop loot (server only)
	if not _enemy.multiplayer.has_multiplayer_peer() or _enemy.multiplayer.is_server():
		_drop_loot()

	# Enhanced gibbing logic with better thresholds
	var max_hp: float = _health_component.max_health if _health_component else 100.0
	var overkill_damage: float = abs(potential_health) if potential_health < 0 else 0.0
	var overkill_ratio: float = overkill_damage / max_hp

	var allow_gib: bool = false
	var gib_intensity: float = 1.0

	# ONLY allow gibbing for direct explosive hits (rockets, grenades, BFG)
	if d_type == DamageInfo.DamageType.EXPLOSIVE or d_type == DamageInfo.DamageType.EXPLOSION:
		# Direct explosive hit with overkill - allow gibbing
		if overkill_ratio > 0.3:
			allow_gib = true
			gib_intensity = min(overkill_ratio + 1.0, 3.0)
			_log(
				(
					"[EnemyDamageHandler] Gibbing allowed - overkill_ratio: "
					+ " "
					+ str(overkill_ratio)
				)
			)

	# All other deaths use ragdoll with hit animations
	if allow_gib:
		_log("[EnemyDamageHandler] Calling _gib_enemy")
		_gib_enemy(death_dir, source_id, gib_intensity)
	else:
		_log("[EnemyDamageHandler] Calling _play_death_animation (will lead to ragdoll)")
		# Use ragdoll death with appropriate hit animation
		_play_death_animation(d_type, is_crit, overkill_ratio, death_dir, death_force, source_id)


func _gib_enemy(death_dir: Vector3, source_id: int, intensity: float = 1.0) -> void:
	if not _enemy.multiplayer.has_multiplayer_peer() or _enemy.multiplayer.is_server():
		died.emit(source_id)

		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs:
			if gs.entity_registry:
				gs.entity_registry.unregister_enemy(_enemy)

			var gib_pos: Vector3 = _enemy.global_position + Vector3(0, 1, 0)
			if gs.effects:
				# Enhanced gore with intensity scaling (blood spray, particles)
				_log(
					(
						"[EnemyDamageHandler] Spawning gore effect at %s with intensity %.1f"
						% [gib_pos, intensity]
					)
				)

			# Use dismemberment system to detach actual limbs from the mesh
			# DON'T spawn additional gore effects - dismemberment handles it
			if _enemy.get("dismemberment_system"):
				_log("[EnemyDamageHandler] Triggering dismemberment system - detaching limbs")
				_enemy.dismemberment_system.dismember_body(
					_enemy.global_position,
					_enemy.velocity,
					last_damage_taken * intensity,
					death_dir
				)
			else:
				# Fallback: spawn generic gore if no dismemberment system
				if _enemy.multiplayer.has_multiplayer_peer():
					gs.effects.spawn_gore_effect.rpc(gib_pos, death_dir, intensity)
				else:
					gs.effects.spawn_gore_effect(gib_pos, death_dir, intensity)

			# NO organ gibs - only use actual mesh limbs via dismemberment

			# Additional dramatic effects for high-intensity gibs
			if intensity > 1.5 and gs.effects:
				# Extra blood spray
				gs.effects.spawn_blood_synced.rpc(gib_pos, Vector3.UP, intensity)
				# Screen flash for dramatic kills
				if gs.effects.has_method("screen_flash"):
					var flash_color: Color = Color(0.8, 0.1, 0.1, 0.4 * min(intensity, 2.0))
					gs.effects.screen_flash(flash_color, 0.2)

		_enemy.queue_free()


func _ragdoll_enemy(death_dir: Vector3, force: float, source_id: int) -> void:
	if not _enemy.multiplayer.has_multiplayer_peer() or _enemy.multiplayer.is_server():
		# NOTE: Enemy is already dead at this point (_enemy.is_dead = true)
		# We're just transitioning to ragdoll state

		died.emit(source_id)

		_log(
			(
				"[EnemyDamageHandler] Starting in-place ragdoll for %s with force %.1f"
				% [_enemy.name, force]
			)
		)

		# CRITICAL: Unregister from entity registry FIRST (fixes minimap cleanup)
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.entity_registry:
			gs.entity_registry.unregister_enemy(_enemy)

		# Use in-place ragdoll instead of spawning separate mesh
		if _enemy.visuals and _enemy.visuals.has_method("start_ragdoll"):
			_log("[EnemyDamageHandler] Starting in-place ragdoll on enemy skeleton")

			# Realistic ragdoll physics (HL2/Painkiller style)
			var realistic_force: float = force  # Use full force!
			var realistic_dir: Vector3 = death_dir

			# Ensure some upward lift for explosions or strong hits
			if force > 10.0 and realistic_dir.y < 0.2:
				realistic_dir.y = 0.4
				realistic_dir = realistic_dir.normalized()

			# Start ragdoll simulation on the enemy's skeleton
			_enemy.visuals.start_ragdoll(realistic_dir, realistic_force)

			_log("[EnemyDamageHandler] In-place ragdoll started successfully")

			# CRITICAL: Apply enemy's current velocity to ragdoll for momentum conservation
			if _enemy.velocity.length() > 0.1:
				_log(
					(
						"[EnemyDamageHandler] Applying enemy velocity to ragdoll: "
						+ " "
						+ str(_enemy.velocity)
					)
				)
				_enemy.visuals.call_deferred("_apply_velocity_to_ragdoll", _enemy.velocity)

			# NEW: Set ragdoll state (DEAD, but can accumulate damage for gibbing)
			_enemy.is_ragdolled = true
			_enemy.ragdoll_damage_taken = 0.0  # Start fresh damage counter
			_log("[EnemyDamageHandler] Ragdoll state active - enemy is DEAD but can be gibbed")

			# Hide health bar (enemy is dead)
			if _enemy.health_bar:
				_enemy.health_bar.visible = false

			# Disable enemy AI and movement
			if _enemy.ai_controller:
				_enemy.ai_controller.set_process(false)
				_enemy.ai_controller.set_physics_process(false)

			if _enemy.movement_component:
				_enemy.movement_component.set_process(false)
				_enemy.movement_component.set_physics_process(false)

			# CRITICAL: Disable physics processing to prevent falling through floor
			_enemy.set_physics_process(false)
			_enemy.set_process(false)

			# CRITICAL: Disable enemy collision AFTER ragdoll starts (give it 1 frame)
			# This prevents ragdoll from starting inside the enemy's collision volume
			await get_tree().process_frame
			_enemy.collision_layer = 0
			_enemy.collision_mask = 0

			# Schedule cleanup after ragdoll has settled (if not gibbed)
			var enemy_id: int = _enemy.get_instance_id()
			get_tree().create_timer(15.0).timeout.connect(
				_on_ragdoll_cleanup.bind(enemy_id), CONNECT_ONE_SHOT
			)
		else:
			_log("[EnemyDamageHandler] WARNING: Enemy visuals missing start_ragdoll method")
			# Fallback: just remove enemy
			_enemy.queue_free()


## Callback for ragdoll cleanup timer (uses instance ID to avoid memory leak)
func _on_ragdoll_cleanup(enemy_id: int) -> void:
	var enemy_instance: Node = instance_from_id(enemy_id)
	if is_instance_valid(enemy_instance) and not enemy_instance.is_queued_for_deletion():
		enemy_instance.queue_free()


## Handle damage to ragdolled enemies (accumulate damage to gib them)
## NOTE: Ragdolled enemies are DEAD - this is just for gibbing mechanics
func _handle_ragdoll_damage(
	info_or_damage: Variant,
	source_id_or_hit_pos: Variant,
	dir: Vector3,
	knockback: float,
	_damage_mod: String,
	_attacker: Node3D
) -> void:
	_log("[EnemyDamageHandler] Ragdoll (DEAD) taking damage for gibbing")

	var dmg: float = 0.0
	var source_id: int = 0
	var hit_pos: Vector3 = Vector3.ZERO
	var bullet_dir: Vector3 = dir

	# Parse arguments
	if info_or_damage is DamageInfo:
		var info: DamageInfo = info_or_damage
		dmg = info.base_amount
		source_id = info.source_id
		hit_pos = info.hit_position
		bullet_dir = info.knockback_direction
	else:
		dmg = float(info_or_damage)
		if typeof(source_id_or_hit_pos) == TYPE_INT:
			source_id = source_id_or_hit_pos
			hit_pos = _enemy.global_position + Vector3(0, 1.0, 0)
		elif typeof(source_id_or_hit_pos) == TYPE_VECTOR3:
			hit_pos = source_id_or_hit_pos

	# Accumulate damage (NOT reducing health - enemy is already dead)
	_enemy.ragdoll_damage_taken += dmg

	if OS.is_debug_build():
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.debug(
				(
					"Ragdoll damage accumulated: %d / %d (threshold)"
					% [_enemy.ragdoll_damage_taken, _enemy.ragdoll_gib_threshold]
				),
				"EnemyDamageHandler"
			)

	# Spawn blood effects
	if hit_pos != Vector3.ZERO:
		var surf_normal: Vector3 = (hit_pos - _enemy.global_position).normalized()
		_enemy.sync_blood_hit.rpc(hit_pos, bullet_dir, int(dmg), surf_normal)

		# Spawn blood pool on floor
		if (
			GameManager.get_core_system("blood_effects")
			and GameManager.get_core_system("blood_effects").is_available()
		):
			GameManager.get_core_system("blood_effects").spawn_blood(hit_pos)

	# Apply additional impulse to ragdoll
	if _enemy.visuals and bullet_dir != Vector3.ZERO:
		var impulse_force: float = knockback * 2.0  # Stronger impulse for ragdolls
		_enemy.visuals.call_deferred("_apply_ragdoll_impulse", bullet_dir, impulse_force)

	# Check if enough damage accumulated to gib
	if _enemy.ragdoll_damage_taken >= _enemy.ragdoll_gib_threshold:
		_log("[EnemyDamageHandler] Ragdoll damage threshold reached - gibbing!")
		_gib_ragdoll(bullet_dir, source_id)


## Gib a ragdolled enemy
func _gib_ragdoll(death_dir: Vector3, _source_id: int) -> void:
	_log("[EnemyDamageHandler] Gibbing ragdolled enemy")

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs:
		var gib_pos: Vector3 = _enemy.global_position + Vector3(0, 1, 0)

		# Use dismemberment system to detach actual limbs from the mesh
		# DON'T spawn additional gore effects - dismemberment handles it
		if _enemy.get("dismemberment_system"):
			_log("[EnemyDamageHandler] Triggering dismemberment - detaching limbs")
			_enemy.dismemberment_system.dismember_body(
				_enemy.global_position, _enemy.velocity, last_damage_taken * 2.0, death_dir
			)
		elif gs.effects:
			# Fallback: spawn generic gore if no dismemberment system
			_log("[EnemyDamageHandler] Spawning gore effect for ragdoll gib at %s" % gib_pos)

			if _enemy.multiplayer.has_multiplayer_peer():
				gs.effects.spawn_gore_effect.rpc(gib_pos, death_dir, 2.0)
			else:
				gs.effects.spawn_gore_effect(gib_pos, death_dir, 2.0)

		# NO organ gibs - only use actual mesh limbs via dismemberment

	# Remove the ragdolled enemy
	_enemy.queue_free()


func _apply_knockback(dir: Vector3, force: float) -> void:
	if dir == Vector3.ZERO or not _pain_system:
		return

	# Calculate knockback using pain system
	var knockback_velocity: Vector3 = _pain_system.calculate_knockback_velocity(
		force, _enemy.global_position, _enemy.global_position - dir
	)

	# Apply knockback to enemy velocity
	_enemy.velocity += knockback_velocity

	if OS.is_debug_build():
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.debug(
				(
					"Applied knockback: %s (force: %s, multiplier: %s)"
					% [knockback_velocity, force, _pain_system.get_knockback_multiplier()]
				),
				"EnemyDamageHandler"
			)


func _handle_pain(dmg: float, force: float, attacker: Node3D) -> void:
	# Check if pain system should trigger
	if _pain_system and _pain_system.should_trigger_pain(dmg):
		# Trigger pain state
		_pain_system.trigger_pain(dmg, attacker)

		if OS.is_debug_build():
			var logger: Node = GameManager.get_core_system("logger")
			if logger:
				logger.debug(
					(
						"Pain triggered - damage: %d, threshold: %d"
						% [dmg, _pain_system.pain_threshold]
					),
					"EnemyDamageHandler"
				)

		# Enhanced hit reaction with specific animations
		_play_hit_reaction_animation(dmg, force, attacker)

		# Pain feedback is now handled by BehaviorCoordinator
		if _enemy.behavior_coordinator:
			_enemy.behavior_coordinator.play_pain_feedback.rpc()

		# Interrupt AI for pain state
		if _enemy.ai_controller:
			if _enemy.ai_controller.has_method("interrupt_for_pain"):
				_enemy.ai_controller.interrupt_for_pain()
			if _enemy.ai_controller.has_method("on_damage_received") and attacker:
				_enemy.ai_controller.on_damage_received(attacker, dmg)
	else:
		# No pain triggered, but still play subtle hit reaction
		var time_now: float = Time.get_unix_time_from_system()
		if time_now > pain_debounce_time:
			pain_debounce_time = time_now + 0.3

			# Light hit reaction without interrupting AI
			_play_hit_reaction_animation(dmg, force, attacker)

			# Still notify AI of damage
			if (
				_enemy.ai_controller
				and _enemy.ai_controller.has_method("on_damage_received")
				and attacker
			):
				_enemy.ai_controller.on_damage_received(attacker, dmg)


func _play_hit_reaction_animation(dmg: float, force: float, attacker: Node3D) -> void:
	## Play specific hit reaction animations based on hit location and damage
	if not _enemy.visuals or not _enemy.visuals.has_method("play_hit_animation"):
		return

	# Determine hit location based on attacker position
	var hit_location: String = "chest"  # Default

	if attacker:
		var hit_dir: Vector3 = (_enemy.global_position - attacker.global_position).normalized()
		var relative_height: float = attacker.global_position.y - _enemy.global_position.y

		# Head shots (high damage from above)
		if relative_height > 1.0 and dmg > 30:
			hit_location = "head"
		# Stomach shots (low attacks)
		elif relative_height < -0.5:
			hit_location = "stomach"
		# Shoulder shots (side attacks)
		elif abs(hit_dir.x) > 0.6:
			hit_location = "shoulder_l" if hit_dir.x > 0 else "shoulder_r"

	# Heavy hits cause knockdown animations
	if force > 15.0 and dmg > 40:
		if randf() > 0.7:  # 30% chance for dramatic knockdown
			_enemy.visuals.play_knockdown_animation()
			return

	# Play appropriate hit animation
	_enemy.visuals.play_hit_animation(hit_location, dmg > 25.0)


func _play_death_animation(
	damage_type: int,
	is_crit: bool,
	overkill_ratio: float,
	death_dir: Vector3,
	death_force: float,
	source_id: int
) -> void:
	## Play dramatic death animation before transitioning to ragdoll
	_log("[EnemyDamageHandler] _play_death_animation called")
	_log("  - Enemy: " + " " + str(_enemy.name))
	_log("  - Visuals: " + " " + str(_enemy.visuals))
	_log("  - Visuals valid: " + " " + str(is_instance_valid(_enemy.visuals)))
	_log(
		(
			"  - Visuals has anim_player: "
			+ " "
			+ str(_enemy.visuals.anim_player if _enemy.visuals else "N/A")
		)
	)

	if not _enemy.visuals:
		_log("[EnemyDamageHandler] No visuals, going straight to ragdoll")
		_ragdoll_enemy(death_dir, death_force, source_id)
		return

	var death_anim: String = ""  # Empty for random selection
	var animation_duration: float = 1.0

	# Choose death animation based on damage type and overkill
	if overkill_ratio > 0.8 or is_crit:
		# Dramatic deaths for overkill/crits
		if damage_type == DamageInfo.DamageType.EXPLOSIVE:
			death_anim = "Celebration"  # Ironic "celebration" pose for explosive deaths
			animation_duration = 1.0  # Give it time to play
		elif randf() > 0.5:
			death_anim = "Death02"  # Alternative death animation
			animation_duration = 1.5  # Full animation
		else:
			death_anim = "Death01"
			animation_duration = 1.5  # Full animation
	elif death_force > 20.0:
		# High-force deaths get dramatic backflip
		death_anim = "BackFlip"
		animation_duration = 1.5  # Full animation
	else:
		# Standard death - let visuals pick random death animation
		death_anim = ""  # Empty string triggers random selection
		animation_duration = 1.5  # Full animation

	_log(
		(
			"[EnemyDamageHandler] Playing death animation: "
			+ " "
			+ str(death_anim if death_anim else "random")
		)
	)
	_log("[EnemyDamageHandler] Animation duration: " + " " + str(animation_duration))

	# Play the death animation
	if _enemy.visuals.has_method("play_death_animation"):
		_log(
			(
				"[EnemyDamageHandler] Calling visuals.play_death_animation("
				+ " "
				+ str(death_anim)
				+ " "
				+ ")"
			)
		)
		_enemy.visuals.play_death_animation(death_anim)
		_log("[EnemyDamageHandler] Death animation call completed")

		# Verify animation is actually playing
		if _enemy.visuals.anim_player:
			_log("[EnemyDamageHandler] AnimationPlayer state:")
			_log("  - is_playing: " + " " + str(_enemy.visuals.anim_player.is_playing()))
			_log(
				"  - current_animation: " + " " + str(_enemy.visuals.anim_player.current_animation)
			)
			_log("  - speed_scale: " + " " + str(_enemy.visuals.anim_player.speed_scale))
		else:
			_log("[EnemyDamageHandler] WARNING: No anim_player found!")

		# CRITICAL FIX: Ensure enemy stays visible during death animation
		_enemy.visible = true
		_enemy.sync_visible = true

		# CRITICAL FIX: Use call_deferred to ensure timer works correctly
		# Transition to ragdoll after animation
		call_deferred(
			"_schedule_ragdoll_transition",
			death_dir,
			death_force,
			source_id,
			animation_duration * 0.8  # Wait for most of the animation to play
		)
	else:
		_log("[EnemyDamageHandler] No play_death_animation method, going straight to ragdoll")
		# Fallback to immediate ragdoll
		_ragdoll_enemy(death_dir, death_force, source_id)


func _schedule_ragdoll_transition(
	death_dir: Vector3, death_force: float, source_id: int, delay: float
) -> void:
	## Helper to schedule ragdoll transition with proper timer handling
	_log("[EnemyDamageHandler] _schedule_ragdoll_transition called with delay: " + " " + str(delay))

	if not is_instance_valid(_enemy) or not is_inside_tree():
		_log("[EnemyDamageHandler] Enemy invalid or not in tree, aborting ragdoll transition")
		return

	# CRITICAL: Keep enemy visible during death animation
	_enemy.visible = true
	_enemy.sync_visible = true

	_log(
		(
			"[EnemyDamageHandler] Waiting "
			+ " "
			+ str(delay)
			+ " "
			+ " seconds before spawning ragdoll"
		)
	)
	await get_tree().create_timer(delay).timeout

	_log("[EnemyDamageHandler] Timer finished, checking if enemy still valid")

	# Verify enemy still exists before spawning ragdoll
	if is_instance_valid(_enemy) and not _enemy.is_queued_for_deletion():
		_log("[EnemyDamageHandler] Enemy still valid, spawning ragdoll now")
		# Ensure enemy is still visible before spawning ragdoll
		_enemy.visible = true
		_enemy.sync_visible = true
		_ragdoll_enemy(death_dir, death_force, source_id)
	else:
		_log("[EnemyDamageHandler] Enemy no longer valid, skipping ragdoll spawn")


func _play_death_sound(damage_type: int, is_crit: bool, potential_health: float) -> void:
	## Play appropriate death sound based on damage type and overkill
	if not GameManager.get_core_system("audio"):
		return

	var sound_event: String = "enemy_death"
	var pitch: float = 1.0
	var volume: float = 0.0

	# Enhanced death sounds based on damage type (modify pitch/volume)
	if damage_type == DamageInfo.DamageType.EXPLOSIVE:
		# Use base sound with explosion-like modifications
		pitch = randf_range(0.6, 0.8)  # Lower pitch
		volume = 3.0  # Louder for explosions
	elif is_crit:
		# Use base sound with dramatic modifications
		pitch = 0.8  # Lower pitch for dramatic effect
		volume = 2.0
	elif potential_health < -50:  # Overkill
		# Use base death sound with modified pitch/volume for overkill effect
		sound_event = "enemy_death"
		pitch = randf_range(0.7, 0.9)
		volume = 1.5

	GameManager.get_core_system("audio").play_event(
		sound_event, _enemy.global_position, false, volume, pitch
	)


func _trigger_death_screen_shake(force: float, position: Vector3) -> void:
	## Trigger screen shake for dramatic death impact
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.effects:
		return

	# Calculate shake intensity based on force and distance to player
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var distance: float = position.distance_to(player.global_position)
	var max_shake_distance: float = 15.0

	if distance > max_shake_distance:
		return

	var distance_factor: float = 1.0 - (distance / max_shake_distance)
	var shake_intensity: float = (force / 30.0) * distance_factor * 0.3

	if shake_intensity > 0.05:
		# Trigger screen shake (assuming there's a screen shake system)
		if gs.effects.has_method("screen_shake"):
			# Trigger screen shake
			gs.effects.screen_shake(shake_intensity, 0.4)


func _spawn_bullet_decal(hit_position: Vector3, hit_normal: Vector3) -> void:
	## Spawn bullet hit decal on enemy body
	_log("[EnemyDamageHandler] _spawn_bullet_decal called")
	_log("  - hit_position: " + " " + str(hit_position))
	_log("  - hit_normal: " + " " + str(hit_normal))
	_log("  - _bullet_decals: " + " " + str(_bullet_decals))

	if not _bullet_decals:
		push_warning("[EnemyDamageHandler] No bullet decals component found")
		return

	if not _bullet_decals.has_method("spawn_bullet_decal"):
		push_warning(
			"[EnemyDamageHandler] BulletDecals component missing spawn_bullet_decal method"
		)
		return

	_bullet_decals.spawn_bullet_decal(hit_position, hit_normal)
	_log("[EnemyDamageHandler] Spawned bullet decal at " + " " + str(hit_position))


func _drop_loot() -> void:
	## Drop loot when enemy dies (server only)
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.loot:
		return

	# Get loot table ID from enemy
	var loot_table_id: String = ""
	if "loot_table_id" in _enemy and _enemy.loot_table_id:
		loot_table_id = _enemy.loot_table_id
	elif "enemy_id" in _enemy and _enemy.enemy_id:
		# Default: use enemy_id as loot table (e.g., "zombie" -> "zombie_loot")
		loot_table_id = _enemy.enemy_id + "_loot"
	else:
		# Fallback: generic enemy loot
		loot_table_id = "enemy_loot"

	# Spawn loot at enemy position
	var loot_pos: Vector3 = _enemy.global_position + Vector3(0, 0.5, 0)
	gs.loot.spawn_loot_from_table(loot_pos, loot_table_id, _enemy.get_path())

	_log(
		(
			"[EnemyDamageHandler] Dropped loot from table: "
			+ " "
			+ str(loot_table_id)
			+ " "
			+ " at "
			+ " "
			+ str(loot_pos)
		)
	)
