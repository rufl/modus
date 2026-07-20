## Player - Central Entity for Human and AI Controllable Characters
##
## This script acts as a mediator and data container. Most logic is delegated
## to specialized components (MovementComponent, WeaponManager, etc.)
## which are instantiated and wired by PlayerComponentFactory.
## Supports:
## - Full Authority (Local Player) with Client-Side Prediction
## - Remote (Other Players) with Entity Interpolation
## - Modifiable via Data-Driven Configuration (JSON5)

class_name Player
extends CharacterBody3D

signal ammo_changed(current: int, reserve: int, weapon: String)
signal reload_started(duration: float)
signal reload_finished

const COMBAT_SERVICE_SCRIPT = preload("res://game/scripts/features/combat/combat_service.gd")
const SPECTATOR_SCENE: PackedScene = preload("res://game/scenes/entities/spectator.tscn")
const RAGDOLL_SCENE: PackedScene = preload("res://game/entities/common/mannequin_ragdoll.tscn")
const GlobalEnums = preload("res://game/core/enums.gd")

# Constants for Magic Numbers
const FALL_DEATH_Y_THRESHOLD: float = -50.0
const FADE_START_DISTANCE: float = 0.3
const FADE_END_DISTANCE: float = 0.15
const DEFAULT_RESPAWN_TIME: float = 5.0
const DEFAULT_AFK_THRESHOLD: float = 30.0
const DEFAULT_STATUS_UPDATE_INTERVAL: float = 1.0
const DEFAULT_BASE_HEALTH: float = 100.0

@export var max_health: int = 100
@export var max_armor: int = 200
@export var spawns: PackedVector3Array = [Vector3(0, 2, 0)]
@export var standing_camera_height: float = 1.75
@export var crouching_camera_height: float = 1.0
@export var crouch_transition_speed: float = 10.0

var respawn_time: float = 5.0
var health: float:
	get:
		return health_component.current_health if health_component else 0.0
	set(value):
		if health_component:
			health_component.current_health = value
var armor: float:
	get:
		return health_component.current_armor if health_component else 0.0
	set(value):
		if health_component:
			health_component.current_armor = value
var current_ammo: int:
	get:
		if weapon_manager:
			var ammo: Array = weapon_manager.get_current_ammo()
			return ammo[0] if ammo.size() > 0 else 0
		return 0
var reserve_ammo: int:
	get:
		if weapon_manager:
			var ammo: Array = weapon_manager.get_current_ammo()
			return ammo[1] if ammo.size() > 1 else 0
		return 0
var weapon_name: String:
	get:
		if weapon_manager:
			var weapon: WeaponData = weapon_manager.get_current_weapon()
			return weapon.weapon_name if weapon else ""
		return ""
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var can_fly: bool = false
var noclip: bool = false
var is_invisible: bool = false
var has_double_jump: bool = false
var has_dodge: bool = false
var jump_count: int = 0
var state_manager: Node = null  # PlayerStateManager
var is_dead: bool:
	get:
		return health_component.is_dead if health_component else false
var is_downed: bool:
	get:
		return downed_handler.is_downed if downed_handler else false
var move_speed: float:
	get:
		return movement_component.speed if movement_component else 5.0
var health_component: HealthComponent = null
var weapon_manager: WeaponManager = null
var dodge_system: DodgeSystem = null
var screen_shake: ScreenShakeSystem = null
var blood_overlay: Control = null  # BloodOverlay for red screen flash
var rocket_jump_system: RocketJumpSystem = null
var advanced_movement: Node = null
var skill_manager: SkillTreeManager = null
var progression: PlayerProgression = null
var passive_effects: PassiveEffects = null
var targeting_system: TargetingSystem = null
var status_effect_manager: StatusEffectManager = null
var input_component: Node = null
var interaction_component: Node = null
var movement_component: Node = null
var blood_hit_spawner: BloodHitSpawner = null
var network_sync: Node = null
var hud_bridge: Node = null
var persistence_component: Node = null
var camera_component: Node = null
var animation_component: Node = null
var status_component: Node = null
var combat_component: Node = null
var last_hit_dir: Vector3 = Vector3.BACK
var is_crouching: bool = false
var is_sprinting: bool = false
var is_swimming: bool = false
var rope_movement: Node = null
var is_climbing: bool:
	get:
		return rope_movement.is_climbing if rope_movement else false

