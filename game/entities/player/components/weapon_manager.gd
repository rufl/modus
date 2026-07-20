class_name WeaponManager
extends GameComponent3D

## Integrated Weapon Manager using modular architecture
## Orchestrates all weapon-related systems through focused modules

signal ammo_changed(current: int, reserve: int, weapon: String)
signal weapon_switched(weapon_name: String)
signal weapon_fired(weapon_name: String, position: Vector3, direction: Vector3)
signal reload_started(duration: float)
signal reload_finished
signal barrel_spinning(speed: float)

# Module references
var inventory: WeaponInventory
var ammo_system: WeaponAmmoSystem
var fire_handler: WeaponFireHandler
var hit_detector: WeaponHitDetector
var network_sync: WeaponNetworkSync
var melee_system: WeaponMeleeSystem
var visuals: Node  # WeaponVisuals
var vfx: Node  # WeaponVFX

# Core references
var camera: Camera3D
var player: CharacterBody3D
var weapon_holder_node: Node3D
var gunshot_sound: AudioStreamPlayer3D

var _default_muzzle_offset: Vector3 = Vector3(0, -0.2, -0.5)


func _log(message: String, category: String = "WeaponManager") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


# Convenience property for accessing current weapon index
var current_weapon_index: int:
	get:
		return inventory.current_weapon_index if inventory else 0


func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		set_physics_process(true)

	# Connect to config reload using safe_connect
	if GameManager.get_core_system("config"):
		safe_connect(GameManager.get_core_system("config").config_reloaded, _on_config_reloaded)


func _exit_tree() -> void:
	# Automatic cleanup handled by GameComponent base class
	super._exit_tree()


func setup(
	p_player: CharacterBody3D, cam: Camera3D, holder: Node3D, audio: AudioStreamPlayer3D
) -> void:
	player = p_player
	camera = cam
	weapon_holder_node = holder
	gunshot_sound = audio

	_load_config()
	_setup_modules()
	_connect_signals()

	# Select first weapon and emit initial ammo
	# FIXED: Use await instead of call_deferred to ensure proper initialization order
	if inventory and inventory.weapons.size() > 0:
		switch_to_weapon(0)
		await get_tree().process_frame
		_emit_initial_ammo()


func _setup_modules() -> void:
	# 1. Inventory (no dependencies)
	inventory = WeaponInventory.new()
	inventory.name = "WeaponInventory"
	add_child(inventory)
	inventory.setup(weapon_holder_node, camera)
	inventory.load_weapons_from_database()
	inventory.setup_weapon_models()

	# 2. Ammo System (depends on inventory)
	ammo_system = WeaponAmmoSystem.new()
	ammo_system.name = "WeaponAmmoSystem"
	add_child(ammo_system)
	ammo_system.setup(inventory)
	ammo_system.initialize_ammo(inventory.weapons)

	# 3. Fire Handler (depends on inventory, ammo)
	fire_handler = WeaponFireHandler.new()
	fire_handler.name = "WeaponFireHandler"
	add_child(fire_handler)
	fire_handler.setup(camera, player, gunshot_sound, inventory, ammo_system)

	# 4. Hit Detector (depends on inventory)
	hit_detector = WeaponHitDetector.new()
	hit_detector.name = "WeaponHitDetector"
	add_child(hit_detector)
	hit_detector.setup(player, inventory)

	# 5. Network Sync (depends on inventory, ammo)
	network_sync = WeaponNetworkSync.new()
	network_sync.name = "WeaponNetworkSync"
	add_child(network_sync)
	network_sync.setup(player, camera, inventory, ammo_system)

	# 6. Melee System (depends on inventory)
	melee_system = WeaponMeleeSystem.new()
	melee_system.name = "WeaponMeleeSystem"
	add_child(melee_system)
	melee_system.setup(player, camera, inventory)

	# 7. Visuals (optional, if exists)
	var WeaponVisualsScript: Script = preload(
		"res://game/entities/player/components/weapon_visuals.gd"
	)
	if WeaponVisualsScript:
		visuals = WeaponVisualsScript.new()
		visuals.name = "WeaponVisuals"
		add_child(visuals)
		visuals.setup(self, weapon_holder_node, camera, player)

	# 8. VFX (optional, if exists)
	var vfx_path: String = "res://game/entities/player/components/weapon_vfx_spawner.gd"
	if ResourceLoader.exists(vfx_path):
		var weapon_vfx_spawner_script: Script = load(vfx_path)
		if weapon_vfx_spawner_script:
			vfx = weapon_vfx_spawner_script.new()
			vfx.name = "WeaponVFX"
			add_child(vfx)
			vfx.setup(camera)
			_log("[WeaponManager] VFX component created: %s" % vfx, "Player")
		else:
			_log("[WeaponManager] Failed to load VFX script", "Player")
	else:
		_log("[WeaponManager] VFX script not found at: %s" % vfx_path, "Player")


