class_name Enemy
extends CharacterBody3D

# Dynamic loading used to prevent cyclic dependencies with components
const TIER_PREFIXES: Dictionary = {1: "", 2: "", 3: "tier_elite", 4: "tier_boss"}
const TIER_COLORS: Dictionary = {
	1: Color(0.8, 0.8, 0.8),  # Normal - Gray
	2: Color(0.2, 0.8, 0.2),  # Veteran - Green
	3: Color(0.2, 0.4, 1.0),  # Elite - Blue
	4: Color(1.0, 0.6, 0.0)  # Boss - Orange
}
const ENEMY_INTERP_SPEED: float = 15.0  # Faster than players for more responsive AI

@export var enemy_id: String = "grunt_basic"
@export var mass: float = 150.0  # Grunt=100, Tank=400+
@export var is_ai_active: bool = true
@export var ai_state_name: String = "Idle"
@export var loot_table_id: String = ""

var health_component: HealthComponent
var movement_component: MovementComponent
var perception_component: PerceptionComponent
var combat_component: CombatComponent
var ai_controller: EnemyAIController
var pain_system: PainSystem
var dismemberment_system: DismembermentSystem
var organ_gib_system: OrganGibSystem
var blood_hit_spawner: BloodHitSpawner
var status_effect_manager: StatusEffectManager
var visual_effects_component: Node  # EnemyVisualEffects
var damage_handler: Node  # EnemyDamageHandler
var spawn_coordinator: Node  # EnemySpawnCoordinator
var behavior_coordinator: Node  # EnemyBehaviorCoordinator
var override_corpse_scene: PackedScene = null
var pain_debounce_time: float = 0.0
var health: float = 100.0
var max_health: float = 100.0
var is_dead: bool = false
var is_ragdolled: bool = false  # NEW: Track if enemy is in ragdoll state (DEAD but can be gibbed)
var ragdoll_damage_taken: float = 0.0  # NEW: Damage accumulator for gibbing (NOT health)
var ragdoll_gib_threshold: float = 100.0  # Damage needed to gib ragdoll
var is_fleeing: bool = false
var is_in_cover: bool = false
var is_aggressive: bool = false  # Aggressive against all (enemies + players)
var debug_state_name: String = "Unknown"  # Synced for debug visualization
var display_name: String = "Enemy"  # Full constructed name (synced)
var base_name: String = "Enemy"  # Base enemy name from data
# Enemy tier (1-4)
var tier: int = 1:
	set(value):
		tier = clampi(value, 1, 4)
		_apply_tier_stat_floor()
var attack_type: String = "melee"  # melee, ranged, flying_ranged
var can_fly: bool = false
var applied_modifiers: Array[EnemyModifier] = []  # Active affixes
var nameplate: Label3D = null  # Billboard label above enemy
var health_bar: EnemyHealthBar = null  # 3D health bar above enemy
var base_color: Color = Color.WHITE
var is_targeted: bool = false
var is_aggro: bool = false:
	set(value):
		is_aggro = value
var debug_visuals: Node  # EnemyDebugVisuals component
var sync_position: Vector3:
	set(value):
		sync_position = value
		_target_position = value
		if not _is_remote:
			global_position = value
	get:
		return global_position
var sync_rotation: Vector3:
	set(value):
		sync_rotation = value
		_target_rotation = value
		if not _is_remote:
			rotation = value
	get:
		return rotation
var sync_visible: bool = true:
	set(value):
		sync_visible = value
		visible = value
	get:
		return visible

@onready var visuals: SkeletalCharacterVisuals = get_node_or_null("Visuals") as SkeletalCharacterVisuals

var _ai_update_rate: float = 1.0  # 1.0 = full rate, 0.5 = half rate, etc.
var _ai_update_offset: float = 0.0  # Stagger updates across frames
var _ai_update_timer: float = 0.0
var _death_y_threshold: float = -50.0  # Loaded from config
var _alert_icon: Label3D  # Client side visual
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation: Vector3 = Vector3.ZERO
var _is_remote: bool = false
var _synchronizer: MultiplayerSynchronizer


func _log(message: String, category: String = "Enemy") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info(message, category)
	else:
		print(message)


func _log_warning(message: String, category: String = "Enemy") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.warning(message, category)
	else:
		push_warning(message)


func _log_error(message: String, category: String = "Enemy") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.error(message, category)
	else:
		push_error(message)


func _log_debug(message: String, category: String = "Enemy") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger and logger.has_method("debug"):
		logger.debug(message, category)
	else:
		print(message)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE: Disconnect all signals to prevent memory leaks ===

	# 1. MatchService debug toggle
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	if gs and gs.match_service:
		if gs.match_service.debug_vision_toggled.is_connected(_on_debug_vision_toggled):
			gs.match_service.debug_vision_toggled.disconnect(_on_debug_vision_toggled)

	# 2. Synchronizer signals
	var synchronizer: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")
	if synchronizer and synchronizer.delta_synchronized.is_connected(_on_properties_synchronized):
		synchronizer.delta_synchronized.disconnect(_on_properties_synchronized)

	# 3. Unregister from GameManager.get_core_system("entity") (if not already done in death)
	if gs and gs.entity_registry:
		gs.entity_registry.unregister_enemy(self)


