extends ModusGutTestBase

## Unit/integration coverage for Steam-to-ENet fallback.
## All successful listeners use port 0 and are closed after each test.

var _network_manager: Node = null
var _steam_manager: Node = null
var _manager_peer_owned := false
var _original_use_steam := false
var _original_fallback_to_enet := true
var _original_steam_available := false
var _steam_state_saved := false
var _peers: Array[ENetMultiplayerPeer] = []
var _multiplayer_roots: Array[Node] = []


func before_each() -> void:
	await modus_setup()
	var network_service := NetworkSvc.get_service()
	if network_service:
		_network_manager = network_service.network_manager
		_steam_manager = network_service.steam_manager
	if _network_manager:
		_original_use_steam = _network_manager._use_steam
		_original_fallback_to_enet = _network_manager._fallback_to_enet
	if _steam_manager:
		_original_steam_available = _steam_manager._steam_available


func after_each() -> void:
	if _manager_peer_owned and _network_manager:
		_network_manager.disconnect_game()
		_manager_peer_owned = false
	if _network_manager:
		_network_manager._use_steam = _original_use_steam
		_network_manager._fallback_to_enet = _original_fallback_to_enet
	if _steam_state_saved and _steam_manager:
		_steam_manager._steam_available = _original_steam_available
	_steam_state_saved = false

	for peer: ENetMultiplayerPeer in _peers:
		if peer:
			peer.close()
	_peers.clear()
	for root: Node in _multiplayer_roots:
		if is_instance_valid(root):
			get_tree().set_multiplayer(null, root.get_path())
			root.queue_free()
	_multiplayer_roots.clear()
	await get_tree().process_frame
	_network_manager = null
	_steam_manager = null
	modus_teardown()


func test_enet_server_creation_uses_ephemeral_port() -> void:
	var peer := ENetMultiplayerPeer.new()
	_peers.append(peer)
	var error: Error = peer.create_server(0, 8)

	assert_eq(error, OK, "ENet should bind an ephemeral listener")
	var host := peer.get_host()
	assert_not_null(host)
	if host:
		assert_gt(host.get_local_port(), 0, "Ephemeral ENet listener should expose its bound port")
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)


func test_network_manager_falls_back_to_enet_when_steam_unavailable() -> void:
	assert_not_null(_network_manager, "NetworkManager is required for fallback coverage")
	assert_not_null(
		_steam_manager, "SteamManager is required to exercise unavailable-Steam fallback"
	)
	if not _network_manager or not _steam_manager:
		return

	# Drive the production availability check to its unavailable branch without a Steam mock.
	_steam_state_saved = true
	_steam_manager._steam_available = false
	_network_manager._use_steam = true
	_network_manager._fallback_to_enet = true

	var hosting_ports: Array[int] = []
	_network_manager.hosting_started.connect(
		func(port: int) -> void: hosting_ports.append(port), CONNECT_ONE_SHOT
	)
	var error: Error = _network_manager.host_game(0, 2)
	_manager_peer_owned = error == OK
	assert_eq(error, OK, "Fallback should create an ENet host")
	if error != OK:
		return

	var active_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	assert_true(active_peer is ENetMultiplayerPeer, "Unavailable Steam must select ENet")
	var enet_peer := active_peer as ENetMultiplayerPeer
	assert_not_null(enet_peer)
	if not enet_peer:
		return
	assert_gt(enet_peer.get_host().get_local_port(), 0)
	assert_true(multiplayer.is_server())
	assert_eq(hosting_ports.size(), 1)
	assert_eq(hosting_ports[0], enet_peer.get_host().get_local_port())
	assert_eq(_network_manager.get_network_mode(), "ENet (IP/LAN)")


func test_enet_server_accepts_client_on_ephemeral_port() -> void:
	var server_root := _create_multiplayer_root("EnetServer")
	var server_api: SceneMultiplayer = server_root.get_multiplayer() as SceneMultiplayer
	var server_peer := ENetMultiplayerPeer.new()
	_peers.append(server_peer)
	var server_error: Error = server_peer.create_server(0, 2)
	assert_eq(server_error, OK)
	if server_error != OK or not server_peer.get_host():
		return
	server_api.multiplayer_peer = server_peer

	var client_root := _create_multiplayer_root("EnetClient")
	var client_api: SceneMultiplayer = client_root.get_multiplayer() as SceneMultiplayer
	var client_peer := ENetMultiplayerPeer.new()
	_peers.append(client_peer)
	var client_error: Error = client_peer.create_client(
		"127.0.0.1", server_peer.get_host().get_local_port()
	)
	assert_eq(client_error, OK)
	if client_error != OK:
		return
	client_api.multiplayer_peer = client_peer

	assert_true(
		await _wait_for_connection(server_api, client_peer),
		"ENet server should report the ephemeral-port client as connected"
	)
	assert_eq(server_api.get_peers().size(), 1)
	assert_eq(client_peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)


func test_invalid_enet_port_fails_without_connected_peer() -> void:
	var peer := ENetMultiplayerPeer.new()
	_peers.append(peer)
	var error: Error = peer.create_server(-1, 8)

	assert_ne(error, OK)
	assert_ne(peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)


func test_port_conflict_rejects_second_listener_and_allows_new_ephemeral_listener() -> void:
	var first := ENetMultiplayerPeer.new()
	_peers.append(first)
	var first_error: Error = first.create_server(0, 2)
	assert_eq(first_error, OK)
	if first_error != OK or not first.get_host():
		return
	var port := first.get_host().get_local_port()
	assert_gt(port, 0)

	var conflicting := ENetMultiplayerPeer.new()
	_peers.append(conflicting)
	assert_ne(conflicting.create_server(port, 2), OK)
	assert_ne(conflicting.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)

	var replacement := ENetMultiplayerPeer.new()
	_peers.append(replacement)
	var replacement_error: Error = replacement.create_server(0, 2)
	assert_eq(replacement_error, OK)
	if replacement_error == OK and replacement.get_host():
		assert_gt(replacement.get_host().get_local_port(), 0)


func test_fallback_configuration_is_enabled_on_network_manager() -> void:
	assert_not_null(_network_manager, "NetworkManager is required for fallback configuration")
	if not _network_manager:
		return
	assert_typeof(_network_manager._fallback_to_enet, TYPE_BOOL)
	assert_true(_network_manager._fallback_to_enet)


func _create_multiplayer_root(root_name: String) -> Node:
	var root := Node.new()
	root.name = root_name
	add_child(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	_multiplayer_roots.append(root)
	return root


func _wait_for_connection(server_api: SceneMultiplayer, client_peer: ENetMultiplayerPeer) -> bool:
	for _frame: int in range(120):
		if (
			client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
			and not server_api.get_peers().is_empty()
		):
			return true
		await get_tree().process_frame
	return false