func _connect_signals() -> void:
	# Forward module signals to external listeners using safe_connect
	if inventory:
		safe_connect(inventory.weapon_switched, _on_weapon_switched)

	if ammo_system:
		safe_connect(ammo_system.ammo_changed, _on_ammo_changed)
		safe_connect(ammo_system.reload_started, _on_reload_started)
		safe_connect(ammo_system.reload_finished, _on_reload_finished)

	if fire_handler:
		safe_connect(fire_handler.weapon_fired, _on_weapon_fired)
		safe_connect(fire_handler.barrel_spinning, _on_barrel_spinning)

	# DEBUG: Weapon visibility check
	await get_tree().process_frame
	await get_tree().process_frame
	_log("[WeaponManager] === WEAPON VISIBILITY DEBUG ===", "Player")
	_log("[WeaponManager] Weapon holder exists: %s" % (weapon_holder_node != null), "Player")
	if weapon_holder_node:
		_log("[WeaponManager] Weapon holder visible: %s" % weapon_holder_node.visible, "Player")
		_log("[WeaponManager] Weapon holder position: %s" % weapon_holder_node.position, "Player")
		_log(
			"[WeaponManager] Weapon holder children: %d" % weapon_holder_node.get_child_count(),
			"Player"
		)
		for child in weapon_holder_node.get_children():
			_log(
				(
					"[WeaponManager]   - Child: %s visible: %s position: %s"
					% [
						child.name,
						child.visible if child is Node3D else "N/A",
						child.position if child is Node3D else "N/A"
					]
				),
				"Player"
			)
	if inventory:
		var current_weapon: Node3D = inventory.get_current_weapon_scene()
		_log("[WeaponManager] Current weapon node: %s" % current_weapon, "Player")
		if current_weapon:
			_log("[WeaponManager] Current weapon visible: %s" % current_weapon.visible, "Player")
			_log("[WeaponManager] Current weapon position: %s" % current_weapon.position, "Player")
			_log(
				(
					"[WeaponManager] Current weapon global position: %s"
					% current_weapon.global_position
				),
				"Player"
			)
	var cam_pos: String = str(camera.global_position) if camera else "NO CAMERA"
	_log("[WeaponManager] Camera position: " + cam_pos, "Player")

	var cam_fwd: String = str(-camera.global_transform.basis.z) if camera else "NO CAMERA"
	_log("[WeaponManager] Camera forward: " + cam_fwd, "Player")
	_log("[WeaponManager] === END DEBUG ===", "Player")


func _on_weapon_switched(weapon_name: String, _weapon_index: int) -> void:
	weapon_switched.emit(weapon_name)

	# Update ammo display
	if ammo_system:
		ammo_system.emit_ammo_update()

	# Reset spin state
	if fire_handler:
		fire_handler.reset_spin()
		var weapon: WeaponData = inventory.get_current_weapon()
		if weapon:
			fire_handler.assign_weapon_audio(weapon)

	# Cancel reload
	if ammo_system:
		ammo_system.cancel_reload()

	# Emit event
	GameManager.emit_event("weapon_switched", {"weapon_name": weapon_name})


func _on_ammo_changed(current: int, reserve: int, weapon: String) -> void:
	ammo_changed.emit(current, reserve, weapon)


func _on_reload_started(duration: float) -> void:
	reload_started.emit(duration)


func _on_reload_finished() -> void:
	reload_finished.emit()