func _ready() -> void:
	# Avoid running on client if server-authoritative logic is required,
	# but for now let's allow it to initialize on both or check authority.
	# Typically AI only runs on server.
	# 1. Load Data
	var gm: Node = get_node_or_null("/root/GameManager")
	var data_service: Node = gm.get_core_system("data") if gm else null
	var data: Dictionary = {}
	if has_meta("enemy_builder_data"):
		data = (get_meta("enemy_builder_data") as Dictionary).duplicate(true)
		remove_meta("enemy_builder_data")
	elif data_service:
		data = data_service.get_enemy_data(enemy_id)

	# Register in enemies group (once only)
	if not is_in_group("enemies"):
		add_to_group("enemies")

	if data.is_empty():
		push_warning("Enemy initialized with invalid ID: " + enemy_id + " - using default stats")
		# Use default fallback data so enemy still functions
		data = {
			"name": enemy_id.capitalize(),
			"tier": 1,
			"role": "basic",
			"stats":
			{
				"health": 30,
				"damage": 5,
				"speed": 4.0,
				"attack_range": 2.0,
				"attack_cooldown": 1.5,
				"aggression": 0.5
			},
			"combat": {"attack_type": "melee", "projectile_speed": 0.0}
		}

	# 2. Setup Components
	EnemyBuilder.build_components(self, data)

	# Apply meta aggression if set from spawn command/manager
	if has_meta("spawn_aggressive"):
		is_aggressive = get_meta("spawn_aggressive")

	if is_aggressive and perception_component:
		perception_component.aggressive_against_all = true

	# 3. Setup AI (Only on Server usually)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_setup_ai(data)

	# 4. Apply Visuals and load custom assets
	visual_effects_component = EnemyVisualEffects.new()
	visual_effects_component.name = "VisualEffects"
	add_child(visual_effects_component)
	visual_effects_component.setup(self, visuals)
	if visuals:
		# Apply tier color from data or default
		visuals.set_color(data.get("visuals", {}).get("color", TIER_COLORS[tier]))

		# Setup dismemberment system with visuals
		if dismemberment_system:
			dismemberment_system.setup(visuals)
	else:
		push_warning("[Enemy] Visuals node is missing or script failed to load!")

	# 4a. Setup Animation Component (Locomotion Blend Tree)
	var anim_script: Script = load(
		"res://game/entities/enemies/components/enemy_animation_component.gd"
	)
	if anim_script:
		var animation_component: Node = anim_script.new()
		animation_component.name = "AnimationComponent"
		add_child(animation_component)
		animation_component.setup(self)

	# 4b. Setup Bullet Decals Component
	var decals_script: Script = load(
		"res://game/entities/enemies/components/enemy_bullet_decals.gd"
	)
	if decals_script:
		var bullet_decals: Node = decals_script.new()
		bullet_decals.name = "BulletDecals"
		add_child(bullet_decals)
		if visuals:
			bullet_decals.setup(self, visuals)

	# Equip weapon logic
	if visuals:
		if data.get("ai_config", {}).get("attack_type", "melee") == "melee":
			visuals.equip_knife("right")
		else:
			# Ranged: Attach dummy gun or specific model if we have one
			# For now, default visuals creates dummy weapon if none attached
			pass

	if "corpse_scene" in data.get("visuals", {}):
		var corpse_path: String = data.visuals.corpse_scene
		if ResourceLoader.exists(corpse_path):
			override_corpse_scene = load(corpse_path)

	# 5. Extract enemy properties for affix name system
	base_name = data.get("name", "Enemy")
	var data_tier: int = data.get("tier", 1)
	if tier == 1 and data_tier > 1:
		tier = data_tier  # Use data tier if not already set (e.g. by sync)

	if "ai_config" in data:
		attack_type = data.ai_config.get("attack_type", "melee")
		can_fly = data.ai_config.get("can_fly", false)

	# 6. Build display name (used for targeting HUD only, no overhead nameplate)
	_build_display_name()
	# DISABLED: Nameplate now shown only in targeting HUD, not overhead
	# _create_nameplate()

	# (group already added above)

	# Register with GameManager.get_core_system("entity") for fast lookups
	var gm2: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm2.get_core_system("gameplay") if gm2 else null
	if gs and gs.entity_registry:
		gs.entity_registry.register_enemy(self)

	# Enforce physics layers
	collision_layer = CollisionLayers.LAYER_ENEMIES
	collision_mask = (
		CollisionLayers.LAYER_WORLD | CollisionLayers.LAYER_PLAYERS | CollisionLayers.LAYER_ENEMIES
	)

	# 10. Setup LOD Component
	_setup_lod()

	# Setup debug visuals (F5 x-ray vision)
	_setup_debug_visuals()

	# 7. Setup Network Synchronization
	_setup_synchronizer()

	# CRITICAL: Ensure enemy is visible at spawn (prevents initial flicker)
	visible = true

	# 7b. Initialize interpolation for remote enemies
	_is_remote = multiplayer.has_multiplayer_peer() and not multiplayer.is_server()
	if _is_remote:
		# Wait one frame for initial network sync before setting interpolation targets
		call_deferred("_initialize_interpolation_targets")

		# SIGNAL HYGIENE: Connect to synchronizer immediately, not deferred
		# Synchronizer is already created in _setup_synchronizer() above
		_connect_to_synchronizer()
	else:
		# CRITICAL FIX: Explicitly disable input processing on server/local authority
		# This prevents spectators (who are authority) from controlling enemies with WASD
		set_process_input(false)
		set_process_unhandled_input(false)

	# 8. Initialize AI update timer with offset for staggering
	_ai_update_timer = _ai_update_offset

	# 9. Validate spawn position (prevent spawning inside geometry)
	spawn_coordinator = EnemySpawnCoordinator.new()
	spawn_coordinator.name = "SpawnCoordinator"
	add_child(spawn_coordinator)
	spawn_coordinator.setup(self)

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		spawn_coordinator.call_deferred("validate_spawn_position")

	# 10. Setup Debug Visuals (via Component)
	# 11. Setup Alert Icon (Client side visual)
	# 12. Create Health Bar (3D overhead bar)
	# FIXED: Use sequential await instead of multiple call_deferred to prevent race conditions
	call_deferred("_initialize_visuals_sequentially")

	# 13. Load global fall death settings
	var gm3: Node = get_node_or_null("/root/GameManager")
	var cfg: Node = gm3.get_core_system("config") if gm3 else null
	if cfg:
		var fall_cfg: Dictionary = cfg.get_value("fall_death", {})
		if not fall_cfg.is_empty():
			_death_y_threshold = fall_cfg.get("death_y_threshold", -50.0)

		# Initial Config Load
		_load_config()
		cfg.config_reloaded.connect(_load_config)

	# Listen for debug toggle
	if gs and gs.match_service:
		gs.match_service.debug_vision_toggled.connect(_on_debug_vision_toggled)


