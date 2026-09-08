extends ModusGutTestBase


class HostWorld:
	extends "res://game/world/world.gd"

	var spawned_players: Array[int] = []
	var removed_players: Array[int] = []

	# Skip map/UI initialization, but retain production transport and exit behavior.
	func _ready() -> void:
		pass

	func spawn_player_node(peer_id: int, _mode: String) -> void:
		spawned_players.append(peer_id)

	func remove_player(peer_id: int) -> void:
		removed_players.append(peer_id)
		super.remove_player(peer_id)


class SoloWorld:
	extends HostWorld

	var test_port: int

	# Redirect only the fixed solo port; the real ENet bind path remains unchanged.
	func _create_host_session(_port: int, max_players: int) -> Error:
		return super._create_host_session(test_port, max_players)


class DisconnectManager:
	extends NetworkManager

	# Exercise the canonical disconnect path without global networking services.
	func _ready() -> void:
		pass


var _roots: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _peers: Array[ENetMultiplayerPeer] = []
var _world: HostWorld
var _server_api: SceneMultiplayer
var _gameplay: GameplaySvc
var _match_service: Node
var _mouse_mode: Input.MouseMode


func before_each() -> void:
	await modus_setup()
	_mouse_mode = Input.mouse_mode
	# Match/UI initialization is outside this transport fixture.
	_gameplay = GameManager.get_core_system("gameplay") as GameplaySvc
	if _gameplay:
		_match_service = _gameplay.match_service
		_gameplay.match_service = null
	var root := _network_root()
	_server_api = root.multiplayer
	_world = HostWorld.new()
	root.add_child(_world)


func after_each() -> void:
	# Free worlds while their original MultiplayerAPI is still available.
	for root: Node in _roots:
		var root_path: NodePath = root.get_path()
		root.free()
		get_tree().set_multiplayer(null, root_path)
	for api: SceneMultiplayer in _apis:
		api.multiplayer_peer = null
	for peer: ENetMultiplayerPeer in _peers:
		peer.close()
	_roots.clear()
	_apis.clear()
	_peers.clear()
	Input.mouse_mode = _mouse_mode
	modus_teardown()

	if is_instance_valid(_gameplay):
		_gameplay.match_service = _match_service
	_match_service = null
	_gameplay = null


func _network_root() -> Node:
	var root := Node.new()
	add_child(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	_roots.append(root)
	_apis.append(api)
	return root


func _listening_peer(port: int = 0) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	_peers.append(peer)
	assert_eq(peer.create_server(port), OK, "The isolated ENet listener must bind")
	return peer


func _host(port: int = 0) -> void:
	_world._on_host_requested({"port": port, "max_players": 4}, {})


func _connect_client(api: SceneMultiplayer, port: int) -> ENetMultiplayerPeer:
	var client := ENetMultiplayerPeer.new()
	_peers.append(client)
	assert_eq(client.create_client("127.0.0.1", port), OK)
	var root := _network_root()
	root.multiplayer.multiplayer_peer = client
	var client_id: int = client.get_unique_id()
	for attempt in range(120):
		if api.get_peers().has(client_id):
			break
		await get_tree().create_timer(0.01).timeout
	assert_true(api.get_peers().has(client_id), "The host must accept a real ENet client")
	return client


func _disconnect_client(client: ENetMultiplayerPeer) -> void:
	var client_id: int = client.get_unique_id()
	client.disconnect_peer(1)
	for attempt in range(120):
		if _world.removed_players.has(client_id):
			break
		await get_tree().create_timer(0.01).timeout
	assert_eq(
		_world.removed_players.count(client_id),
		1,
		"Each real disconnection must remove the player exactly once"
	)


func test_host_handler_retains_session_and_repeated_starts_preserve_it() -> void:
	_host()
	assert_true(_world.in_game)
	var peer: ENetMultiplayerPeer = _world.enet_peer
	assert_not_null(peer)
	if not peer:
		return
	var port: int = peer.get_host().get_local_port()
	var client := await _connect_client(_server_api, port)

	_host()
	_world._on_single_player_start_requested("must_not_replace_host")
	assert_push_error_count(2)

	assert_same(_server_api.multiplayer_peer, peer, "Repeated starts must keep the current host")
	assert_true(_world.in_game, "Rejecting a duplicate start must not end the active match")
	assert_eq(_world.spawned_players, [1], "Repeated starts must not spawn another local player")
	assert_true(_server_api.get_peers().has(client.get_unique_id()))
	await _disconnect_client(client)


func test_occupied_port_does_not_enter_game_or_close_other_listener() -> void:
	var occupied := _listening_peer()
	var port: int = occupied.get_host().get_local_port()
	var other_root := _network_root()
	other_root.multiplayer.multiplayer_peer = occupied
	# A prior match notification must not make a failed new session appear active.
	_world.in_game = true

	_host(port)
	assert_engine_error_count(1)
	assert_push_error_count(1)

	assert_false(_world.in_game)
	assert_true(_world.spawned_players.is_empty())
	assert_null(_world.enet_peer)
	assert_true(_server_api.multiplayer_peer is OfflineMultiplayerPeer)
	await _connect_client(other_root.multiplayer, port)


func test_network_manager_disconnect_allows_same_port_rehost_without_duplicate_removal() -> void:
	_host()
	var peer: ENetMultiplayerPeer = _world.enet_peer
	assert_not_null(peer)
	if not peer:
		return
	var port: int = peer.get_host().get_local_port()
	var client := await _connect_client(_server_api, port)
	await _disconnect_client(client)
	var manager := DisconnectManager.new()
	_roots[0].add_child(manager)

	manager.disconnect_game()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_world.in_game, "Explicit disconnect must clear owned gameplay state")
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)

	_host(port)
	assert_true(_world.in_game)
	var replacement := await _connect_client(_server_api, port)
	await _disconnect_client(replacement)
	assert_eq(_world.removed_players.size(), 2, "Rehosting must not multiply disconnect callbacks")