func _on_weapon_fired(weapon_name: String, fire_position: Vector3, direction: Vector3) -> void:
	weapon_fired.emit(weapon_name, fire_position, direction)

	# Trigger visual effects
	if visuals:
		visuals.apply_visual_recoil()

	# Spawn muzzle flash and smoke
	var weapon: WeaponData = inventory.get_current_weapon()
	if weapon and vfx:
		# Spawn muzzle flash (light + particles)
		if vfx.has_method("spawn_muzzle_flash"):
			var muzzle_pos: Vector3 = inventory.get_muzzle_position(_default_muzzle_offset)
			vfx.spawn_muzzle_flash(muzzle_pos)
			_log("[WeaponManager] Spawned muzzle flash at %s" % muzzle_pos, "Player")

		# Spawn muzzle smoke
		if vfx.has_method("spawn_muzzle_smoke"):
			var muzzle_pos: Vector3 = inventory.get_muzzle_position(_default_muzzle_offset)
			vfx.spawn_muzzle_smoke(muzzle_pos)
			_log("[WeaponManager] Spawned muzzle smoke at %s" % muzzle_pos, "Player")

	# Spawn cartridge ejection
	if weapon and weapon.cartridge_eject_enabled and vfx:
		_log("[WeaponManager] Spawning cartridge for weapon: %s" % weapon.weapon_name, "Player")
		_spawn_cartridge_visuals(weapon, fire_position, direction)
	elif weapon:
		_log(
			(
				"[WeaponManager] Cartridge ejection disabled or no VFX. Enabled: %s, VFX: %s"
				% [weapon.cartridge_eject_enabled, vfx != null]
			),
			"Player"
		)


func _on_barrel_spinning(speed: float) -> void:
	barrel_spinning.emit(speed)


func _emit_initial_ammo() -> void:
	if ammo_system:
		ammo_system.emit_ammo_update()


func _load_config() -> void:
	var ui_svc: Node = GameManager.get_core_system("ui")
	if not ui_svc or not "hud_weapon_settings" in ui_svc:
		return

	var settings: Dictionary = ui_svc.hud_weapon_settings
	var defaults: Dictionary = settings.get("defaults", {}).get("weapon", {})

	if defaults.has("muzzleFlashOffset"):
		var offset_array: Array = defaults.muzzleFlashOffset
		if offset_array.size() >= 3:
			_default_muzzle_offset = Vector3(
				float(offset_array[0]), float(offset_array[1]), float(offset_array[2])
			)


func _on_config_reloaded(_file_path: String = "") -> void:
	_load_config()
	if inventory:
		var ui_svc: Node = GameManager.get_core_system("ui")
		if ui_svc and "hud_weapon_settings" in ui_svc:
			var settings: Dictionary = ui_svc.hud_weapon_settings
			# Pass the 'weapons' dictionary directly to inventory
			if settings.has("weapons"):
				inventory.apply_weapon_adjustments(settings.weapons)


func _unhandled_input(event: InputEvent) -> void:
	var is_local: bool = not multiplayer.has_multiplayer_peer() or player.is_multiplayer_authority()
	if event is InputEventMouseMotion and is_local:
		if visuals:
			visuals.handle_mouse_input(event.relative)


func _process(delta: float) -> void:
	# Update spin mechanics
	if fire_handler:
		fire_handler.update_spin(delta)

	# Update visuals - in single player (no peer), always update for local player
	var is_local: bool = not multiplayer.has_multiplayer_peer() or player.is_multiplayer_authority()
	if is_local and visuals:
		visuals.process_visuals(delta)


# ============================================================================
# PUBLIC API
# ============================================================================

var _is_switching: bool = false


func switch_to_weapon(index: int) -> void:
	if _is_switching:
		return

	if inventory:
		# 1. Holster current (if applicable)
		var current_node: Node3D = inventory.get_current_weapon_scene()
		if current_node:
			var anim: AnimationPlayer = _find_animation_player(current_node)
			if anim and anim.has_animation("Unequip"):
				_is_switching = true
				anim.play("Unequip")
				await anim.animation_finished
				_is_switching = false

		# 2. Switch Data/Visuals
		inventory.switch_to_weapon(index)

		# 3. Draw new (if applicable)
		var new_node: Node3D = inventory.get_current_weapon_scene()
		if new_node:
			var anim: AnimationPlayer = _find_animation_player(new_node)
			if anim and anim.has_animation("Equip"):
				_is_switching = true
				anim.play("Equip")
				# Optional: wait for equip to finish before allowing fire?
				# For responsiveness, we might want to allow early exit or just block firing.
				# Let's block firing until equip is done.
				await anim.animation_finished
				_is_switching = false