# Public vars accessed by factory and components
var is_remote_player: bool = false
var match_service: Node = null
var fall_checker: FallDeathChecker = null

@onready var visuals: SkeletalCharacterVisuals = $PlayerVisuals
@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var weapon_holder: Node3D = $Camera3D/WeaponHolder
@onready var damage_indicator: Control = $HUDLayer/DamageIndicatorManager
@onready var gunshot_sound: AudioStreamPlayer3D = %GunshotSound
@onready var downed_handler: DownedStateHandler = $DownedHandler

# Animation player accessor - delegates to visuals
var anim_player: AnimationPlayer:
	get:
		return visuals.anim_player if visuals else null

var _player_service: Node = null
var _effects_service: Node = null
var _target_position: Vector3 = Vector3.ZERO:
	set(value):
		_target_position = value
var _target_rotation_y: float = 0.0:
	set(value):
		_target_rotation_y = value
var _target_camera_rotation_x: float = 0.0:
	set(value):
		_target_camera_rotation_x = value
var _melee_cooldown: float = 0.0
var _last_weapon_index: int = 0
var _pending_look_delta: Vector2 = Vector2.ZERO


func _enter_tree() -> void:
	var peer_id: int = str(name).to_int()
	if peer_id != 0:
		set_multiplayer_authority(peer_id)

	add_to_group("player")


func _exit_tree() -> void:
	# Unsubscribe from GameManager events
	if not get_node_or_null("ProgressionBridge"):
		GameManager.unsubscribe("enemy_died", on_enemy_killed_event)

	# Config signals
	var cfg: Node = GameManager.get_core_system("config")
	if cfg:
		if cfg.config_reloaded.is_connected(_load_config):
			cfg.config_reloaded.disconnect(_load_config)
		if cfg.config_reloaded.is_connected(_configure_from_config):
			cfg.config_reloaded.disconnect(_configure_from_config)

	# Match Service signals
	if match_service:
		if match_service.match_state_changed.is_connected(_on_match_state_changed):
			match_service.match_state_changed.disconnect(_on_match_state_changed)

	# Unregister from entity registry
	var peer_id: int = name.to_int()
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.entity_registry:
		gs.entity_registry.unregister_player(peer_id)


func _ready() -> void:
	# Determine multiplayer authority early
	var has_peer: bool = multiplayer.has_multiplayer_peer()
	var is_auth: bool = is_multiplayer_authority()
	is_remote_player = has_peer and not is_auth

	# Determine if this is a local player (authority in multiplayer, or single-player)
	# In single-player (no peer), we ARE the local player
	var is_local_player: bool = not has_peer or is_auth

	# Load configuration values (does NOT initialize components)
	_load_config()

	# Connect config reload signal
	var cfg: Node = GameManager.get_core_system("config")
	if cfg and cfg.has_signal("config_reloaded"):
		cfg.config_reloaded.connect(_load_config)

	# SETUP NETWORK SYNC (required for all players)
	PlayerComponentFactory.setup_network_sync(self)

	# Initialize interpolation targets for remote players
	if is_remote_player:
		_target_position = global_position
		_target_rotation_y = rotation.y
		if camera:
			_target_camera_rotation_x = camera.rotation.x

	# Register with entity registry
	var peer_id: int = name.to_int()
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.entity_registry:
		gs.entity_registry.register_player(peer_id, self)

	# Service Injection
	match_service = gs.match_service if gs else null
	_player_service = gs.player if gs else null
	_effects_service = gs.effects if gs else null

	# Setup components based on player type
	if not is_local_player:
		# Remote player: setup visual sync components only
		PlayerComponentFactory.setup_remote(self)
	else:
		# Local player: setup camera
		camera.current = true
		var listener: AudioListener3D = camera.get_node_or_null("AudioListener3D")
		if listener:
			listener.make_current()

	# Setup state manager (required for all players)
	PlayerComponentFactory.setup_state_manager(self)

	# Setup local components (input, movement, etc.) for local player only
	if is_local_player:
		PlayerComponentFactory.setup_local(self)

	# Configure MultiplayerSynchronizer for 60 Hz tick rate
	var sync: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")
	var has_authority: bool = not has_peer or is_auth
	if sync and has_authority:
		sync.replication_interval = 1.0 / 60.0

	# Initial animation
	if anim_player:
		anim_player.play("Idle")

	# Load additional configs
	_configure_from_config()
	if cfg:
		cfg.config_reloaded.connect(_configure_from_config)

	# Connect match service signals
	if match_service:
		match_service.match_state_changed.connect(_on_match_state_changed)

	# Subscribe to GameManager events (only if no ProgressionBridge handles it)
	if not get_node_or_null("ProgressionBridge"):
		GameManager.subscribe("enemy_died", on_enemy_killed_event)


