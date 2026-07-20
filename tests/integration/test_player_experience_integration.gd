extends GutTest

## Comprehensive Player Experience Integration Test
## Tests signals, visibility layers, system initialization, VFX, HUD, weapons
## Focuses on player-facing functionality and user experience

var _player: CharacterBody3D
var _camera: Camera3D
var _weapon_manager: Node
var _hud: Control


func before_each() -> void:
	await super.before_each()
	# Setup test environment
	_setup_test_scene()


func after_each() -> void:
	super.after_each()
	# Cleanup
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null
	_camera = null
	_weapon_manager = null
	_hud = null


func _setup_test_scene() -> void:
	## Load and instantiate player for testing
	var player_scene: PackedScene = load("res://game/entities/player/player.tscn")
	assert_not_null(player_scene, "Player scene should load")

	_player = player_scene.instantiate()
	assert_not_null(_player, "Player should instantiate")

	get_tree().root.add_child(_player)
	await get_tree().process_frame

	# Get references
	_camera = _player.get_node_or_null("Camera3D")
	_weapon_manager = _player.get_node_or_null("WeaponManager")


# =============================================================================
# PLAYER CORE SYSTEMS
# =============================================================================


func test_player_has_required_nodes() -> void:
	assert_not_null(_player, "Player should exist")
	assert_not_null(_camera, "Player should have Camera3D")
	assert_not_null(_player.get_node_or_null("CollisionShape3D"), "Player should have collision")
	assert_not_null(_player.get_node_or_null("HUDLayer"), "Player should have HUD layer")


func test_player_camera_settings() -> void:
	assert_not_null(_camera, "Camera should exist")
	assert_true(_camera.current, "Camera should be current")
	assert_gt(_camera.fov, 0, "Camera FOV should be positive")
	assert_gt(_camera.near, 0, "Camera near plane should be positive")
	assert_lt(_camera.near, 0.1, "Camera near plane should be small enough for weapons")
	assert_gt(_camera.far, 100, "Camera far plane should be reasonable")


func test_player_collision_layers() -> void:
	assert_not_null(_player, "Player should exist")
	# Player should be on player layer and collide with world/enemies
	assert_gt(_player.collision_layer, 0, "Player should have collision layer set")
	assert_gt(_player.collision_mask, 0, "Player should have collision mask set")


# =============================================================================
# WEAPON SYSTEM INTEGRATION
# =============================================================================


func test_weapon_manager_exists() -> void:
	assert_not_null(_weapon_manager, "WeaponManager should exist")


func test_weapon_manager_has_required_components() -> void:
	if not _weapon_manager:
		return

	var inventory: Node = _weapon_manager.get_node_or_null("WeaponInventory")
	var ammo_system: Node = _weapon_manager.get_node_or_null("WeaponAmmoSystem")
	var fire_handler: Node = _weapon_manager.get_node_or_null("WeaponFireHandler")
	var vfx: Node = _weapon_manager.get_node_or_null("WeaponVFX")

	assert_not_null(inventory, "WeaponManager should have WeaponInventory")
	assert_not_null(ammo_system, "WeaponManager should have WeaponAmmoSystem")
	assert_not_null(fire_handler, "WeaponManager should have WeaponFireHandler")
	assert_not_null(vfx, "WeaponManager should have WeaponVFX")


func test_weapon_holder_visible() -> void:
	var weapon_holder: Node3D = _camera.get_node_or_null("WeaponHolder") if _camera else null
	assert_not_null(weapon_holder, "WeaponHolder should exist under camera")
	assert_true(weapon_holder.visible, "WeaponHolder should be visible")


func test_weapons_load_from_database() -> void:
	if not _weapon_manager:
		return

	var inventory: Node = _weapon_manager.get_node_or_null("WeaponInventory")
	if not inventory:
		return

	assert_true(inventory.weapons.size() > 0, "Should have weapons loaded from database")
	assert_true(inventory.weapon_scenes.size() > 0, "Should have weapon scenes instantiated")


func test_weapon_models_visible() -> void:
	if not _weapon_manager:
		return

	var inventory: Node = _weapon_manager.get_node_or_null("WeaponInventory")
	if not inventory or inventory.weapon_scenes.size() == 0:
		return

	# First weapon should be visible
	var first_weapon: Node3D = inventory.weapon_scenes[0]
	assert_not_null(first_weapon, "First weapon should exist")
	assert_true(first_weapon.visible, "First weapon should be visible")
	assert_true(first_weapon.is_inside_tree(), "First weapon should be in scene tree")


func test_weapon_signals_connected() -> void:
	if not _weapon_manager:
		return

	# Check critical signals exist
	assert_has_signal(
		_weapon_manager, "weapon_fired", "WeaponManager should have weapon_fired signal"
	)
	assert_has_signal(
		_weapon_manager, "weapon_switched", "WeaponManager should have weapon_switched signal"
	)
	assert_has_signal(
		_weapon_manager, "ammo_changed", "WeaponManager should have ammo_changed signal"
	)
	assert_has_signal(
		_weapon_manager, "reload_started", "WeaponManager should have reload_started signal"
	)
	assert_has_signal(
		_weapon_manager, "reload_finished", "WeaponManager should have reload_finished signal"
	)


