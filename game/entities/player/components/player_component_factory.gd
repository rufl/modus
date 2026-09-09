class_name PlayerComponentFactory
extends RefCounted

## Factory for creating and wiring Player components.
## Centralizes all preloads, instantiation, and signal wiring.

# Duplicated from Player to avoid circular class_name dependency
const FADE_START_DISTANCE: float = 0.3
const FADE_END_DISTANCE: float = 0.15
const FALL_DEATH_Y_THRESHOLD: float = -50.0

# --- Preloaded Scripts ---
const StateMgrScript = preload("res://game/entities/player/components/player_state_manager.gd")
const PlayerNetworkSyncScript = preload(
	"res://game/entities/player/components/player_network_sync.gd"
)
const PlayerHUDBridgeScript = preload("res://game/entities/player/components/player_hud_bridge.gd")
const PlayerAnimCompScript = preload(
	"res://game/entities/player/components/player_animation_component.gd"
)
const PlayerStatusCompScript = preload(
	"res://game/entities/player/components/player_status_component.gd"
)
const PlayerCombatCompScript = preload(
	"res://game/entities/player/components/player_combat_component.gd"
)
const FirstPersonBodyShaderScript = preload(
	"res://game/entities/player/components/first_person_body_shader.gd"
)
const InputCompScript = preload("res://game/entities/player/components/player_input_component.gd")
const MCompScript = preload("res://game/entities/player/components/player_movement_component.gd")
const PersistCompScript = preload(
	"res://game/entities/player/components/player_persistence_component.gd"
)
const CamCompScript = preload("res://game/entities/player/components/player_camera_component.gd")
const RopeCompScript = preload("res://game/entities/player/components/rope_movement_component.gd")
const AdvancedMovementScript = preload("res://game/entities/player/advanced_movement.gd")
const WeaponPoseScript = preload(
	"res://game/entities/player/components/player_weapon_pose_controller.gd"
)
const ProgressionBridgeScript = preload(
	"res://game/entities/player/components/player_progression_bridge.gd"
)
const MenuControllerScript = preload(
	"res://game/entities/player/components/player_menu_controller.gd"
)
const RemoteInterpolatorScript = preload("res://game/core/network/remote_entity_interpolator.gd")
const PlayerPredictorScript = preload("res://game/core/network/player_movement_predictor.gd")
const StateMachineScript = preload("res://game/entities/player/components/states/state_machine.gd")
const IdleStateScript = preload("res://game/entities/player/components/states/idle_state.gd")
const WalkStateScript = preload("res://game/entities/player/components/states/walk_state.gd")
const RunStateScript = preload("res://game/entities/player/components/states/run_state.gd")
const JumpStateScript = preload("res://game/entities/player/components/states/jump_state.gd")
const InAirStateScript = preload("res://game/entities/player/components/states/inair_state.gd")
const CrouchStateScript = preload("res://game/entities/player/components/states/crouch_state.gd")
const SlideStateScript = preload("res://game/entities/player/components/states/slide_state.gd")
const DashStateScript = preload("res://game/entities/player/components/states/dash_state.gd")
const WallrunStateScript = preload("res://game/entities/player/components/states/wallrun_state.gd")
const FlyStateScript = preload("res://game/entities/player/components/states/fly_state.gd")


static func setup_network_sync(player: Node) -> void:
	## Create and attach network sync component.
	if PlayerNetworkSyncScript:
		player.network_sync = PlayerNetworkSyncScript.new()
		player.network_sync.name = "NetworkSync"
		player.add_child(player.network_sync)
		player.network_sync.setup(player, player.camera, player.is_remote_player)

	# The server needs the same RPC endpoint as the owning client.
	if player.multiplayer.has_multiplayer_peer() and player.get_multiplayer_authority() != 1:
		var predictor: Node = PlayerPredictorScript.new()
		predictor.name = "PlayerMovementPredictor"
		player.add_child(predictor)


static func setup_state_manager(player: Node) -> void:
	## Create and attach player state manager.
	player.state_manager = StateMgrScript.new()
	player.state_manager.name = "StateManager"
	player.add_child(player.state_manager)
	_setup_health(player)
	_setup_status_effects(player)
	player.state_manager.setup(player, player.health_component, player.match_service)