func _load_config(_file_path: String = "") -> void:
	## Load configuration values only - does NOT initialize components
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		return

	# Load basic config values
	respawn_time = cfg.get_value("game_rules.respawn_time", DEFAULT_RESPAWN_TIME)

	var base_hp: float = cfg.get_value("balance.player.base_health", DEFAULT_BASE_HEALTH)
	max_health = int(base_hp)

	standing_camera_height = cfg.get_value("balance.player.standing_camera_height", 1.75)
	crouching_camera_height = cfg.get_value("balance.player.crouching_camera_height", 1.0)
	crouch_transition_speed = cfg.get_value("balance.player.crouch_transition_speed", 10.0)

	# Configure components if they exist (they may not exist yet during initial _ready)
	if status_component:
		status_component.configure(
			cfg.get_value("game_rules.afk_threshold", DEFAULT_AFK_THRESHOLD),
			DEFAULT_STATUS_UPDATE_INTERVAL
		)

	if health_component:
		health_component.max_health = float(max_health)


func _configure_from_config(_file_path: String = "") -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		return

	var balance: Dictionary = cfg.get_value("balance.player", {})
	if not balance.is_empty():
		max_health = int(balance.get("base_health", max_health))

	var movement_cfg: Dictionary = cfg.get_value("movement", {})
	if not movement_cfg.is_empty():
		if rocket_jump_system and movement_cfg.has("rocket_jump"):
			rocket_jump_system.configure(movement_cfg.rocket_jump)

		if advanced_movement and advanced_movement.has_method("configure"):
			if movement_cfg.has("advanced_movement"):
				advanced_movement.configure(movement_cfg.advanced_movement)

		if dodge_system and movement_cfg.has("dodge"):
			dodge_system.configure(movement_cfg.dodge)

	var status_cfg: Dictionary = cfg.get_value("player_modes.status", {})
	if not status_cfg.is_empty():
		if status_component:
			status_component.configure(
				status_cfg.get("afk_threshold_seconds", DEFAULT_AFK_THRESHOLD),
				status_cfg.get("status_update_interval", DEFAULT_STATUS_UPDATE_INTERVAL)
			)

	if movement_component:
		GameManager.get_core_system("logger").info(
			(
				"[Player] Configured from JSON5: Speed=%.1f, Jump=%.1f"
				% [movement_component.move_speed, movement_component.jump_velocity]
			),
			"Player"
		)

	GameManager.get_core_system("logger").info("[Player] Configuration loaded/reloaded.", "Player")


func trigger_screen_flash(color: Color, duration: float = 0.3) -> void:
	if hud_bridge:
		hud_bridge.trigger_screen_flash(color, duration)


func take_damage(
	info_or_damage: Variant,
	source_id_or_hit_pos: Variant = 0,
	dir: Vector3 = Vector3.ZERO,
	knockback: float = 1.0,
	_damage_mod: String = "bullet",
	attacker: Node3D = null
) -> void:
	## Route damage through health component.
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc

	# Blood effect
	if gs and gs.effects:
		gs.effects.spawn_blood_synced(global_position, last_hit_dir)

	# God Mode check
	if gs and gs.match_service and gs.match_service.is_godmode_active():
		return

	# Parse to DamageInfo
	var final_info: DamageInfo
	if info_or_damage is DamageInfo:
		final_info = info_or_damage
	else:
		final_info = DamageInfo.create(
			float(info_or_damage), DamageInfo.DamageType.GENERIC, attacker
		)
		final_info.knockback_force = knockback
		final_info.knockback_direction = dir

		if typeof(source_id_or_hit_pos) == TYPE_INT:
			final_info.source_id = source_id_or_hit_pos
		elif typeof(source_id_or_hit_pos) == TYPE_VECTOR3:
			final_info.hit_position = source_id_or_hit_pos

		match _damage_mod:
			"fire":
				final_info.damage_type = DamageInfo.DamageType.FIRE
			"explosive":
				final_info.damage_type = DamageInfo.DamageType.EXPLOSIVE
			"melee":
				final_info.damage_type = DamageInfo.DamageType.MELEE

	health_component.take_damage(final_info)