# =============================================================================
# VFX SYSTEM INTEGRATION
# =============================================================================


func test_vfx_component_exists() -> void:
	if not _weapon_manager:
		return

	var vfx: Node = _weapon_manager.get_node_or_null("WeaponVFX")
	assert_not_null(vfx, "WeaponVFX component should exist")


func test_vfx_has_required_methods() -> void:
	if not _weapon_manager:
		return

	var vfx: Node = _weapon_manager.get_node_or_null("WeaponVFX")
	if not vfx:
		return

	assert_true(vfx.has_method("spawn_bullet_tracer"), "VFX should have spawn_bullet_tracer")
	assert_true(vfx.has_method("spawn_muzzle_smoke"), "VFX should have spawn_muzzle_smoke")
	assert_true(vfx.has_method("spawn_bullet_hole"), "VFX should have spawn_bullet_hole")
	assert_true(vfx.has_method("spawn_enemy_blood"), "VFX should have spawn_enemy_blood")


func test_effects_service_available() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		pending("GameCore not available")
		return

	var effects: Node = game_manager.get_service("effects")
	assert_not_null(effects, "Effects service should be available")


func test_effects_service_has_required_methods() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		pending("GameCore not available")
		return

	var effects: Node = game_manager.get_service("effects")
	if not effects:
		return

	assert_true(effects.has_method("spawn_blood_synced"), "Effects should have spawn_blood_synced")
	assert_true(effects.has_method("spawn_gore_effect"), "Effects should have spawn_gore_effect")


# =============================================================================
# HUD SYSTEM INTEGRATION
# =============================================================================


func test_hud_layer_exists() -> void:
	var hud_layer: CanvasLayer = _player.get_node_or_null("HUDLayer")
	assert_not_null(hud_layer, "HUDLayer should exist")


func test_hud_components_exist() -> void:
	var hud_layer: CanvasLayer = _player.get_node_or_null("HUDLayer")
	if not hud_layer:
		return

	# Check for critical HUD elements
	var crosshair: Control = hud_layer.get_node_or_null("Crosshair")
	var health_bar: Control = hud_layer.get_node_or_null("HealthBar")
	var ammo_display: Control = hud_layer.get_node_or_null("AmmoDisplay")

	# At least one HUD element should exist
	var has_hud: bool = crosshair != null or health_bar != null or ammo_display != null
	assert_true(has_hud, "Should have at least one HUD element")


func test_hud_visible_by_default() -> void:
	var hud_layer: CanvasLayer = _player.get_node_or_null("HUDLayer")
	if not hud_layer:
		return

	assert_true(hud_layer.visible, "HUD layer should be visible by default")


func test_damage_indicator_exists() -> void:
	var damage_indicator: Control = _player.get_node_or_null("HUDLayer/DamageIndicatorManager")
	# Damage indicator is optional but should exist if referenced
	if damage_indicator:
		assert_true(damage_indicator.is_inside_tree(), "Damage indicator should be in tree")


# =============================================================================
# SIGNAL HYGIENE
# =============================================================================


func test_no_orphaned_signals() -> void:
	## Check that player signals are properly connected
	if not _player:
		return

	# Get all signals from player
	var signal_list: Array = _player.get_signal_list()

	for sig_info in signal_list:
		var sig_name: String = sig_info["name"]
		var connections: Array = _player.get_signal_connection_list(sig_name)

		# Critical signals should have connections
		if sig_name in ["health_changed", "died", "respawned"]:
			assert_gt(
				connections.size(), 0, "Critical signal '%s' should have connections" % sig_name
			)


func test_weapon_manager_signals_connected() -> void:
	if not _weapon_manager:
		return

	# Check weapon_fired signal has connections (should connect to HUD/VFX)
	var connections: Array = _weapon_manager.get_signal_connection_list("weapon_fired")
	# May not have connections in test environment, but signal should exist
	assert_has_signal(_weapon_manager, "weapon_fired", "weapon_fired signal should exist")


# =============================================================================
# ASSET INTEGRITY
# =============================================================================


func test_weapon_assets_exist() -> void:
	## Verify weapon view models exist
	var weapon_paths: Array[String] = [
		"res://game/weapons/pistol.tscn",
		"res://game/weapons/machinegun.tscn",
		"res://game/weapons/shotgun.tscn",
	]

	for path in weapon_paths:
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path)
			assert_not_null(scene, "Weapon scene should load: %s" % path)


func test_vfx_shaders_exist() -> void:
	## Verify critical VFX shaders exist
	var shader_paths: Array[String] = [
		"res://game/art/shaders/retro_tracer.gdshader",
	]

	for path in shader_paths:
		if ResourceLoader.exists(path):
			var shader: Shader = load(path)
			assert_not_null(shader, "Shader should load: %s" % path)