func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
	return null


func fire(input_pressed: bool, input_just_pressed: bool) -> void:
	if _is_switching:
		return

	if not fire_handler:
		return

	if fire_handler.fire(input_pressed, input_just_pressed):
		# Fire was successful, handle server logic
		var origin: Vector3 = inventory.get_muzzle_position(_default_muzzle_offset)
		var direction: Vector3 = -camera.global_transform.basis.z

		if multiplayer.is_server():
			perform_server_fire(origin, direction, inventory.current_weapon_index)
		else:
			network_sync.request_fire_to_server(origin, direction, inventory.current_weapon_index)


func start_reload() -> void:
	if ammo_system:
		ammo_system.start_reload()


func quick_melee() -> void:
	if melee_system:
		melee_system.quick_melee()


func get_current_weapon() -> WeaponData:
	if inventory:
		return inventory.get_current_weapon()
	return null


func get_current_ammo() -> Array:
	if ammo_system:
		return ammo_system.get_current_ammo()
	return [0, 0]


func get_ammo_data() -> Dictionary:
	if ammo_system:
		return ammo_system.get_ammo_data()
	return {}


func apply_ammo_data(data: Dictionary) -> void:
	if ammo_system:
		ammo_system.apply_ammo_data(data)


func refill_ammo() -> void:
	## Refills all ammo to maximum (used on respawn)
	if ammo_system:
		ammo_system.refill_all_ammo()


# ============================================================================
# SERVER LOGIC
# ============================================================================


func perform_server_fire(origin: Vector3, direction: Vector3, weapon_idx: int) -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return

	if weapon_idx < 0 or weapon_idx >= inventory.weapons.size():
		return

	var weapon: WeaponData = inventory.weapons[weapon_idx]

	# Register shot
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service and gs.match_service.has_method("register_shot_fired"):
		gs.match_service.register_shot_fired(player.name.to_int())

	# Consume ammo
	if not ammo_system.consume_ammo(weapon_idx):
		return

	# Sync ammo to client
	var sender_id: int = player.name.to_int()
	var ammo: Array = ammo_system.get_current_ammo()
	network_sync.sync_ammo_to_client(weapon_idx, ammo[0], ammo[1], sender_id)

	# Fire logic
	if weapon.projectile_scene:
		_spawn_projectile_server(weapon, origin, direction)
	else:
		_fire_hitscan_server(weapon, origin, direction)

	# Broadcast effects
	network_sync.broadcast_fire_effects(weapon.weapon_name, origin, direction, weapon_idx)


func _fire_hitscan_server(weapon: WeaponData, origin: Vector3, direction: Vector3) -> void:
	var hits: Array[Dictionary] = []

	# Apply Lag Compensation
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var lag_comp: Node = null
	if gs and gs.combat and "lag_compensation" in gs.combat:
		lag_comp = gs.combat.lag_compensation

	if lag_comp and lag_comp.has_method("start_compensation"):
		lag_comp.start_compensation(player.name.to_int())

	# Perform raycasts
	hits = hit_detector.fire_hitscan(weapon, origin, direction)

	# End Lag Compensation
	if lag_comp and lag_comp.has_method("end_compensation"):
		lag_comp.end_compensation()

	for hit in hits:
		_process_hit(hit, weapon)

		# Spawn tracer
		# Spawn tracer
		_log(
			"[WeaponManager] Attempting to spawn tracer from %s to %s" % [origin, hit.position],
			"Player"
		)
		if vfx and vfx.has_method("spawn_bullet_tracer"):
			_log("[WeaponManager] VFX has spawn_bullet_tracer method, calling RPC", "Player")
			vfx.spawn_bullet_tracer.rpc(
				origin, hit.position, weapon.tracer_color, weapon.tracer_width
			)
		else:
			_log("[WeaponManager] VFX missing or no spawn_bullet_tracer method", "Player")


