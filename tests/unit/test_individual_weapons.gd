extends GutTest

## Unit tests for MODUS Weapons System
## Tests all 9 weapons individually, hitscan vs projectile mechanics,
## damage calculations, reload mechanics, and ammo management

const WeaponManagerClass := preload(
	"res://game/entities/player/components/weapon_manager.gd"
)
const WeaponDataClass := preload("res://game/weapons/weapon_data.gd")
const WeaponInventoryClass := preload(
	"res://game/entities/player/components/weapon_inventory.gd"
)
const WeaponAmmoSystemClass := preload(
	"res://game/entities/player/components/weapon_ammo_system.gd"
)
const WeaponFireHandlerClass := preload(
	"res://game/entities/player/components/weapon_fire_handler.gd"
)

var player: CharacterBody3D
var camera: Camera3D
var weapon_holder: Node3D
var audio_player: AudioStreamPlayer3D
var weapon_manager: WeaponManager


func before_each() -> void:
	# Create player
	player = CharacterBody3D.new()
	player.name = "1"  # Network ID
	add_child_autofree(player)
	
	# Create camera
	camera = Camera3D.new()
	camera.name = "Camera"
	player.add_child(camera)
	
	# Create weapon holder
	weapon_holder = Node3D.new()
	weapon_holder.name = "WeaponHolder"
	camera.add_child(weapon_holder)
	
	# Create audio player
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "GunshotSound"
	player.add_child(audio_player)
	
	# Create weapon manager
	weapon_manager = WeaponManager.new()
	weapon_manager.name = "WeaponManager"
	player.add_child(weapon_manager)
	
	# Setup weapon manager and wait for its initial weapon selection.
	await weapon_manager.setup(player, camera, weapon_holder, audio_player)


# ============================================================================
# Individual Weapon Tests
# ============================================================================

func test_knife_weapon_exists() -> void:
	# Get knife weapon (slot 0)
	var knife: WeaponData = _get_weapon_by_name("Combat Knife")
	
	assert_not_null(knife, "Knife weapon should exist")
	assert_eq(knife.weapon_name, "Combat Knife", "Knife should have correct name")


func test_pistol_weapon_exists() -> void:
	# Get pistol weapon
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	assert_not_null(pistol, "Pistol weapon should exist")
	assert_eq(pistol.weapon_name, "Pistol", "Pistol should have correct name")


func test_shotgun_weapon_exists() -> void:
	# Get shotgun weapon
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	assert_not_null(shotgun, "Shotgun weapon should exist")
	assert_eq(shotgun.weapon_name, "Shotgun", "Shotgun should have correct name")


func test_machinegun_weapon_exists() -> void:
	# Get machinegun weapon
	var machinegun: WeaponData = _get_weapon_by_name("Machinegun")
	
	assert_not_null(machinegun, "Machinegun weapon should exist")
	assert_eq(
		machinegun.weapon_name,
		"Machinegun",
		"Machinegun should have correct name"
	)


func test_chaingun_weapon_exists() -> void:
	# Get chaingun weapon
	var chaingun: WeaponData = _get_weapon_by_name("Chaingun")
	
	assert_not_null(chaingun, "Chaingun weapon should exist")
	assert_eq(chaingun.weapon_name, "Chaingun", "Chaingun should have correct name")


func test_grenade_launcher_weapon_exists() -> void:
	# Get grenade launcher weapon
	var grenade_launcher: WeaponData = _get_weapon_by_name("Grenade Launcher")
	
	assert_not_null(grenade_launcher, "Grenade Launcher weapon should exist")
	assert_eq(
		grenade_launcher.weapon_name,
		"Grenade Launcher",
		"Grenade Launcher should have correct name"
	)


func test_rocket_launcher_weapon_exists() -> void:
	# Get rocket launcher weapon
	var rocket_launcher: WeaponData = _get_weapon_by_name("Rocket Launcher")
	
	assert_not_null(rocket_launcher, "Rocket Launcher weapon should exist")
	assert_eq(
		rocket_launcher.weapon_name,
		"Rocket Launcher",
		"Rocket Launcher should have correct name"
	)


func test_hyperblaster_weapon_exists() -> void:
	# Get hyperblaster weapon
	var hyperblaster: WeaponData = _get_weapon_by_name("Hyperblaster")
	
	assert_not_null(hyperblaster, "Hyperblaster weapon should exist")
	assert_eq(
		hyperblaster.weapon_name,
		"Hyperblaster",
		"Hyperblaster should have correct name"
	)