# === INPUT SIGNAL CALLBACKS (public for factory wiring) ===


func on_input_interact_pressed() -> void:
	if is_downed:
		return
	if downed_handler:
		if downed_handler.try_revive_target(camera, get_rid()):
			return
	if interaction_component:
		interaction_component.interact()


func on_input_quick_switch() -> void:
	if weapon_manager:
		var idx: int = weapon_manager.current_weapon_index
		weapon_manager.switch_to_weapon(_last_weapon_index)
		_last_weapon_index = idx


func on_input_weapon_switch(idx: int) -> void:
	if weapon_manager:
		_last_weapon_index = weapon_manager.current_weapon_index
		weapon_manager.switch_to_weapon(idx)
	else:
		push_warning("[Player] No weapon_manager available!")


func on_input_melee_pressed() -> void:
	if weapon_manager:
		weapon_manager.quick_melee()


func _process(_delta: float) -> void:
	# Check authority - in single player (no peer), always process for local player
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if is_local:
		if not is_dead:
			_update_crosshair_target()

			if visuals and visuals.has_method("set_look_pitch"):
				if camera:
					visuals.set_look_pitch(camera.rotation.x)

			if camera and not camera.current:
				GameManager.get_core_system("logger").info(
					(
						"[Player] WARNING: Camera is not current! Rotation: "
						+ " "
						+ str(camera.rotation.x)
					),
					"Player"
				)


func get_command_look_delta() -> Vector2:
	var delta := _pending_look_delta
	_pending_look_delta = Vector2.ZERO
	return delta


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	if _melee_cooldown > 0:
		_melee_cooldown -= delta

	# CLIENT-SIDE PREDICTION & SERVER RECONCILIATION
	var predictor: Node = get_node_or_null("PlayerMovementPredictor")
	if predictor and predictor.has_method("_process"):  # It uses _process for capture and prediction
		# The predictor handles its own movement application and server sync.
		# When using prediction, we skip the legacy physics process.
		if not is_multiplayer_authority():
			_interpolate_remote_player(delta)
		return

	if multiplayer.multiplayer_peer != null and not is_multiplayer_authority():
		_interpolate_remote_player(delta)
		return

	if is_dead:
		return

	if rope_movement and rope_movement.is_active:
		rope_movement.process_physics(delta)
		return

	if input_component:
		if not is_downed:
			var fire_input: Dictionary = input_component.get_fire_input()
			weapon_manager.fire(fire_input.is_pressed, fire_input.just_pressed)

		if input_component.wish_reload and not is_downed:
			weapon_manager.start_reload()
			input_component.wish_reload = false

	if movement_component:
		if input_component:
			is_crouching = input_component.is_crouching
			is_sprinting = input_component.is_sprinting and not is_crouching

		movement_component.process_physics(delta)

	# Update dodge system with current facing direction
	if dodge_system:
		var forward := -global_transform.basis.z
		var right := global_transform.basis.x
		dodge_system.update_directions(forward, right)
		dodge_system.check_input()

	if dodge_system and dodge_system.is_dodging:
		velocity = dodge_system.apply_dodge_movement(velocity)

	if screen_shake:
		screen_shake.apply_shake_to_camera(camera)

	_update_interaction_tooltip()

	move_and_slide()


func on_died(_source_id: int) -> void:
	if state_manager:
		state_manager.enter_downed()


func _melee_attack() -> void:
	if combat_component:
		combat_component.melee_attack()


# Interaction proxies


func _perform_pickup(_obj: RigidBody3D) -> void:
	if interaction_component:
		interaction_component.perform_pickup(_obj)


func has_item(item_id: String) -> bool:
	if interaction_component:
		return interaction_component.has_key(item_id)
	return false


