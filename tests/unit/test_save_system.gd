extends ModusGutTestBase

## Unit tests for MODUS Save System
## Tests save file creation, loading, validation, and corruption handling
##
## Requirements: 9 (Save System Testing)

const WORLD_STATE_SCRIPT = preload("res://game/scripts/features/gameplay/game_state_manager.gd")
const PLAYER_STATE_SCRIPT = preload("res://game/entities/player/components/player_state_manager.gd")

var save_system: Node
var test_save_path: String = "user://test_save.dat"
var _network_roots: Array[Node] = []
var _network_apis: Array[SceneMultiplayer] = []


class SavedPlayer:
	extends CharacterBody3D

	var health_component: HealthComponent
	var state_manager: Node
	var downed_handler: DownedStateHandler
	var camera: Camera3D
	var weapon_holder: Node3D
	var input_component: Node
	var weapon_manager: Node
	var standing_camera_height: float = 1.6
	var spawns: Array[Vector3] = []


func before_each() -> void:
	super.before_each()

	# Get save system from GameManager
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		save_system = gm.get_core_system("save")

	# Clean up any existing test save
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)

	await get_tree().process_frame


func after_each() -> void:
	# Clean up test save file
	for api: SceneMultiplayer in _network_apis:
		api.multiplayer_peer.close()
		api.multiplayer_peer = null
	for root: Node in _network_roots:
		get_tree().set_multiplayer(null, root.get_path())
		root.free()
	_network_apis.clear()
	_network_roots.clear()

	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)

	save_system = null
	super.after_each()


# ============================================================================
# Save File Creation Tests (Requirement 9.1)
# ============================================================================


func test_save_system_exists() -> void:
	assert_not_null(save_system, "Save system should be available from GameManager")


func test_save_file_creation() -> void:
	assert_not_null(save_system, "Save system should exist")

	# Create test save data
	var save_data: Dictionary = {
		"player_health": 100,
		"player_position": Vector3(10, 5, 20),
		"inventory": ["weapon_pistol", "item_medkit"]
	}

	# Save to file
	var result: bool = save_system.save_game(test_save_path, save_data)

	# Verify save succeeded
	assert_true(result, "Save operation should succeed")
	assert_true(FileAccess.file_exists(test_save_path), "Save file should exist on disk")


# ============================================================================
# Save File Loading Tests (Requirement 9.2)
# ============================================================================


func test_slot_save_exists_and_delete_use_current_format() -> void:
	assert_not_null(save_system, "Save system should exist")
	var slot := "gut_slot_contract"
	save_system.delete_save(slot)

	assert_true(save_system.save_data(slot, {"version": "1.0", "value": 42}))
	assert_true(save_system.save_exists(slot), "Current .sav slot should be discoverable")
	var saves: Array = save_system.get_all_saves()
	assert_true(
		saves.any(func(entry: Dictionary) -> bool: return entry.get("slot_name", "") == slot),
		"Current slot should appear in save listings"
	)

	save_system.delete_save(slot)
	assert_false(save_system.save_exists(slot), "Delete should remove the current slot format")


func test_game_state_score_keys_restore_as_peer_ids() -> void:
	var state_manager: Node = WORLD_STATE_SCRIPT.new()
	var normalized: Dictionary = state_manager.call(
		"_normalize_player_scores", {"1": {"score": 10}, 2: {"score": 20}, "invalid": {}}
	)
	assert_true(normalized.has(1), "JSON string keys should restore as integer peer IDs")
	assert_true(normalized.has(2), "Existing integer peer IDs should be preserved")
	assert_false(normalized.has("1"), "String peer IDs should not leak into MatchService")
	assert_false(normalized.has("invalid"), "Invalid peer IDs should be ignored")
	state_manager.free()