func test_railgun_weapon_exists() -> void:
	# Get railgun weapon
	var railgun: WeaponData = _get_weapon_by_name("Railgun")
	
	assert_not_null(railgun, "Railgun weapon should exist")
	assert_eq(railgun.weapon_name, "Railgun", "Railgun should have correct name")


func test_bfg_weapon_exists() -> void:
	# Get BFG weapon
	var bfg: WeaponData = _get_weapon_by_name("BFG10K")
	
	assert_not_null(bfg, "BFG weapon should exist")
	assert_eq(bfg.weapon_name, "BFG10K", "BFG should have correct name")


# ============================================================================
# Hitscan Weapon Tests
# ============================================================================

func test_pistol_is_hitscan() -> void:
	# Get pistol
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify hitscan (no projectile scene)
	assert_null(
		pistol.projectile_scene,
		"Pistol should be hitscan (no projectile scene)"
	)


func test_shotgun_is_hitscan() -> void:
	# Get shotgun
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	# Verify hitscan
	assert_null(
		shotgun.projectile_scene,
		"Shotgun should be hitscan (no projectile scene)"
	)


func test_machinegun_is_hitscan() -> void:
	# Get machinegun
	var machinegun: WeaponData = _get_weapon_by_name("Machinegun")
	
	# Verify hitscan
	assert_null(
		machinegun.projectile_scene,
		"Machinegun should be hitscan (no projectile scene)"
	)


func test_railgun_is_hitscan() -> void:
	# Get railgun
	var railgun: WeaponData = _get_weapon_by_name("Railgun")
	
	# Verify hitscan
	assert_null(
		railgun.projectile_scene,
		"Railgun should be hitscan (no projectile scene)"
	)


func test_hitscan_weapons_have_zero_projectile_speed() -> void:
	# Get hitscan weapons
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	# Verify zero projectile speed (instant hit)
	assert_eq(
		pistol.projectile_speed,
		0.0,
		"Hitscan weapons should have zero projectile speed"
	)
	assert_eq(
		shotgun.projectile_speed,
		0.0,
		"Hitscan weapons should have zero projectile speed"
	)


# ============================================================================
# Projectile Weapon Tests
# ============================================================================

func test_rocket_launcher_is_projectile() -> void:
	# Get rocket launcher
	var rocket_launcher: WeaponData = _get_weapon_by_name("Rocket Launcher")
	
	# Verify projectile weapon
	assert_not_null(
		rocket_launcher.projectile_scene,
		"Rocket Launcher should be projectile weapon"
	)


func test_grenade_launcher_is_projectile() -> void:
	# Get grenade launcher
	var grenade_launcher: WeaponData = _get_weapon_by_name("Grenade Launcher")
	
	# Verify projectile weapon
	assert_not_null(
		grenade_launcher.projectile_scene,
		"Grenade Launcher should be projectile weapon"
	)


func test_hyperblaster_is_projectile() -> void:
	# Get hyperblaster
	var hyperblaster: WeaponData = _get_weapon_by_name("Hyperblaster")
	
	# Verify projectile weapon
	assert_not_null(
		hyperblaster.projectile_scene,
		"Hyperblaster should be projectile weapon"
	)


func test_bfg_is_projectile() -> void:
	# Get BFG
	var bfg: WeaponData = _get_weapon_by_name("BFG10K")
	
	# Verify projectile weapon
	assert_not_null(
		bfg.projectile_scene,
		"BFG should be projectile weapon"
	)


func test_projectile_weapons_have_speed() -> void:
	# Get projectile weapons
	var rocket: WeaponData = _get_weapon_by_name("Rocket Launcher")
	var hyperblaster: WeaponData = _get_weapon_by_name("Hyperblaster")
	
	# Verify projectile speed
	assert_gt(
		rocket.projectile_speed,
		0.0,
		"Projectile weapons should have positive speed"
	)
	assert_gt(
		hyperblaster.projectile_speed,
		0.0,
		"Projectile weapons should have positive speed"
	)


# ============================================================================
# Weapon Damage Tests
# ============================================================================

func test_pistol_damage() -> void:
	# Get pistol
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify damage value
	assert_eq(pistol.damage, 10, "Pistol should deal 10 damage")