func _process_hit(hit: Dictionary, weapon: WeaponData) -> void:
	var collider: Object = hit.collider
	var hit_pos: Vector3 = hit.position
	var hit_normal: Vector3 = hit.normal

	# Calculate damage
	var damage_info: Dictionary = hit_detector.calculate_damage(weapon)
	var final_damage: int = damage_info.final
	var is_crit: bool = damage_info.is_crit

	# Detect high velocity weapons (railgun, sniper, etc.)
	var is_high_velocity: bool = _is_high_velocity_weapon(weapon)

	# Find enemy
	var enemy: Enemy = hit_detector.find_enemy_from_collider(collider)

	if enemy:
		# Apply damage through combat service directly
		var combat_service: Node = GameManager.get_core_system("combat")
		if combat_service and combat_service.has_method("apply_damage"):
			combat_service.apply_damage(
				enemy,
				final_damage,
				player,
				weapon.damage_type,
				weapon,
				is_crit,
				player.name.to_int(),
				hit_pos,
				hit_normal
			)
		else:
			push_warning("[WeaponManager] Combat service not available - damage not applied")

		# Spawn blood effects (same as knife/melee for consistency)
		var gs2 := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs2 and gs2.effects:
			if gs2.effects.has_method("spawn_blood_synced"):
				gs2.effects.spawn_blood_synced.rpc(
					hit_pos, hit_normal, 1.0 if is_high_velocity else 0.5
				)
			if gs2.effects.has_method("spawn_gore_effect"):
				gs2.effects.spawn_gore_effect.rpc(
					hit_pos, -hit_normal, 5.0 if is_high_velocity else 3.0
				)

		# Handle affix effects
		var effects: Dictionary = hit_detector.get_affix_effects(weapon)
		_apply_affix_effects(enemy, hit_pos, final_damage, effects)

	elif collider is CharacterBody3D:
		# Player PVP
		var hit_player: CharacterBody3D = collider as CharacterBody3D
		if hit_player.has_method("receive_damage"):
			hit_player.receive_damage.rpc_id(
				hit_player.get_multiplayer_authority(),
				final_damage,
				multiplayer.get_unique_id(),
				player.global_position
			)

	else:
		# Wall or prop
		if vfx:
			if vfx.has_method("spawn_bullet_hole"):
				vfx.spawn_bullet_hole.rpc(hit_pos, hit_normal)
			if vfx.has_method("spawn_wall_debris"):
				vfx.spawn_wall_debris.rpc(hit_pos, hit_normal)


func _apply_affix_effects(enemy: Enemy, hit_pos: Vector3, damage: int, effects: Dictionary) -> void:
	# Lifesteal
	if effects.lifesteal > 0:
		var heal_amount: int = int(damage * effects.lifesteal)
		if heal_amount > 0 and player.has_method("heal"):
			player.heal(heal_amount)

	# Chain damage
	if effects.chain_count > 0:
		_apply_chain_damage(
			enemy.get_path(), hit_pos, damage, effects.chain_count, effects.chain_falloff
		)

	# Splash damage
	if effects.splash_radius > 0:
		var splash_damage: int = int(damage * effects.splash_mult)
		_apply_splash_damage(hit_pos, splash_damage, effects.splash_radius, enemy.get_path())


func _apply_chain_damage(
	origin_path: NodePath, origin_pos: Vector3, damage: int, chains: int, falloff: float
) -> void:
	if chains <= 0:
		return

	var chain_damage: int = int(damage * falloff)
	if chain_damage <= 0:
		return

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var enemies: Array = []
	if gs and gs.entity_registry:
		enemies = gs.entity_registry.get_all_enemies()

	var closest_enemy: Node3D = null
	var closest_dist: float = INF

	for enemy: Node3D in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get_path() == origin_path:
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue

		var dist: float = origin_pos.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy

	if closest_enemy and closest_enemy.has_method("take_damage"):
		closest_enemy.call_deferred("take_damage", chain_damage, player.name.to_int())

		# Spawn chain VFX
		if vfx and vfx.has_method("spawn_chain_effect"):
			vfx.spawn_chain_effect.rpc(origin_pos, closest_enemy.global_position)

		# Continue chain
		if chains > 1:
			call_deferred(
				"_apply_chain_damage",
				closest_enemy.get_path(),
				closest_enemy.global_position,
				chain_damage,
				chains - 1,
				falloff
			)