func _load_config(_file_path: String = "") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var cfg: Node = gm.get_core_system("config") if gm else null
	if not cfg:
		return

	# Load base enemy config
	# merged with specific enemy_id config
	var enemies_cfg: Dictionary = cfg.get_value("enemies", {})
	if enemies_cfg.has(enemy_id):
		configure(enemies_cfg[enemy_id])

	# Override with balance settings if present
	var balance: Dictionary = cfg.get_value("balance.enemies", {})
	if balance.has(enemy_id):
		configure(balance[enemy_id])


func configure(data: Dictionary) -> void:
	if data.has("health"):
		max_health = data.health
		if health_component:
			health_component.max_health = float(max_health)
			health_component.current_health = float(max_health)

	if data.has("damage") and combat_component:
		combat_component.attack_damage = data.damage

	if data.has("speed") and movement_component:
		movement_component.speed = data.speed

	if data.has("attack_range") and combat_component:
		combat_component.attack_range = data.attack_range

	if data.has("detection_radius") and perception_component:
		perception_component.detection_radius = data.detection_radius

	# Visual scaling
	if data.has("scale"):
		var s: float = data.scale
		scale = Vector3(s, s, s)

	_apply_tier_stat_floor()


func _apply_tier_stat_floor() -> void:
	if not health_component:
		return
	var health_floor: float = _get_tier_health_floor(tier)
	if health_floor <= 0.0:
		return
	if health_component.max_health < health_floor:
		health_component.max_health = health_floor
		health_component.current_health = max(health_component.current_health, health_floor)
		max_health = health_component.max_health
		health = health_component.current_health


func _get_tier_health_floor(tier_value: int) -> float:
	if tier_value < 2:
		return 0.0

	var fallback: Dictionary = {2: 75.0, 3: 150.0, 4: 300.0}
	var gm: Node = get_node_or_null("/root/GameManager")
	var cfg: Node = gm.get_core_system("config") if gm else null
	if cfg:
		var configured: Variant = cfg.get_value(
			"ai_combat.tier_system.tier_%d.health_max" % tier_value,
			fallback.get(tier_value, 0.0)
		)
		return float(configured)

	return fallback.get(tier_value, 0.0)


## Deferred initialization of visual helpers.
func _initialize_visuals_sequentially() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not debug_visuals:
		_setup_debug_visuals()
	if not _alert_icon:
		_create_alert_icon()
	if not health_bar:
		_create_health_bar()


func _setup_debug_visuals() -> void:
	if debug_visuals:
		return
	var script: Script = load("res://game/entities/enemies/components/enemy_debug_visuals.gd")
	if script:
		debug_visuals = script.new()
		debug_visuals.name = "DebugVisuals"
		add_child(debug_visuals)
		debug_visuals.setup(self)


# Using preload to ensure script resolution without relying on global class cache