func test_shotgun_damage_per_pellet() -> void:
	# Get shotgun
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	# Verify damage per pellet
	assert_eq(shotgun.damage, 5, "Shotgun should deal 5 damage per pellet")
	assert_eq(shotgun.pellet_count, 8, "Shotgun should fire 8 pellets")


func test_shotgun_total_damage() -> void:
	# Get shotgun
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	# Calculate total damage (all pellets hit)
	var total_damage: int = shotgun.damage * shotgun.pellet_count
	
	# Verify total damage
	assert_eq(
		total_damage,
		40,
		"Shotgun should deal 40 total damage (all pellets)"
	)


func test_rocket_launcher_damage() -> void:
	# Get rocket launcher
	var rocket: WeaponData = _get_weapon_by_name("Rocket Launcher")
	
	# Verify damage
	assert_eq(rocket.damage, 80, "Rocket Launcher should deal 80 damage")


func test_railgun_damage() -> void:
	# Get railgun
	var railgun: WeaponData = _get_weapon_by_name("Railgun")
	
	# Verify damage
	assert_eq(railgun.damage, 80, "Railgun should deal 80 damage")


func test_bfg_damage() -> void:
	# Get BFG
	var bfg: WeaponData = _get_weapon_by_name("BFG10K")
	
	# Verify damage
	assert_eq(bfg.damage, 200, "BFG should deal 200 damage")


func test_knife_damage() -> void:
	# Get knife
	var knife: WeaponData = _get_weapon_by_name("Combat Knife")
	
	# Verify damage
	assert_eq(knife.damage, 35, "Knife should deal 35 damage")


# ============================================================================
# Weapon Reload Tests
# ============================================================================

func test_pistol_reload_time() -> void:
	# Get pistol
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify reload time
	assert_eq(pistol.reload_time, 1.5, "Pistol should have 1.5s reload time")


func test_shotgun_reload_time() -> void:
	# Get shotgun
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	# Verify reload time
	assert_eq(shotgun.reload_time, 2.5, "Shotgun should have 2.5s reload time")


func test_rocket_launcher_reload_time() -> void:
	# Get rocket launcher
	var rocket: WeaponData = _get_weapon_by_name("Rocket Launcher")
	
	# Verify reload time
	assert_eq(rocket.reload_time, 3.0, "Rocket Launcher should have 3.0s reload time")


func test_reload_starts_correctly() -> void:
	# Switch to pistol
	var pistol_index := _get_weapon_index_by_name("Pistol")
	await weapon_manager.switch_to_weapon(pistol_index)

	# Empty magazine by firing
	if weapon_manager.ammo_system:
		for i: int in range(12):  # Pistol has 12 rounds
			weapon_manager.ammo_system.consume_ammo(pistol_index)
	
	# Start reload
	watch_signals(weapon_manager)
	weapon_manager.start_reload()

	# Verify reload signal emitted
	assert_signal_emitted(weapon_manager, "reload_started")


func test_reload_finishes_correctly() -> void:
	# Switch to pistol
	var pistol_index := _get_weapon_index_by_name("Pistol")
	await weapon_manager.switch_to_weapon(pistol_index)

	# Empty magazine
	if weapon_manager.ammo_system:
		for i: int in range(12):
			weapon_manager.ammo_system.consume_ammo(pistol_index)
	
	# Start reload and wait
	weapon_manager.start_reload()
	await get_tree().create_timer(1.6).timeout  # Wait for reload to finish
	
	# Verify ammo restored
	var ammo: Array = weapon_manager.get_current_ammo()
	assert_gt(ammo[0], 0, "Reload should restore ammo")


func test_knife_has_no_reload() -> void:
	# Get knife
	var knife: WeaponData = _get_weapon_by_name("Combat Knife")
	
	# Verify no reload
	assert_eq(knife.reload_time, 0.0, "Knife should have no reload time")


# ============================================================================
# Weapon Ammo Management Tests
# ============================================================================

func test_pistol_magazine_size() -> void:
	# Get pistol
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify magazine size
	assert_eq(pistol.magazine_size, 12, "Pistol should have 12 round magazine")


func test_pistol_reserve_ammo() -> void:
	# Get pistol
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify reserve ammo
	assert_eq(pistol.max_reserve_ammo, 48, "Pistol should have 48 reserve ammo")