static func setup_remote(player: Node) -> void:
	## Setup components for remote (non-authority) players.

	# Weapon Manager (needed for visual sync)
	player.weapon_manager = WeaponManager.new()
	player.weapon_manager.name = "WeaponManager"
	player.add_child(player.weapon_manager)
	player.weapon_manager.setup(player, player.camera, player.weapon_holder, player.gunshot_sound)

	# Skeletal Visuals
	if player.visuals:
		player.visuals.character_color = Color(0.5, 0.5, 0.9)

	# Animation Component
	if PlayerAnimCompScript:
		player.animation_component = PlayerAnimCompScript.new()
		player.animation_component.name = "AnimationComponent"
		player.add_child(player.animation_component)
		player.animation_component.setup(player)

	# Combat Component (needed for visuals/effects)
	if PlayerCombatCompScript:
		player.combat_component = PlayerCombatCompScript.new()
		player.combat_component.name = "CombatComponent"
		player.add_child(player.combat_component)
		player.combat_component.setup(
			player,
			player.health_component,
			player.match_service,
			player.screen_shake,
			player.blood_hit_spawner,
			player.hud_bridge,
			player.anim_player,
			player.camera
		)

	# Remote Interpolation (smooths other players)
	if RemoteInterpolatorScript:
		var interpolator: Node = RemoteInterpolatorScript.new()
		interpolator.name = "RemoteInterpolator"
		player.add_child(interpolator)


static func setup_local(player: Node) -> void:
	## Setup all components for local (authority) player.
	_setup_weapon_manager(player)
	_setup_visuals(player)
	_setup_movement_systems(player)
	_setup_hud(player)
	_setup_animation(player)
	_setup_status_component(player)
	_setup_combat_component(player)
	_setup_rope(player)
	_setup_blood(player)
	_setup_advanced_movement(player)
	_setup_fall_checker(player)
	_setup_progression(player)
	_setup_input(player)
	_setup_interaction(player)
	_setup_movement_state_machine(player)
	_setup_movement_component(player)
	_setup_persistence(player)
	_setup_camera(player)
	_setup_weapon_pose(player)
	_setup_menu_controller(player)
	_setup_progression_bridge(player)
	_connect_input_signals(player)
	_setup_extended_hud(player)
	_setup_targeting(player)

	# Integrate UI inputs with UIInputManager
	var ui_input_integration_script := preload("res://game/scripts/core/ui_input_integration.gd")
	if ui_input_integration_script:
		player.call_deferred("_integrate_ui_inputs_deferred", ui_input_integration_script)


# --- Private Setup Helpers ---


static func _setup_weapon_manager(player: Node) -> void:
	player.weapon_manager = WeaponManager.new()
	player.weapon_manager.name = "WeaponManager"
	player.add_child(player.weapon_manager)
	player.weapon_manager.setup(player, player.camera, player.weapon_holder, player.gunshot_sound)

	# Connect weapon signals
	player.weapon_manager.ammo_changed.connect(player.on_weapon_ammo_changed)
	player.weapon_manager.reload_started.connect(player.on_weapon_reload_started)
	player.weapon_manager.reload_finished.connect(player.on_weapon_reload_finished)
	player.weapon_manager.weapon_switched.connect(player.on_weapon_switched)

	# Set initial weapon pose
	player.call_deferred("update_weapon_pose")


static func _setup_visuals(player: Node) -> void:
	if not player.visuals:
		return

	player.visuals.character_color = Color(0.5, 0.5, 0.9)
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(
			(
				"[Player] Set local player character color to: "
				+ " "
				+ str(player.visuals.character_color)
			),
			"Player"
		)
	player.visuals.visible = true

	# Setup first-person body shader (GTA V technique)
	var fp_shader: Node = FirstPersonBodyShaderScript.new()
	fp_shader.name = "FirstPersonBodyShader"
	player.add_child(fp_shader)
	if fp_shader.has_method("setup"):
		fp_shader.setup(player.camera, player.visuals, player)

	fp_shader.set_fade_distances(FADE_START_DISTANCE, FADE_END_DISTANCE)

	# Attach WeaponHolder to Mannequin Hand for True FPS
	if player.weapon_holder:
		player.visuals.attach_weapon_node(player.weapon_holder, "right")


static func _setup_health(player: Node) -> void:
	player.health_component = HealthComponent.new()
	player.health_component.name = "HealthComponent"
	player.health_component.max_health = float(player.max_health)
	player.health_component.max_armor = float(player.max_armor)
	player.health_component.current_health = float(player.max_health)
	player.health_component.current_armor = 0.0
	player.add_child(player.health_component)

	player.health_component.died.connect(player.on_died)

	# Connect DownedHandler signals
	if player.downed_handler:
		player.downed_handler.revived.connect(player.state_manager.revive)
		player.downed_handler.bleedout_expired.connect(player.state_manager.bleedout)


static func _setup_status_effects(player: Node) -> void:
	player.status_effect_manager = StatusEffectManager.new()
	player.status_effect_manager.name = "StatusEffectManager"
	player.add_child(player.status_effect_manager)