func _setup_lod() -> void:
	var lod_script: Script = load("res://game/scripts/features/performance/lod_component.gd")
	if not lod_script:
		return

	var lod: Node = lod_script.new()
	lod.name = "LODComponent"
	add_child(lod)

	# Configure distances (could be data-driven later)
	lod.distance_medium = 15.0
	lod.distance_low = 35.0
	lod.distance_cull = 60.0  # relatively close for testing, maybe 60-80 normally

	# We want signal-based control for AI/Physics, not hard process disabling by the component
	# to avoid network sync issues.
	lod.optimize_process = false
	lod.optimize_physics = false
	lod.optimize_visibility = false  # We handle visibility separately (server-side only)

	# Enable Frustum Culling
	# This ensures we throttle AI updates even if close but looking away
	lod.use_frustum_culling = true
	# Give some margin for shadow casting / tall enemies
	lod.frustum_margin = Vector3(1.5, 2.0, 1.5)

	lod.lod_changed.connect(_on_lod_changed)

	# Initial update
	_on_lod_changed(0)  # LODLevel.HIGH (0)


func _on_lod_changed(level: int) -> void:
	# Network Optimization: Throttle replication spread based on LOD
	# We attempt to find the synchronizer if not cached (lazy load as it might be added at runtime)
	if not _synchronizer:
		_synchronizer = get_node_or_null("MultiplayerSynchronizer")
		# If named differently in some prefabs, try finding by type (slower, but one-off)
		if not _synchronizer:
			for child: Node in get_children():
				if child is MultiplayerSynchronizer:
					_synchronizer = child
					break

	if _synchronizer:
		match level:
			0:  # HIGH
				_synchronizer.replication_interval = 0.0  # Server tick rate (default)
			1:  # MEDIUM
				_synchronizer.replication_interval = 0.05  # 20 Hz
			2:  # LOW
				_synchronizer.replication_interval = 0.1  # 10 Hz
			3:  # CULL
				_synchronizer.replication_interval = 0.5  # 2 Hz - very sparse

	# Adjust AI update rate based on LOD
	match level:
		0:  # HIGH
			set_ai_update_rate(1.0)
			set_update_offset(randf_range(0.0, 0.1))
		1:  # MEDIUM
			set_ai_update_rate(0.5)  # 30hz effective
			set_update_offset(randf_range(0.0, 0.2))
		2:  # LOW
			set_ai_update_rate(0.2)  # 12hz effective
			set_update_offset(randf_range(0.0, 0.5))
		3:  # CULL
			set_ai_update_rate(0.1)  # 6hz minimal
			# Don't disable completely as we might be just off-screen

	if visual_effects_component and visual_effects_component.has_method("set_lod_level"):
		visual_effects_component.set_lod_level(level)


## Callback for MatchService debug vision toggle


func _on_debug_vision_toggled(enabled: bool) -> void:
	if debug_visuals:
		debug_visuals.toggle_debug(enabled)


# Note: Debug visuals moved to EnemyDebugVisuals component


## AI State Name (Replicated for HUD)
func _create_debug_particles() -> void:
	if visual_effects_component:
		visual_effects_component.create_debug_particles()


func _physics_process(delta: float) -> void:
	# Remote enemies (clients): Use interpolation instead of physics
	if _is_remote:
		_interpolate_remote_enemy(delta)
		# NOTE: Clients do NOT update visibility - they receive synced value from server
		# to prevent flickering from client/server visibility conflicts
		return

	# Server-side: Normal physics and AI
	if not is_on_floor():
		# CRITICAL FIX: Apply gravity correctly
		# get_gravity() returns a Vector3 with NEGATIVE Y (e.g. Vector3(0, -9.8, 0))
		# We ADD the gravity vector (which is already negative) to velocity
		# This makes velocity.y decrease (become more negative), causing falling
		var gravity_vec: Vector3 = get_gravity()
		velocity += gravity_vec * delta

		# Debug: Print gravity to verify it's correct
		if OS.is_debug_build() and randf() < 0.01:  # Print 1% of frames
			var gm: Node = get_node_or_null("/root/GameManager")
			var logger: Node = gm.get_core_system("logger") if gm else null
			if logger:
				logger.info(
					"[Enemy] Gravity: %s velocity.y: %s" % [gravity_vec, velocity.y], "Enemy"
				)
	else:
		# Reset vertical velocity when on ground
		if velocity.y < 0:
			velocity.y = 0.0

	# Void Kill Check (Fall Death) - check BEFORE move_and_slide
	if global_position.y < _death_y_threshold:
		if not is_dead:  # Prevent spam
			_die_from_void()
			return

	# Pain damping/friction
	if Time.get_unix_time_from_system() < pain_debounce_time:
		velocity.x *= 0.8
		velocity.z *= 0.8

	# MovementComponent sets velocity x/z
	move_and_slide()

	# Position sanity check - detect NaN/Inf/extreme values that cause disappearance
	if not _validate_position():
		return  # Position was invalid, enemy will be recovered or killed

	# Update visibility on server
	_update_visibility()

	# Periodic stuck-in-geometry detection (prevents clipping)
	if spawn_coordinator:
		spawn_coordinator.check_stuck_in_geometry(delta)

	# Server-side Debug State Update (or Singleplayer)
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if is_server_or_sp and ai_controller and ai_controller.current_state:
		# Only update if changed to minimize bandwidth (though string sync is usually reliable-ish)
		if debug_state_name != ai_controller.current_state.name:
			debug_state_name = ai_controller.current_state.name