func test_shotgun_magazine_size() -> void:
	# Get shotgun
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	# Verify magazine size
	assert_eq(shotgun.magazine_size, 6, "Shotgun should have 6 shell magazine")


func test_machinegun_magazine_size() -> void:
	# Get machinegun
	var machinegun: WeaponData = _get_weapon_by_name("Machinegun")
	
	# Verify magazine size
	assert_eq(machinegun.magazine_size, 50, "Machinegun should have 50 round magazine")


func test_chaingun_magazine_size() -> void:
	# Get chaingun
	var chaingun: WeaponData = _get_weapon_by_name("Chaingun")
	
	# Verify magazine size
	assert_eq(chaingun.magazine_size, 100, "Chaingun should have 100 round magazine")


func test_rocket_launcher_magazine_size() -> void:
	# Get rocket launcher
	var rocket: WeaponData = _get_weapon_by_name("Rocket Launcher")
	
	# Verify magazine size
	assert_eq(rocket.magazine_size, 4, "Rocket Launcher should have 4 rocket magazine")


func test_ammo_consumption() -> void:
	# Switch to pistol
	var pistol_index := _get_weapon_index_by_name("Pistol")
	await weapon_manager.switch_to_weapon(pistol_index)
	
	# Get initial ammo
	var initial_ammo: Array = weapon_manager.get_current_ammo()
	var initial_current: int = initial_ammo[0]
	
	# Consume ammo
	if weapon_manager.ammo_system:
		weapon_manager.ammo_system.consume_ammo(pistol_index)
	
	# Get new ammo
	var new_ammo: Array = weapon_manager.get_current_ammo()
	var new_current: int = new_ammo[0]
	
	# Verify ammo decreased
	assert_eq(new_current, initial_current - 1, "Firing should consume ammo")


func test_ammo_refill() -> void:
	# Switch to pistol
	var pistol_index := _get_weapon_index_by_name("Pistol")
	await weapon_manager.switch_to_weapon(pistol_index)

	# Consume some ammo
	if weapon_manager.ammo_system:
		for i: int in range(5):
			weapon_manager.ammo_system.consume_ammo(pistol_index)
	
	# Refill ammo
	weapon_manager.refill_ammo()
	
	# Get ammo
	var ammo: Array = weapon_manager.get_current_ammo()
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify ammo refilled
	assert_eq(
		ammo[0],
		pistol.magazine_size,
		"Refill should restore magazine to full"
	)


func test_knife_infinite_ammo() -> void:
	# Get knife
	var knife: WeaponData = _get_weapon_by_name("Combat Knife")
	
	# Verify infinite ammo
	assert_eq(knife.magazine_size, 999, "Knife should have infinite ammo")
	assert_eq(knife.max_reserve_ammo, 0, "Knife should have no reserve ammo")


# ============================================================================
# Weapon Fire Rate Tests
# ============================================================================

func test_pistol_fire_rate() -> void:
	# Get pistol
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify fire rate
	assert_eq(pistol.fire_rate, 0.4, "Pistol should have 0.4s fire rate")


func test_shotgun_fire_rate() -> void:
	# Get shotgun
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	# Verify fire rate
	assert_eq(shotgun.fire_rate, 1.0, "Shotgun should have 1.0s fire rate")


func test_machinegun_fire_rate() -> void:
	# Get machinegun
	var machinegun: WeaponData = _get_weapon_by_name("Machinegun")
	
	# Verify fire rate
	assert_eq(machinegun.fire_rate, 0.1, "Machinegun should have 0.1s fire rate")


func test_pistol_is_semi_automatic() -> void:
	# Get pistol
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify semi-automatic
	assert_false(pistol.is_automatic, "Pistol should be semi-automatic")


func test_machinegun_is_automatic() -> void:
	# Get machinegun
	var machinegun: WeaponData = _get_weapon_by_name("Machinegun")
	
	# Verify automatic
	assert_true(machinegun.is_automatic, "Machinegun should be automatic")


# ============================================================================
# Weapon Spread Tests
# ============================================================================

func test_pistol_has_no_spread() -> void:
	# Get pistol
	var pistol: WeaponData = _get_weapon_by_name("Pistol")
	
	# Verify no spread
	assert_eq(pistol.spread_angle, 0.0, "Pistol should have perfect accuracy")