func test_world_exit_releases_owned_port_even_with_peer_reference_retained() -> void:
	_host()
	var peer: ENetMultiplayerPeer = _world.enet_peer
	assert_not_null(peer)
	if not peer:
		return
	var port: int = peer.get_host().get_local_port()

	_world.free()

	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)
	assert_false(_server_api.has_multiplayer_peer(), "World exit must detach its owned transport")
	var rebound := _listening_peer(port)
	_server_api.multiplayer_peer = rebound
	await _connect_client(_server_api, port)


func test_host_refusal_and_world_exit_preserve_external_session() -> void:
	var external := _listening_peer()
	var port: int = external.get_host().get_local_port()
	_server_api.multiplayer_peer = external
	_world._on_match_started()

	_host()
	_world._on_single_player_start_requested("must_not_replace_external")
	assert_push_error_count(2)
	await get_tree().process_frame
	assert_true(_world.in_game, "World must retain gameplay state established for external peers")
	assert_true(_world.spawned_players.is_empty())
	assert_same(_server_api.multiplayer_peer, external)

	_world.free()

	assert_same(_server_api.multiplayer_peer, external)
	await _connect_client(_server_api, port)


func test_world_exit_closes_displaced_owned_peer_but_not_its_replacement() -> void:
	_host()
	var owned: ENetMultiplayerPeer = _world.enet_peer
	assert_not_null(owned)
	if not owned:
		return
	var owned_port: int = owned.get_host().get_local_port()
	var external := _listening_peer()
	var external_port: int = external.get_host().get_local_port()
	_server_api.multiplayer_peer = external

	_world.free()

	assert_eq(owned.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)
	assert_same(_server_api.multiplayer_peer, external)
	_listening_peer(owned_port)
	await _connect_client(_server_api, external_port)


func test_singleplayer_bind_failure_does_not_enter_game_or_change_save_slot() -> void:
	var occupied := _listening_peer()
	_world.free()
	var solo := SoloWorld.new()
	solo.test_port = occupied.get_host().get_local_port()
	_world = solo
	_roots[0].add_child(_world)
	var globals: Node = GameManager.get_core_system("globals")
	var previous_slot: String = globals.current_save_slot if globals else ""

	_world._on_single_player_start_requested("must_not_be_selected")
	assert_engine_error_count(1)
	assert_push_error_count(1)

	assert_false(_world.in_game)
	assert_true(_world.spawned_players.is_empty())
	assert_null(_world.enet_peer)
	if globals:
		assert_eq(globals.current_save_slot, previous_slot, "Failed starts must not select a save")


func test_external_replacement_keeps_gameplay_state_and_releases_displaced_host() -> void:
	_host()
	var owned: ENetMultiplayerPeer = _world.enet_peer
	assert_not_null(owned)
	if not owned:
		return
	var port: int = owned.get_host().get_local_port()
	var external := _listening_peer()
	_server_api.multiplayer_peer = external
	_world._on_match_started()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(_world.in_game, "An external match notification must survive owned-peer cleanup")
	assert_same(_server_api.multiplayer_peer, external)
	assert_eq(owned.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)
	_listening_peer(port)
	await _connect_client(_server_api, external.get_host().get_local_port())