func _apply_splash_damage(
	center: Vector3, damage: int, radius: float, exclude_path: NodePath
) -> void:
	# Spawn explosion mark at impact point
	if vfx and vfx.has_method("spawn_explosion_mark"):
		# Use upward normal for ground explosions
		var explosion_normal: Vector3 = Vector3.UP
		vfx.spawn_explosion_mark.rpc(center, explosion_normal, radius)

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var enemies: Array = []
	if gs and gs.entity_registry:
		enemies = gs.entity_registry.get_all_enemies()

	for enemy: Node3D in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get_path() == exclude_path:
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue

		var dist: float = center.distance_to(enemy.global_position)
		if dist <= radius:
			var falloff: float = 1.0 - (dist / radius)
			var splash_dmg: int = int(damage * falloff)
			if splash_dmg > 0 and enemy.has_method("take_damage"):
				enemy.call_deferred("take_damage", splash_dmg, player.name.to_int())


func _spawn_projectile_server(weapon: WeaponData, origin: Vector3, direction: Vector3) -> void:
	var pool_service: Node = GameManager.get_core_system("pools")
	if not pool_service:
		return

	var proj: Node3D = (
		pool_service.get_instance(weapon.projectile_scene.resource_path)
		if pool_service.has_method("get_instance")
		else null
	)
	if not proj:
		proj = weapon.projectile_scene.instantiate()

	proj.name = "Projectile_" + str(player.name.to_int()) + "_" + str(Time.get_ticks_msec())

	var rot: Basis = Basis.looking_at(direction)
	proj.transform = Transform3D(rot, origin)

	# Remove from pool parent before adding to tree
	if proj.get_parent():
		proj.get_parent().remove_child(proj)

	get_tree().root.add_child(proj)

	if proj.has_method("launch"):
		if "damage" in proj:
			proj.damage = weapon.damage
		if "speed" in proj:
			proj.speed = weapon.projectile_speed
		if "shooter_id" in proj:
			proj.shooter_id = player.name.to_int()
		if "pool_scene_path" in proj:
			proj.pool_scene_path = weapon.projectile_scene.resource_path

		proj.launch(origin, direction, player)


func _spawn_cartridge_visuals(weapon: WeaponData, origin: Vector3, direction: Vector3) -> void:
	if not weapon or not weapon.cartridge_eject_enabled or not vfx:
		_log(
			(
				"[WeaponManager] Cannot spawn cartridge - weapon: %s, enabled: %s, vfx: %s"
				% [weapon != null, weapon.cartridge_eject_enabled if weapon else false, vfx != null]
			),
			"Player"
		)
		return

	if not vfx.has_method("spawn_cartridge"):
		_log("[WeaponManager] VFX does not have spawn_cartridge method", "Player")
		return

	var eject_basis: Basis
	if abs(direction.y) < 0.99:
		eject_basis = Basis.looking_at(direction, Vector3.UP)
	else:
		eject_basis = Basis.looking_at(direction, Vector3.RIGHT)

	var start_pos: Vector3 = origin + (eject_basis * weapon.cartridge_eject_offset)
	var eject_dir: Vector3 = (eject_basis.x + eject_basis.y * 0.5).normalized()

	_log(
		(
			"[WeaponManager] Calling spawn_cartridge at %s with dir %s, scale %s, scene: %s"
			% [start_pos, eject_dir, weapon.cartridge_scale, weapon.cartridge_scene_path]
		),
		"Player"
	)
	vfx.spawn_cartridge(start_pos, eject_dir, weapon.cartridge_scale, weapon.cartridge_scene_path)


func _is_high_velocity_weapon(weapon: WeaponData) -> bool:
	## Detect high velocity weapons (railgun, sniper, etc.) for special blood decals
	if not weapon:
		return false

	var weapon_name_lower: String = weapon.weapon_name.to_lower()

	# Check for high velocity weapon names
	return (
		weapon_name_lower.contains("rail")
		or weapon_name_lower.contains("sniper")
		or weapon_name_lower.contains("gauss")
		or weapon_name_lower.contains("lightning")
	)