func test_shotgun_has_spread() -> void:
	# Get shotgun
	var shotgun: WeaponData = _get_weapon_by_name("Shotgun")
	
	# Verify spread
	assert_gt(shotgun.spread_angle, 0.0, "Shotgun should have spread")
	assert_eq(shotgun.spread_angle, 15.0, "Shotgun should have 15 degree spread")


func test_machinegun_has_spread() -> void:
	# Get machinegun
	var machinegun: WeaponData = _get_weapon_by_name("Machinegun")
	
	# Verify spread
	assert_gt(machinegun.spread_angle, 0.0, "Machinegun should have spread")


func test_railgun_has_no_spread() -> void:
	# Get railgun
	var railgun: WeaponData = _get_weapon_by_name("Railgun")
	
	# Verify no spread
	assert_eq(railgun.spread_angle, 0.0, "Railgun should have perfect accuracy")


# ============================================================================
# Weapon Switching Tests
# ============================================================================

func test_weapon_switch_signal() -> void:
	# Watch signals
	watch_signals(weapon_manager)

	# Switch weapon
	await weapon_manager.switch_to_weapon(_get_weapon_index_by_name("Shotgun"))

	# Verify signal emitted
	assert_signal_emitted(weapon_manager, "weapon_switched")


func test_weapon_switch_updates_current_weapon() -> void:
	# Switch to shotgun
	await weapon_manager.switch_to_weapon(_get_weapon_index_by_name("Shotgun"))
	
	# Get current weapon
	var current: WeaponData = weapon_manager.get_current_weapon()
	
	# Verify weapon switched
	assert_not_null(current, "Current weapon should not be null")
	if current:
		assert_eq(current.weapon_name, "Shotgun", "Current weapon should be Shotgun")


func test_weapon_switch_updates_ammo_display() -> void:
	# Switch to pistol
	await weapon_manager.switch_to_weapon(_get_weapon_index_by_name("Pistol"))
	
	# Get ammo
	var pistol_ammo: Array = weapon_manager.get_current_ammo()
	
	# Switch to shotgun
	await weapon_manager.switch_to_weapon(_get_weapon_index_by_name("Shotgun"))
	
	# Get ammo
	var shotgun_ammo: Array = weapon_manager.get_current_ammo()
	
	# Verify ammo changed
	assert_ne(
		pistol_ammo[0],
		shotgun_ammo[0],
		"Weapon switch should update ammo display"
	)


# ============================================================================
# Special Weapon Features Tests
# ============================================================================

func test_chaingun_has_spinup() -> void:
	# Get chaingun
	var chaingun: WeaponData = _get_weapon_by_name("Chaingun")
	
	# Verify spinup feature
	assert_true(chaingun.has_spin_up, "Chaingun should have spin-up mechanic")


func test_rocket_launcher_has_blast_radius() -> void:
	# Get rocket launcher
	var rocket: WeaponData = _get_weapon_by_name("Rocket Launcher")
	
	# Verify blast radius
	assert_gt(rocket.blast_radius, 0.0, "Rocket Launcher should have blast radius")
	assert_eq(rocket.blast_radius, 5.0, "Rocket Launcher should have 5m blast radius")


func test_grenade_launcher_has_blast_radius() -> void:
	# Get grenade launcher
	var grenade: WeaponData = _get_weapon_by_name("Grenade Launcher")
	
	# Verify blast radius
	assert_gt(grenade.blast_radius, 0.0, "Grenade Launcher should have blast radius")


func test_knife_has_melee_range() -> void:
	# Get knife
	var knife: WeaponData = _get_weapon_by_name("Combat Knife")
	
	# Verify melee range
	assert_gt(knife.attack_range, 0.0, "Knife should have melee range")
	assert_eq(knife.attack_range, 2.0, "Knife should have 2m range")


# ============================================================================
# Helper Functions
# ============================================================================

func _get_weapon_by_name(weapon_name: String) -> WeaponData:
	## Helper to get weapon by name from inventory
	if not weapon_manager or not weapon_manager.inventory:
		return null

	for weapon: WeaponData in weapon_manager.inventory.weapons:
		if weapon.weapon_name == weapon_name:
			return weapon

	return null


func _get_weapon_index_by_name(weapon_name: String) -> int:
	for index in weapon_manager.inventory.weapons.size():
		if weapon_manager.inventory.weapons[index].weapon_name == weapon_name:
			return index
	return -1