func _process(_delta: float) -> void:
	# AI only runs on server (clients use interpolation)
	if _is_remote:
		return  # Clients don't run AI logic

	# Update visual indicators locally (eye glint, debug overlays)
	# This should run for the local player in any mode (single-player or multiplayer)
	# _update_visual_indicators()
	# -> Moved to EnemyDebugVisuals component which has its own process logic


## Update enemy visibility based on health and death state
## OPTIMIZATION: Only on server, synced to clients via sync_visible property


func _update_visibility() -> void:
	# CRITICAL FIX: Only server manages visibility
	# Clients receive visibility via sync_visible property
	if _is_remote:
		return

	# CRITICAL FIX: Do NOT hide enemies when dead!
	# Death animations and ragdolls need the enemy to be visible
	# The enemy will be removed via queue_free() after ragdoll spawns
	# Hiding here causes enemies to disappear before death animation/ragdoll

	# Keep enemy visible at all times - removal is handled by death system
	if not visible:
		visible = true
		sync_visible = true


func _die_from_void() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger and logger.has_method("info"):
		logger.info("[Enemy] %s fell into the void" % name, "Enemy")
	# Force kill instantly
	if health_component:
		health_component.current_health = 0.0
		# Use public API for death
		health_component.die(0)  # 0 = environment/void
	else:
		queue_free()  # Fallback for components missing


## Validate position is sane (no NaN/Inf/extreme values)
## Returns false if position was invalid and recovery was attempted


func _validate_position() -> bool:
	var pos: Vector3 = global_position

	# Check for NaN
	if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
		_log_error("[Enemy %s] Position is NaN! Attempting recovery." % name)
		_recover_from_invalid_position("NaN")
		return false

	# Check for Infinity
	if is_inf(pos.x) or is_inf(pos.y) or is_inf(pos.z):
		_log_error("[Enemy %s] Position is Infinite! Attempting recovery." % name)
		_recover_from_invalid_position("Infinity")
		return false

	# Check for extreme values (outside playable area)
	const POSITION_LIMIT: float = 5000.0
	if absf(pos.x) > POSITION_LIMIT or absf(pos.y) > POSITION_LIMIT or absf(pos.z) > POSITION_LIMIT:
		# Special handling for swarmlings - they fall off easily, just recycle them
		if enemy_id == "swarmling":
			_handle_swarmling_out_of_bounds()
			return false

		_log_warning(
			(
				"[Enemy %s] Position extreme: (%.1f, %.1f, %.1f) - checking bounds"
				% [name, pos.x, pos.y, pos.z]
			)
		)
		# Don't kill, just log - let spawn coordinator handle stuck detection

	return true


## Attempt to recover enemy from invalid position


func _recover_from_invalid_position(reason: String) -> void:
	# First try: Use last valid position from spawn coordinator
	if spawn_coordinator and "get_last_valid_position" in spawn_coordinator:
		var last_valid: Vector3 = spawn_coordinator.get_last_valid_position()
		if last_valid != Vector3.ZERO:
			global_position = last_valid
			velocity = Vector3.ZERO
			_log(
				(
					"[Enemy %s] Recovered to last valid position: %s (reason: %s)"
					% [name, last_valid, reason]
				)
			)
			return

	# Second try: Find nearest navmesh point
	var nav_map: RID = get_world_3d().navigation_map
	if nav_map.is_valid():
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, Vector3.ZERO)
		if closest != Vector3.ZERO:
			global_position = closest + Vector3(0, 1, 0)
			velocity = Vector3.ZERO
			_log("Enemy %s] Recovered to navmesh origin: %s (reason: %s)" % [name, closest, reason])
			return

	# Last resort: Kill the enemy
	_log_error("[Enemy %s] Could not recover from %s - forcing death" % [name, reason])
	_die_from_void()


## Handle swarmling going out of bounds - silently recycle it
func _handle_swarmling_out_of_bounds() -> void:
	# Swarmlings are disposable minions, just kill them quietly
	# The summoner will track them as dead and can spawn more
	if is_dead:
		return

	# Silent death - no effects, no loot, no stats
	is_dead = true
	set_physics_process(false)
	set_process(false)

	# Hide immediately
	visible = false

	# Queue for deletion
	queue_free()


# _update_visual_indicators logic moved to EnemyDebugVisuals component


func _setup_synchronizer() -> void:
	# Check if we already have a synchronizer (e.g. from scene)
	var synchronizer: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")
	if synchronizer:
		# Scene already has a configured synchronizer
		# Verify it has replication_interval set for optimal performance
		if synchronizer.replication_interval == 0.0:
			synchronizer.replication_interval = 0.033  # 30Hz default
		return

	# No synchronizer in scene, create one programmatically
	synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MultiplayerSynchronizer"
	synchronizer.replication_interval = 0.033  # 30Hz updates
	synchronizer.delta_interval = 0.0  # Always use delta compression
	add_child(synchronizer)

	# Configure replication
	var config: SceneReplicationConfig = SceneReplicationConfig.new()

	# Sync Transform via custom properties (enables smooth client interpolation)
	# CRITICAL: Using sync_position/sync_rotation instead of position/rotation
	# so that the setters trigger and update _target_position for interpolation
	config.add_property(".:sync_position")
	config.add_property(".:sync_rotation")
	config.add_property(".:scale")

	# Sync syncable properties
	config.add_property(".:health")
	config.add_property(".:is_dead")
	config.add_property(".:is_fleeing")
	config.add_property(".:is_in_cover")
	config.add_property(".:display_name")
	config.add_property(".:tier")
	config.add_property(".:debug_state_name")
	config.add_property(".:sync_visible")  # Visibility sync via dedicated property
	# NOTE: Using sync_visible instead of .:visible to avoid infinite toggle loops
	# The setter applies the value to visible on clients

	synchronizer.replication_config = config