static func _setup_movement_systems(player: Node) -> void:
	player.dodge_system = DodgeSystem.new()
	player.add_child(player.dodge_system)

	@warning_ignore("static_called_on_instance")
	var cfg: Node = GameManager.get_core_system("config")
	if cfg and cfg.is_feature_enabled("rocket_jump"):
		player.rocket_jump_system = RocketJumpSystem.new()
		player.rocket_jump_system.name = "RocketJumpSystem"
		player.add_child(player.rocket_jump_system)

	@warning_ignore("static_called_on_instance")
	if cfg and cfg.is_feature_enabled("screen_shake"):
		player.screen_shake = ScreenShakeSystem.new()
		player.add_child(player.screen_shake)


static func _setup_hud(player: Node) -> void:
	if PlayerHUDBridgeScript:
		player.hud_bridge = PlayerHUDBridgeScript.new()
		player.hud_bridge.name = "HUDBridge"
		player.add_child(player.hud_bridge)
		player.hud_bridge.setup(player, player.camera, player.raycast, player.interaction_component)

	@warning_ignore("static_called_on_instance")
	var cfg: Node = GameManager.get_core_system("config")
	if cfg and cfg.is_feature_enabled("movement_polish"):
		var movement_polish: MovementPolishSystem = MovementPolishSystem.new()
		movement_polish.name = "MovementPolishSystem"
		player.add_child(movement_polish)


static func _setup_animation(player: Node) -> void:
	if PlayerAnimCompScript:
		player.animation_component = PlayerAnimCompScript.new()
		player.animation_component.name = "AnimationComponent"
		player.add_child(player.animation_component)
		player.animation_component.setup(player)


static func _setup_status_component(player: Node) -> void:
	if PlayerStatusCompScript:
		player.status_component = PlayerStatusCompScript.new()
		player.status_component.name = "StatusComponent"
		player.add_child(player.status_component)
		player.status_component.setup(
			player, player.input_component, player.health_component, player.match_service
		)


static func _setup_combat_component(player: Node) -> void:
	if PlayerCombatCompScript:
		player.combat_component = PlayerCombatCompScript.new()
		player.combat_component.name = "CombatComponent"
		player.add_child(player.combat_component)
		player.combat_component.setup(
			player,
			player.health_component,
			player.match_service,
			player.screen_shake,
			player.blood_hit_spawner,
			player.hud_bridge,
			player.anim_player,
			player.camera
		)


static func _setup_rope(player: Node) -> void:
	player.rope_movement = RopeCompScript.new()
	player.rope_movement.name = "RopeMovement"
	player.add_child(player.rope_movement)
	player.rope_movement.setup(player, player.camera)


static func _setup_blood(player: Node) -> void:
	player.blood_hit_spawner = BloodHitSpawner.new()
	player.blood_hit_spawner.name = "BloodHitSpawner"
	player.blood_hit_spawner.droplet_count_base = 3
	player.add_child(player.blood_hit_spawner)


static func _setup_advanced_movement(player: Node) -> void:
	player.advanced_movement = AdvancedMovementScript.new()
	player.advanced_movement.name = "AdvancedMovement"
	player.add_child(player.advanced_movement)


static func _setup_fall_checker(player: Node) -> void:
	player.fall_checker = FallDeathChecker.new()
	player.fall_checker.name = "FallDeathChecker"
	player.fall_checker.death_y_threshold = (FALL_DEATH_Y_THRESHOLD)
	player.add_child(player.fall_checker)


static func _setup_progression(player: Node) -> void:
	@warning_ignore("static_called_on_instance")
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg or not cfg.is_feature_enabled("skills"):
		return

	player.passive_effects = PassiveEffects.new()
	player.add_child(player.passive_effects)

	player.skill_manager = SkillTreeManager.new()
	player.skill_manager.set_passive_effects(player.passive_effects)
	player.add_child(player.skill_manager)

	player.progression = PlayerProgression.new()
	player.progression.name = "PlayerProgression"
	player.progression.set_skill_manager(player.skill_manager)
	player.add_child(player.progression)

	player.progression.load_progression(GameManager.get_core_system("globals").current_save_slot)


static func _setup_input(player: Node) -> void:
	player.input_component = InputCompScript.new()
	player.input_component.name = "InputComponent"
	player.add_child(player.input_component)
	player.input_component.setup(player.camera)


static func _setup_interaction(player: Node) -> void:
	var interact_path: String = "res://game/entities/player/components/interaction_component.gd"
	var interact_script: Script = load(interact_path)
	if not interact_script:
		return

	player.interaction_component = interact_script.new()
	player.interaction_component.name = "InteractionComponent"
	player.add_child(player.interaction_component)
	player.interaction_component.setup(player, player.camera)

	player.interaction_component.item_collected.connect(player.on_item_collected)


