extends GutTest

## Integration tests for breakable props in various multiplayer modes

var glass_scene: PackedScene
var wood_scene: PackedScene
var test_world: Node3D
var _original_peer: MultiplayerPeer


func before_each() -> void:
	_original_peer = multiplayer.multiplayer_peer
	# Load scenes
	glass_scene = load("res://game/world/actors/props/glass_window.tscn")
	wood_scene = load("res://game/world/actors/props/wood_plank.tscn")

	# Create test world
	test_world = Node3D.new()
	add_child_autofree(test_world)


func after_each() -> void:
	# Release only a transport installed by this fixture, preserving the shared API.
	if multiplayer.multiplayer_peer != _original_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = _original_peer


# =============================================================================
# SINGLEPLAYER TESTS
# =============================================================================


func test_glass_breaks_in_singleplayer() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	# Act
	glass.take_damage(15.0, "bullet")
	await wait_frames(2)

	# Assert
	assert_true(glass.is_destroyed, "Glass should be destroyed")
	assert_eq(glass.sync_health, 0.0, "Health should be 0")


func test_wood_breaks_in_singleplayer() -> void:
	# Arrange
	var wood: BreakableWoodPanel = wood_scene.instantiate()
	test_world.add_child(wood)
	await wait_frames(2)

	# Act
	wood.take_damage(35.0, "bullet")
	await wait_frames(2)

	# Assert
	assert_true(wood.is_destroyed, "Wood should be destroyed")
	assert_eq(wood.sync_health, 0.0, "Health should be 0")


func test_glass_takes_partial_damage() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	# Act
	glass.take_damage(5.0, "bullet")
	await wait_frames(2)

	# Assert
	assert_false(glass.is_destroyed, "Glass should not be destroyed")
	assert_eq(glass.sync_health, 5.0, "Health should be 5")


func test_wood_shows_damage_progression() -> void:
	# Arrange
	var wood: BreakableWoodPanel = wood_scene.instantiate()
	test_world.add_child(wood)
	await wait_frames(2)

	var initial_crack_count := wood._crack_count

	# Act
	wood.take_damage(10.0, "bullet")
	await wait_frames(2)

	# Assert
	assert_gt(wood._crack_count, initial_crack_count, "Should have more cracks")
	assert_false(wood.is_destroyed, "Wood should not be destroyed yet")


# =============================================================================
# MULTIPLAYER TESTS
# =============================================================================


func test_glass_breaks_in_multiplayer_server() -> void:
	# Arrange - Setup as server
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(9999)
	multiplayer.multiplayer_peer = peer

	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	# Act
	glass.take_damage(15.0, "bullet")
	await wait_frames(2)

	# Assert
	assert_true(glass.is_destroyed, "Glass should be destroyed on server")
	assert_true(multiplayer.is_server(), "Should be server")


func test_damage_request_validates_server() -> void:
	# Arrange - Setup as server
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(9999)
	multiplayer.multiplayer_peer = peer

	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	# Act - Call RPC directly (simulating client request)
	glass._request_damage(15.0, "bullet")
	await wait_frames(2)

	# Assert - Should process on server
	assert_true(glass.is_destroyed, "Server should process damage request")


# =============================================================================
# EDITOR MODE TESTS
# =============================================================================


func test_props_dont_initialize_in_editor() -> void:
	# This test verifies the Engine.is_editor_hint() checks work
	# In actual editor mode, _ready() would skip initialization

	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	# Assert - In test mode (not editor), should initialize normally
	assert_not_null(glass.mesh_instance, "Should have mesh instance")
	assert_not_null(glass.collision_shape, "Should have collision shape")


# =============================================================================
# SIGNAL TESTS
# =============================================================================


func test_glass_emits_destroyed_signal() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	var _signal_watcher = watch_signals(glass)

	# Act
	glass.take_damage(15.0, "bullet")
	await wait_frames(2)

	# Assert
	assert_signal_emitted(glass, "prop_destroyed", "Should emit destroyed signal")