func _setup_ai(data: Dictionary) -> void:
	ai_controller = get_node_or_null("EnemyAIController")
	if not ai_controller:
		ai_controller = EnemyAIController.new()
		ai_controller.name = "EnemyAIController"
		add_child(ai_controller)

	# Delegate to EnemyAIFactory (reduces this from 70 lines to 3 lines)
	EnemyAIFactory.create_states(ai_controller, data)
	ai_controller.ensure_initial_state()


func _update_tier_visuals() -> void:
	if visual_effects_component:
		visual_effects_component.update_tier_visuals()


## Smooth interpolation for remote enemies (eliminates choppy movement)


func _interpolate_remote_enemy(delta: float) -> void:
	# Smoothly interpolate to target position
	global_position = global_position.lerp(_target_position, ENEMY_INTERP_SPEED * delta)

	# Smoothly interpolate rotation
	rotation = rotation.lerp(_target_rotation, ENEMY_INTERP_SPEED * delta)


## Initialize interpolation targets after first network sync


func _initialize_interpolation_targets() -> void:
	_target_position = global_position
	_target_rotation = rotation
	sync_position = global_position
	sync_rotation = rotation
	if OS.is_debug_build():
		_log_debug("[Enemy %s] Interpolation targets initialized: pos=%s" % [name, global_position])


## Connect to synchronizer signal
## SIGNAL HYGIENE: Validates synchronizer exists before connecting


func _connect_to_synchronizer() -> void:
	var synchronizer: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")
	if not synchronizer:
		push_error("[Enemy %s] No MultiplayerSynchronizer found - position sync disabled!" % name)
		return

	# Validate synchronizer is properly configured
	if not synchronizer.replication_config:
		push_error("[Enemy %s] MultiplayerSynchronizer has no replication_config!" % name)
		return

	# SIGNAL HYGIENE: Check if already connected before connecting
	if not synchronizer.delta_synchronized.is_connected(_on_properties_synchronized):
		synchronizer.delta_synchronized.connect(_on_properties_synchronized)
		if OS.is_debug_build():
			_log_debug("[Enemy %s] Connected to delta_synchronized" % name)


## Update interpolation targets when server sends position updates
## CRITICAL: Without this, clients interpolate to stale positions causing flickering


func _on_properties_synchronized() -> void:
	if not _is_remote:
		return

	# Only update other properties here if needed.
	# Position and Rotation are now handled via sync_position/sync_rotation setters.


## Get network diagnostics for debugging


func get_network_diagnostics() -> Dictionary:
	return {
		"is_remote": _is_remote,
		"is_server": multiplayer.is_server() if multiplayer.has_multiplayer_peer() else true,
		"visible": visible,
		"health": health,
		"is_dead": is_dead,
		"position": global_position,
		"target_position": _target_position,
		"has_synchronizer": has_node("MultiplayerSynchronizer"),
		"display_name": display_name
	}


func take_damage(
	info_or_damage: Variant,
	source_id_or_hit_pos: Variant = 0,
	dir: Vector3 = Vector3.ZERO,
	knockback: float = 1.0,
	_damage_mod: String = "bullet",
	attacker: Node3D = null
) -> void:
	## Modified signature to support both Legacy and Quake2 args
	# Only process damage on server
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Delegate to component
	if damage_handler:
		damage_handler.handle_damage(
			info_or_damage, source_id_or_hit_pos, dir, knockback, _damage_mod, attacker
		)


func _on_pain_triggered(damage: float, source: Node3D) -> void:
	## Called when pain triggers - apply knockback and interrupt
	# Calculate and apply knockback
	if source and pain_system:
		var knockback: Vector3 = pain_system.calculate_knockback_velocity(
			damage, global_position, source.global_position
		)
		velocity = knockback

	# Interrupt current AI state (optional - can add pain state)
	if ai_controller and ai_controller.has_method("interrupt_for_pain"):
		ai_controller.interrupt_for_pain()

	# Visual feedback (flash red, play animation, etc.)
	if behavior_coordinator:
		if multiplayer.has_multiplayer_peer():
			behavior_coordinator.play_pain_feedback.rpc()
		else:
			behavior_coordinator.play_pain_feedback()