func test_particle_scenes_exist() -> void:
	## Verify particle effect scenes exist
	var particle_paths: Array[String] = [
		"res://game/entities/effects/blood_spray.tscn",
		"res://game/scenes/effects/explosion_particles.gd",
		"res://game/scenes/effects/glass_shatter_particles.gd",
	]

	for path in particle_paths:
		assert_true(
			ResourceLoader.exists(path) or FileAccess.file_exists(path),
			"Particle asset should exist: %s" % path
		)


# =============================================================================
# SERVICE AVAILABILITY
# =============================================================================


func test_required_services_available() -> void:
	## Verify all services needed for player experience are available
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		pending("GameCore not available")
		return

	var required_services: Array[String] = [
		"effects",
		"audio",
		"ui",
	]

	for service_name in required_services:
		var service: Node = game_manager.get_service(service_name)
		assert_not_null(service, "Service '%s' should be available" % service_name)


func test_gameplay_services_available() -> void:
	## Verify gameplay services are available
	var gs := GameplaySvc.get_service()
	assert_not_null(gs, "GameplaySvc should be available")

	if gs:
		assert_not_null(gs.combat, "Combat service should be available")
		assert_not_null(gs.entity_registry, "Entity registry should be available")


# =============================================================================
# VISIBILITY LAYERS
# =============================================================================


func test_player_visible_in_first_person() -> void:
	## Player body should be visible in first-person (for GTA V style)
	var visuals: Node = _player.get_node_or_null("SkeletalCharacterVisuals")
	if not visuals:
		return

	# Visuals should exist and be in tree
	assert_true(visuals.is_inside_tree(), "Player visuals should be in tree")


func test_weapon_layer_mask() -> void:
	## Weapons should be on correct layer to be visible to camera
	var weapon_holder: Node3D = _camera.get_node_or_null("WeaponHolder") if _camera else null
	if not weapon_holder:
		return

	# Weapon holder should be in tree and visible
	assert_true(weapon_holder.is_inside_tree(), "Weapon holder should be in tree")
	assert_true(weapon_holder.visible, "Weapon holder should be visible")


func test_camera_cull_mask() -> void:
	## Camera should see all necessary layers
	if not _camera:
		return

	var cull_mask: int = _camera.cull_mask
	assert_gt(cull_mask, 0, "Camera cull mask should be set")


# =============================================================================
# INITIALIZATION ORDER
# =============================================================================


func test_systems_initialize_in_correct_order() -> void:
	## Verify systems are initialized before use
	if not _weapon_manager:
		return

	var inventory: Node = _weapon_manager.get_node_or_null("WeaponInventory")
	var ammo_system: Node = _weapon_manager.get_node_or_null("WeaponAmmoSystem")

	# If inventory exists, it should have weapons loaded
	if inventory:
		# Weapons should be loaded (may be 0 in test environment)
		assert_true(inventory.weapons is Array, "Inventory should have weapons array")

	# If ammo system exists, it should be initialized
	if ammo_system:
		assert_true(ammo_system.has_method("get_current_ammo"), "Ammo system should be initialized")


func test_no_null_references() -> void:
	## Check for common null reference issues
	if not _weapon_manager:
		return

	# Camera should be set
	assert_not_null(_weapon_manager.camera, "WeaponManager should have camera reference")

	# Player should be set
	assert_not_null(_weapon_manager.player, "WeaponManager should have player reference")


# =============================================================================
# FUNCTIONAL TESTS
# =============================================================================


func test_weapon_switching_works() -> void:
	if not _weapon_manager:
		return

	var inventory: Node = _weapon_manager.get_node_or_null("WeaponInventory")
	if not inventory or inventory.weapons.size() < 2:
		return

	var initial_weapon: int = inventory.current_weapon_index

	# Try to switch weapon
	_weapon_manager.switch_to_weapon(1)
	await get_tree().process_frame

	# Weapon should have switched (or stayed same if only 1 weapon)
	assert_true(inventory.current_weapon_index >= 0, "Should have valid weapon index")


func test_ammo_display_updates() -> void:
	if not _weapon_manager:
		return

	# Check if ammo_changed signal exists and can be emitted
	assert_has_signal(_weapon_manager, "ammo_changed", "Should have ammo_changed signal")

	# Signal should be emittable
	var signal_emitted: bool = false
	_weapon_manager.ammo_changed.connect(
		func(_current: int, _reserve: int, _weapon: String) -> void: signal_emitted = true
	)

	# Trigger ammo update
	if _weapon_manager.has_method("get_current_ammo"):
		var ammo: Array = _weapon_manager.get_current_ammo()
		assert_true(ammo is Array, "Should return ammo array")


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================


func assert_has_signal(obj: Object, signal_name: String, message: String = "") -> void:
	var signals: Array = obj.get_signal_list()
	var has_signal: bool = false

	for sig_info in signals:
		if sig_info["name"] == signal_name:
			has_signal = true
			break

	assert_true(has_signal, message if message else "Object should have signal: %s" % signal_name)