func test_alive_save_revives_dead_player_and_cancels_pending_respawn() -> void:
	var player := SavedPlayer.new()
	player.name = "SavedPlayer"
	add_child_autofree(player)
	player.camera = Camera3D.new()
	player.add_child(player.camera)
	player.weapon_holder = Node3D.new()
	player.add_child(player.weapon_holder)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = CapsuleShape3D.new()
	player.add_child(collision)
	player.downed_handler = DownedStateHandler.new()
	player.add_child(player.downed_handler)
	player.health_component = HealthComponent.new()
	player.add_child(player.health_component)
	player.state_manager = PLAYER_STATE_SCRIPT.new()
	player.add_child(player.state_manager)
	player.state_manager.setup(player, player.health_component, null)
	player.state_manager.set_respawn_time(0.05)
	player.health_component.died.connect(player.state_manager.enter_downed.unbind(1))
	player.add_to_group("player")

	player.health_component.set_health(0.0, 0.0)
	player.state_manager.enter_dead()
	assert_true(player.health_component.is_dead)
	assert_eq(player.state_manager.current_state, Enums.PlayerState.DEAD)
	assert_false(player.visible)
	var spectator: Node3D = player.state_manager.get("_spectator_instance")
	watch_signals(player.state_manager)

	var world_state: Node = WORLD_STATE_SCRIPT.new()
	add_child_autofree(world_state)
	var saved_position := Vector3(12, 8, 24)
	(
		world_state
		. call(
			"_deserialize_players",
			[
				{
					"peer_id": player.get_multiplayer_authority(),
					"position": [12, 8, 24],
					"rotation": [0, 0.5, 0],
					"health": 25.0,
					"armor": 10.0,
				}
			]
		)
	)

	assert_false(player.health_component.is_dead, "An alive save clears the damage gate")
	assert_eq(player.state_manager.current_state, Enums.PlayerState.ALIVE)
	assert_false(player.downed_handler.is_downed, "Bleedout must stop on restoration")
	assert_true(player.visible)
	assert_false(collision.disabled)
	assert_true(player.weapon_holder.visible)
	assert_true(player.camera.current, "The player regains the camera from the spectator")
	assert_signal_emit_count(player.state_manager, "state_changed", 1)

	await get_tree().create_timer(0.15).timeout
	assert_false(is_instance_valid(spectator), "Restoration releases the spectator")
	assert_eq(
		player.global_position, saved_position, "The old timer cannot teleport the restored player"
	)
	assert_eq(player.health_component.current_health, 25.0, "The old timer cannot refill saved HP")
	assert_eq(player.health_component.current_armor, 10.0)
	assert_signal_not_emitted(player.state_manager, "respawned")
	player.health_component.take_damage(DamageInfo.create(5.0))
	assert_lt(
		player.health_component.current_health, 25.0, "Restored players can take damage again"
	)


func _create_network_saved_player(root: Node, peer_id: int) -> SavedPlayer:
	var player := SavedPlayer.new()
	player.name = "Player"
	root.add_child(player)
	player.health_component = HealthComponent.new()
	player.health_component.name = "Health"
	player.add_child(player.health_component)
	player.downed_handler = DownedStateHandler.new()
	player.add_child(player.downed_handler)
	player.state_manager = PLAYER_STATE_SCRIPT.new()
	player.state_manager.name = "State"
	player.add_child(player.state_manager)
	player.state_manager.setup(player, player.health_component, null)
	player.set_multiplayer_authority(peer_id)
	return player


func test_server_restores_client_owned_health_and_lifecycle_and_rejects_client_writes() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(0), OK)
	var client_peer := ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", server_peer.get_host().get_local_port()), OK)

	for peer: ENetMultiplayerPeer in [server_peer, client_peer]:
		var root := Node3D.new()
		add_child(root)
		var api := SceneMultiplayer.new()
		api.multiplayer_peer = peer
		get_tree().set_multiplayer(api, root.get_path())
		_network_roots.append(root)
		_network_apis.append(api)

	var client_id: int = client_peer.get_unique_id()
	for attempt in range(120):
		if _network_apis[0].get_peers().has(client_id):
			break
		await get_tree().create_timer(0.01).timeout
	assert_true(_network_apis[0].get_peers().has(client_id), "The real client must connect")
	if not _network_apis[0].get_peers().has(client_id):
		return

	var server_player := _create_network_saved_player(_network_roots[0], client_id)
	var client_player := _create_network_saved_player(_network_roots[1], client_id)
	server_player.health_component.set_health(0.0, 0.0)
	for attempt in range(120):
		if client_player.health_component.is_dead:
			break
		await get_tree().create_timer(0.01).timeout
	assert_true(
		client_player.health_component.is_dead, "Server health reaches a client-owned component"
	)
	for player: SavedPlayer in [server_player, client_player]:
		player.state_manager.current_state = Enums.PlayerState.DEAD
		player.downed_handler.enter_downed()
		player.visible = false

	# Even the owning client cannot publish health or clear authoritative death state.
	client_player.health_component.rpc_id(1, "_sync_health_state", 90.0, 100.0)
	client_player.state_manager.rpc_id(1, "_sync_restored_alive")
	await get_tree().create_timer(0.1).timeout
	assert_eq(server_player.health_component.current_health, 0.0)
	assert_true(server_player.health_component.is_dead)
	assert_eq(server_player.state_manager.current_state, Enums.PlayerState.DEAD)

	watch_signals(server_player.health_component)
	watch_signals(client_player.health_component)
	watch_signals(client_player.state_manager)
	server_player.state_manager.restore_health(25.0, 10.0)
	for attempt in range(120):
		if client_player.health_component.current_health == 25.0:
			break
		await get_tree().create_timer(0.01).timeout

	for player: SavedPlayer in [server_player, client_player]:
		assert_eq(player.health_component.current_health, 25.0)
		assert_eq(player.health_component.current_armor, 10.0)
		assert_false(player.health_component.is_dead)
		assert_false(player.downed_handler.is_downed)
		assert_eq(player.state_manager.current_state, Enums.PlayerState.ALIVE)
		assert_true(player.visible)
		assert_signal_emit_count(player.health_component, "health_changed", 1)
		assert_signal_emit_count(player.health_component, "armor_changed", 1)
	assert_signal_emit_count(client_player.state_manager, "state_changed", 1)