@rpc("authority", "call_local", "unreliable")
func sync_blood_hit(
	hit_pos: Vector3, bullet_dir: Vector3, damage: int, normal: Vector3 = Vector3.UP
) -> void:
	## Sync blood hit effect to all clients using new Quake 2 BloodSpray
	## Sync blood hit effect to all clients
	var vel: Vector3 = Vector3.ZERO
	var spray_dir: Vector3 = normal

	# Try to use component first for full features (decals, physics, generic particles)
	if blood_hit_spawner:
		# Use velocity based on bullet direction (if provided)
		if bullet_dir != Vector3.ZERO:
			vel = bullet_dir * 10.0  # Arbitrary speed for inheritance
		# We use the normal for direction, but spawner also takes velocity
		blood_hit_spawner.spawn_blood(hit_pos, normal, damage, vel)
		return

	# Fallback to simple sprite spray
	# Direction: usually opposite to bullet (back spray) or along normal
	if bullet_dir != Vector3.ZERO:
		# Some randomize
		spray_dir = (normal + (-bullet_dir.normalized() * 0.5)).normalized()

	var blood_script: Script = load("res://game/entities/effects/blood_spray.gd")
	if blood_script:
		blood_script.spawn(hit_pos, spray_dir, damage * 0.1, normal)


@rpc("authority", "call_local", "reliable")
func sync_spawn_ragdoll(
	impact_dir: Vector3, force: float, spin_force: Vector3 = Vector3.ZERO
) -> void:
	_log("[Enemy] sync_spawn_ragdoll: %s at %s" % [name, global_position])
	_log("  - Impact dir: %s Force: %s" % [impact_dir, force])

	# CRITICAL: Unregister from GameManager.get_core_system("entity") FIRST (fixes minimap cleanup)
	# This ensures enemy disappears from minimap/compass immediately
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	if gs and gs.entity_registry:
		gs.entity_registry.unregister_enemy(self)

	# Use mannequin ragdoll for realistic physics
	var ragdoll_scene: PackedScene = load("res://game/entities/common/mannequin_ragdoll.tscn")
	if not ragdoll_scene:
		_log("[Enemy] ERROR: Failed to load mannequin_ragdoll.tscn")
		push_error("[Enemy] Failed to load mannequin_ragdoll.tscn")
		queue_free()
		return

	var ragdoll: Node3D = ragdoll_scene.instantiate()
	ragdoll.position = global_position
	ragdoll.rotation = global_rotation

	# Add to tree
	get_parent().add_child(ragdoll)
	_log("[Enemy] Ragdoll added to scene tree at %s" % ragdoll.global_position)

	# Set ragdoll color to match enemy
	if ragdoll.has_method("set_color") and visuals:
		ragdoll.set_color(visuals.character_color)
		_log("[Enemy] Ragdoll color set to %s" % visuals.character_color)

	# Apply death impulse with realistic physics
	# FIXED: Apply impulse immediately after ragdoll is added to tree (no call_deferred)
	# This ensures immediate response (<0.02s) as per bugfix requirements 2.1, 2.3
	if ragdoll.has_method("apply_death_impulse") and ragdoll.is_inside_tree():
		ragdoll.apply_death_impulse(impact_dir, force, spin_force)
		_log("[Enemy] Ragdoll impulse applied immediately")
	else:
		if not ragdoll.has_method("apply_death_impulse"):
			_log("[Enemy] WARNING: Ragdoll missing apply_death_impulse method")
		elif not ragdoll.is_inside_tree():
			_log("[Enemy] WARNING: Ragdoll not in tree, cannot apply impulse")

	# Remove the entity itself
	queue_free()
	_log("[Enemy] Enemy queued for removal")


func _deferred_death_cleanup() -> void:
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		queue_free()


## Set AI update rate for performance optimization
## Called by performance service


func set_ai_update_rate(rate: float) -> void:
	_ai_update_rate = clamp(rate, 0.1, 1.0)


## Set AI update offset for staggered updates
## Called by performance service


func set_update_offset(offset: float) -> void:
	_ai_update_offset = offset
	_ai_update_timer = offset


## Check if AI should update this frame based on throttle rate


func should_update_ai(delta: float) -> bool:
	if _ai_update_rate >= 1.0:
		return true  # Full rate, always update

	_ai_update_timer += delta
	var update_interval: float = 1.0 / (60.0 * _ai_update_rate)  # Target 60 FPS base

	if _ai_update_timer >= update_interval:
		_ai_update_timer -= update_interval
		return true

	return false


# ============================================================================
# Diablo-style Affix Name System
# ============================================================================

## Build the full display name from tier, modifiers, attack type, and base name


func _build_display_name() -> void:
	var parts: Array[String] = []

	# 1. Tier prefix (Elite/Boss)
	var tier_key: String = TIER_PREFIXES.get(tier, "")
	if tier_key != "":
		# Use GameManager.get_core_system("localization") for translation
		var gm: Node = get_node_or_null("/root/GameManager")
		var localization: Node = gm.get_core_system("localization") if gm else null
		if localization:
			parts.append(localization.translate(tier_key))
		else:
			parts.append(tier_key)

	# 2. Modifier prefixes
	for mod in applied_modifiers:
		if mod.prefix != "":
			parts.append(mod.prefix)

	# 3. Attack type descriptor - skipped for simplicity

	# 4. Base name
	var gm2: Node = get_node_or_null("/root/GameManager")
	var localization2: Node = gm2.get_core_system("localization") if gm2 else null
	if localization2:
		parts.append(localization2.translate(base_name))
	else:
		parts.append(base_name)

	# Combine all parts
	display_name = " ".join(parts)

	# Update nameplate if exists
	_update_nameplate()