func collect_key(key_id: String) -> void:
	if interaction_component:
		interaction_component.collect_key(key_id)


func _on_match_state_changed(_new_state: int) -> void:
	pass


func _update_crosshair_target() -> void:
	if hud_bridge:
		hud_bridge.update_crosshair_target()


func update_weapon_pose() -> void:
	## Thin proxy - actual logic in PlayerWeaponPoseController.
	var wpc: Node = get_node_or_null("WeaponPoseController")
	if wpc and wpc.has_method("update_pose"):
		wpc.update_pose()


@rpc("any_peer", "call_local", "unreliable")
func _sync_movement_state(_c: bool, _s: bool) -> void:
	# Only remote players should receive this
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if is_local:
		return
	if network_sync:
		network_sync.sync_movement_state(_c, _s)
	else:
		is_crouching = _c
		is_sprinting = _s


func _set_position(value: Vector3) -> void:
	if network_sync:
		network_sync.set_target_position(value)
		return
	if is_remote_player:
		_target_position = value
	else:
		global_position = value


func _set_rotation(value: Vector3) -> void:
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if not is_local:
		if network_sync:
			network_sync.set_target_rotation(value)
		elif is_remote_player:
			_target_rotation_y = value.y
		else:
			rotation = value


func _deferred_mouse_setup() -> void:
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if is_local and not is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameManager.get_core_system("logger").info(
			"[Player] Mouse mode set to CAPTURED (mode=%d)" % Input.mouse_mode, "Player"
		)
		if camera:
			camera.current = true


func _ensure_mouse_captured() -> void:
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if is_local and not is_dead:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			GameManager.get_core_system("logger").debug(
				"[Player] Re-capturing mouse (was reset by something)", "Player"
			)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Signal Handlers (public for factory wiring)


func on_weapon_ammo_changed(curr: int, res: int, w_name: String) -> void:
	ammo_changed.emit(curr, res, w_name)
	GameManager.emit_event(
		"ammo_changed",
		{"entity_id": get_instance_id(), "current": curr, "reserve": res, "weapon_name": w_name}
	)


func on_weapon_reload_started(duration: float) -> void:
	reload_started.emit(duration)
	GameManager.emit_event("reload_started", {"entity_id": get_instance_id(), "duration": duration})


func on_weapon_reload_finished() -> void:
	reload_finished.emit()
	GameManager.emit_event("reload_finished", {"entity_id": get_instance_id()})


func on_weapon_switched(_w_name: String) -> void:
	update_weapon_pose()


func set_available_rope(rope: Node3D, segment: RigidBody3D) -> void:
	if rope_movement:
		rope_movement.set_available_rope(rope, segment)

	if rope_movement:
		rope_movement.clear_available_rope(rope)


func _interpolate_remote_player(delta: float) -> void:
	if network_sync:
		network_sync.process_interpolation(delta)


func _update_interaction_tooltip() -> void:
	if hud_bridge:
		hud_bridge.update_interaction_tooltip()


func on_item_collected(_item_id: String) -> void:
	pass


func on_enemy_killed_event(data: Dictionary) -> void:
	## Fallback handler if no ProgressionBridge component exists.
	var is_local: bool = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	if not is_local:
		return
	var killer_id: int = data.get("killer_id", -1)
	var my_id: int = multiplayer.get_unique_id()
	if killer_id == my_id:
		_handle_enemy_killed(data)


func _handle_enemy_killed(data: Dictionary) -> void:
	var enemy_id: String = data.get("enemy_id", "unknown")
	var is_crit: bool = data.get("is_crit", false)
	var xp_amount: int = 10
	if is_crit:
		xp_amount += 5
	if progression:
		progression.add_xp(xp_amount)
	GameManager.get_core_system("logger").info(
		"[Player] Killed %s! Awarded %d XP" % [enemy_id, xp_amount], "Player"
	)


func _integrate_ui_inputs_deferred(ui_input_integration_script: Script) -> void:
	## Helper to integrate UI inputs with UIInputManager (called deferred)
	if (
		ui_input_integration_script
		and ui_input_integration_script.has_method("integrate_ui_inputs")
	):
		ui_input_integration_script.integrate_ui_inputs()