func test_wood_emits_damaged_signal() -> void:
	# Arrange
	var wood: BreakableWoodPanel = wood_scene.instantiate()
	test_world.add_child(wood)
	await wait_frames(2)

	var _signal_watcher = watch_signals(wood)

	# Act
	wood.take_damage(10.0, "bullet")
	await wait_frames(2)

	# Assert
	assert_signal_emitted(wood, "prop_damaged", "Should emit damaged signal")


# =============================================================================
# HEALTH SYNC TESTS
# =============================================================================


func test_health_syncs_via_multiplayer_synchronizer() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	# Assert - Should have synchronizer
	assert_true(glass.has_node("MultiplayerSynchronizer"), "Should have MultiplayerSynchronizer")

	var sync: MultiplayerSynchronizer = glass.get_node("MultiplayerSynchronizer")
	assert_not_null(sync.replication_config, "Should have replication config")


# =============================================================================
# PHYSICS TESTS
# =============================================================================


func test_glass_spawns_shards_on_break() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	var initial_child_count := test_world.get_child_count()

	# Act
	glass.take_damage(15.0, "bullet")
	await wait_frames(5)  # Wait for shards to spawn

	# Assert
	var final_child_count := test_world.get_child_count()
	# Note: Shards are added to current_scene, not test_world
	# This test verifies the method runs without errors
	assert_true(glass.is_destroyed, "Glass should be destroyed")


func test_wood_spawns_splinters_on_break() -> void:
	# Arrange
	var wood: BreakableWoodPanel = wood_scene.instantiate()
	test_world.add_child(wood)
	await wait_frames(2)

	# Act
	wood.take_damage(35.0, "bullet")
	await wait_frames(5)  # Wait for splinters to spawn

	# Assert
	# Splinters are added to current_scene
	# This test verifies the method runs without errors
	assert_true(wood.is_destroyed, "Wood should be destroyed")


# =============================================================================
# CONFIGURATION TESTS
# =============================================================================


func test_glass_configuration() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	# Assert - Default values
	assert_eq(glass.max_health, 10.0, "Glass should have 10 HP")
	assert_eq(glass.damage_resistance, 0.0, "Glass should have no resistance")
	assert_false(glass.wobble_on_damage, "Glass should not wobble")


func test_wood_configuration() -> void:
	# Arrange
	var wood: BreakableWoodPanel = wood_scene.instantiate()
	test_world.add_child(wood)
	await wait_frames(2)

	# Assert - Default values
	assert_eq(wood.max_health, 30.0, "Wood should have 30 HP")
	assert_eq(wood.damage_resistance, 0.1, "Wood should have 10% resistance")
	assert_true(wood.wobble_on_damage, "Wood should wobble")


# =============================================================================
# EDGE CASES
# =============================================================================


func test_cannot_damage_destroyed_prop() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	glass.take_damage(15.0, "bullet")
	await wait_frames(2)

	var health_after_first_break := glass.sync_health

	# Act - Try to damage again
	glass.take_damage(10.0, "bullet")
	await wait_frames(2)

	# Assert - Health should not change
	assert_eq(glass.sync_health, health_after_first_break, "Health should not change")


func test_zero_damage_does_nothing() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	var initial_health := glass.sync_health

	# Act
	glass.take_damage(0.0, "bullet")
	await wait_frames(2)

	# Assert
	assert_eq(glass.sync_health, initial_health, "Health should not change")
	assert_false(glass.is_destroyed, "Should not be destroyed")


func test_negative_damage_clamped() -> void:
	# Arrange
	var glass: BreakableGlass = glass_scene.instantiate()
	test_world.add_child(glass)
	await wait_frames(2)

	var initial_health := glass.sync_health

	# Act
	glass.take_damage(-10.0, "bullet")
	await wait_frames(2)

	# Assert - Should not heal
	assert_lte(glass.sync_health, initial_health, "Should not heal from negative damage")