## Create billboard Label3D as nameplate above enemy
# Disabled per user request (moved to HUD)


func _create_nameplate() -> void:
	return


## Update nameplate text and color
func _update_nameplate() -> void:
	if not nameplate:
		return


## Create 3D health bar above enemy
func _create_health_bar() -> void:
	if health_bar:
		return  # Already exists

	health_bar = EnemyHealthBar.new()
	health_bar.name = "HealthBar"
	add_child(health_bar)

	# Initial update with current health
	if health_component:
		health_bar.update_health(health_component.current_health, health_component.max_health)

	health_bar.visible = false  # Default hidden until damaged or targeted


## Handle health change signal - update health bar


func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.update_health(current, max_val)
		# Show health bar if damaged (and not already dead)
		if current < max_val and current > 0:
			_update_health_bar_visibility()


## Get the full Diablo-style display name


func get_display_name() -> String:
	return display_name


## Apply a modifier (affix) to this enemy


func apply_modifier(mod: EnemyModifier) -> void:
	if not mod:
		return

	applied_modifiers.append(mod)
	mod.apply_to(self)

	# Rebuild name with new modifier
	_build_display_name()


## Apply stat multiplier (called by EnemyModifier.apply_to)


func apply_stat_multiplier(stat_name: String, multiplier: float) -> void:
	match stat_name:
		"health":
			if health_component:
				health_component.max_health *= multiplier
				health_component.current_health = health_component.max_health
		"damage":
			if combat_component:
				combat_component.attack_damage *= multiplier
		"speed":
			if movement_component:
				movement_component.speed *= multiplier
		"scale":
			scale *= multiplier
			# Adjust nameplate position when scaling
			if nameplate:
				nameplate.position.y *= multiplier


func _create_alert_icon() -> void:
	_alert_icon = Label3D.new()
	_alert_icon.name = "AlertIcon"
	_alert_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_icon.pixel_size = 0.01  # Smaller (was 0.015)
	_alert_icon.font_size = 128
	_alert_icon.outline_size = 12
	_alert_icon.position = Vector3(0, 3.0, 0)  # Higher (was 2.5)
	_alert_icon.visible = false
	_alert_icon.no_depth_test = true  # Always visible on top
	_alert_icon.modulate = Color(1.0, 0.0, 0.0)  # Red
	add_child(_alert_icon)


func _on_target_spotted(target: Node3D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	is_aggro = true

	# Only notify the target client
	if target.is_in_group("player"):
		if multiplayer.has_multiplayer_peer():
			_client_show_alert.rpc_id(target.name.to_int(), "spotted")
		else:
			_client_show_alert("spotted")


func _on_target_lost(target: Node3D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	is_aggro = false

	# Only notify the target client
	if target.is_in_group("player"):
		if multiplayer.has_multiplayer_peer():
			_client_show_alert.rpc_id(target.name.to_int(), "lost")
		else:
			_client_show_alert("lost")


@rpc("authority", "call_local", "reliable")
func _client_show_alert(type: String) -> void:
	if not _alert_icon:
		return

	_alert_icon.visible = true
	_alert_icon.modulate.a = 1.0

	if type == "spotted":
		_alert_icon.text = "!"
		_alert_icon.modulate = Color(1.0, 0.0, 0.0)  # Red

		# Animate pop
		var tween: Tween = create_tween()
		_alert_icon.scale = Vector3.ZERO
		(
			tween
			. tween_property(_alert_icon, "scale", Vector3.ONE, 0.3)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)

		# Fade out after a few seconds
		tween.tween_property(_alert_icon, "modulate:a", 0.0, 0.5).set_delay(2.0)
		tween.tween_callback(
			func() -> void:
				if is_instance_valid(_alert_icon):
					_alert_icon.visible = false
		)

	elif type == "lost":
		_alert_icon.text = "?"
		_alert_icon.modulate = Color(1.0, 0.2, 0.2)  # Light Red

		# Animate pop
		var tween: Tween = create_tween()
		_alert_icon.scale = Vector3.ZERO
		(
			tween
			. tween_property(_alert_icon, "scale", Vector3.ONE, 0.3)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)

		# Fade out faster
		tween.tween_property(_alert_icon, "modulate:a", 0.0, 0.5).set_delay(1.5)
		tween.tween_callback(
			func() -> void:
				if is_instance_valid(_alert_icon):
					_alert_icon.visible = false
		)


func set_targeted(targeted: bool) -> void:
	if is_targeted != targeted:
		is_targeted = targeted
		_update_health_bar_visibility()


func _update_health_bar_visibility() -> void:
	if not health_bar:
		return

	var should_show: bool = false
	# Show if targeted
	if is_targeted:
		should_show = true
	# Show if damaged
	elif (
		health_component
		and health_component.current_health < health_component.max_health
		and health_component.current_health > 0
	):
		should_show = true

	health_bar.visible = should_show