static func _setup_movement_state_machine(player: Node) -> void:
	var sm: Node = StateMachineScript.new()
	sm.name = "MovementStateMachine"
	player.add_child(sm)

	var states: Array[Dictionary] = [
		{"script": IdleStateScript, "name": "IdleState"},
		{"script": WalkStateScript, "name": "WalkState"},
		{"script": RunStateScript, "name": "RunState"},
		{"script": JumpStateScript, "name": "JumpState"},
		{"script": InAirStateScript, "name": "InAirState"},
		{"script": CrouchStateScript, "name": "CrouchState"},
		{"script": SlideStateScript, "name": "SlideState"},
		{"script": DashStateScript, "name": "DashState"},
		{"script": WallrunStateScript, "name": "WallrunState"},
		{"script": FlyStateScript, "name": "FlyState"},
	]

	var first_state: State = null
	for state_def: Dictionary in states:
		var state: State = state_def.script.new()
		state.name = state_def.name
		sm.add_child(state)
		if not first_state:
			first_state = state

	sm.initial_state = first_state


static func _setup_movement_component(player: Node) -> void:
	player.movement_component = MCompScript.new()
	player.movement_component.name = "MovementComponent"
	player.add_child(player.movement_component)
	player.movement_component.setup(
		player,
		player.input_component,
		player.rocket_jump_system,
		player.advanced_movement,
		player.rope_movement
	)


static func _setup_persistence(player: Node) -> void:
	player.persistence_component = PersistCompScript.new()
	player.persistence_component.name = "PersistenceComponent"
	player.add_child(player.persistence_component)
	player.persistence_component.setup(player, player.health_component, player.weapon_manager)


static func _setup_camera(player: Node) -> void:
	player.camera_component = CamCompScript.new()
	player.camera_component.name = "CameraComponent"
	player.camera_component.standing_height = (player.standing_camera_height)
	player.camera_component.crouching_height = (player.crouching_camera_height)
	player.camera_component.transition_speed = (player.crouch_transition_speed)
	player.add_child(player.camera_component)
	player.camera_component.setup(player, player.camera)


static func _setup_weapon_pose(player: Node) -> void:
	var wp: Node = WeaponPoseScript.new()
	wp.name = "WeaponPoseController"
	player.add_child(wp)
	wp.setup(player.weapon_manager, player.visuals)


static func _setup_menu_controller(player: Node) -> void:
	var mc: Node = MenuControllerScript.new()
	mc.name = "MenuController"
	player.add_child(mc)
	mc.setup(player, player.input_component, player.status_component, player.skill_manager)


static func _setup_progression_bridge(player: Node) -> void:
	if not player.progression:
		return
	var pb: Node = ProgressionBridgeScript.new()
	pb.name = "ProgressionBridge"
	player.add_child(pb)
	pb.setup(player.progression)


static func _connect_input_signals(player: Node) -> void:
	if not player.input_component:
		return

	player.input_component.interact_pressed.connect(player.on_input_interact_pressed)
	player.input_component.quick_switch_requested.connect(player.on_input_quick_switch)
	player.input_component.weapon_switch_requested.connect(player.on_input_weapon_switch)
	player.input_component.melee_pressed.connect(player.on_input_melee_pressed)

	# Connect pause signal to open pause menu
	if player.input_component.has_signal("pause_toggled"):
		player.input_component.pause_toggled.connect(_on_player_pause_requested.bind(player))


static func _on_player_pause_requested(_player: Node) -> void:
	## Handle pause input from player
	var us := UISystem.get_service()
	if us and us.ui_manager:
		var ui: Node = us.ui_manager
		# Only open pause if no modal is open and not transitioning
		var can_open: bool = not ui.has_open_modal()
		var pause_path: String = "res://shared/ui_core/screens/pause_screen.tscn"
		if can_open and (not ui.has_method("is_transitioning") or not ui.is_transitioning()):
			ui.push_screen(pause_path)


static func _setup_extended_hud(player: Node) -> void:
	if player.hud_bridge:
		player.hud_bridge.setup_extended_hud()


static func _setup_targeting(player: Node) -> void:
	@warning_ignore("static_called_on_instance")
	var cfg: Node = GameManager.get_core_system("config")
	if cfg and cfg.is_feature_enabled("targeting"):
		player.targeting_system = TargetingSystem.new()
		player.targeting_system.name = "TargetingSystem"
		player.add_child(player.targeting_system)