func test_save_file_loading() -> void:
	assert_not_null(save_system, "Save system should exist")

	# Create and save test data
	var original_data: Dictionary = {
		"player_health": 75, "player_ammo": 50, "level_name": "test_level"
	}
	save_system.save_game(test_save_path, original_data)

	# Load the save file
	var loaded_data: Dictionary = save_system.load_game(test_save_path)

	# Verify data was loaded correctly
	assert_eq(loaded_data["player_health"], 75, "Loaded health should match saved value")
	assert_eq(loaded_data["player_ammo"], 50, "Loaded ammo should match saved value")
	assert_eq(loaded_data["level_name"], "test_level", "Loaded level name should match saved value")


# ============================================================================
# Save Data Validation Tests (Requirement 9.3)
# ============================================================================


func test_save_data_validation() -> void:
	assert_not_null(save_system, "Save system should exist")

	# Test valid save data
	var valid_data: Dictionary = {"version": "1.0", "player_health": 100}
	assert_true(
		save_system.validate_save_data(valid_data), "Valid save data should pass validation"
	)

	# Test invalid save data (missing required fields)
	var invalid_data: Dictionary = {}
	assert_false(
		save_system.validate_save_data(invalid_data), "Invalid save data should fail validation"
	)


# ============================================================================
# Corruption Handling Tests (Requirement 9.4)
# ============================================================================


func test_save_file_corruption_handling() -> void:
	assert_not_null(save_system, "Save system should exist")

	# Create corrupted save file
	var file: FileAccess = FileAccess.open(test_save_path, FileAccess.WRITE)
	file.store_string("CORRUPTED DATA !@#$%")
	file.close()

	# Attempt to load corrupted file
	var loaded_data: Dictionary = save_system.load_game(test_save_path)

	# Verify graceful handling (returns empty dict or default data)
	assert_true(
		loaded_data.is_empty() or loaded_data.has("error"),
		"Corrupted save should be handled gracefully"
	)


# ============================================================================
# Round-Trip Property Tests (Requirement 9.5)
# ============================================================================


func test_save_load_roundtrip_property() -> void:
	assert_not_null(save_system, "Save system should exist")

	# Create test data
	var original_data: Dictionary = {
		"player_health": 85,
		"player_position": Vector3(15, 10, 25),
		"inventory": ["weapon_shotgun", "item_armor", "ammo_shells"],
		"stats": {"kills": 42, "deaths": 3, "score": 1337}
	}

	# Save
	save_system.save_game(test_save_path, original_data)

	# Load
	var loaded_data: Dictionary = save_system.load_game(test_save_path)

	# Save again
	var roundtrip_path: String = "user://test_save_roundtrip.dat"
	save_system.save_game(roundtrip_path, loaded_data)

	# Load again
	var final_data: Dictionary = save_system.load_game(roundtrip_path)

	# Verify round-trip preserves data
	assert_eq(final_data, original_data, "Round-trip should produce equivalent data")

	# Cleanup
	if FileAccess.file_exists(roundtrip_path):
		DirAccess.remove_absolute(roundtrip_path)
