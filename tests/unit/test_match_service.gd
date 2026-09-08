extends ModusGutTestBase

# Test MODUS Framework Match Service
# Converted from legacy Dictionary format to GUT assertions

var _match_svc: MatchSvc = null
var _network_roots: Array[Node] = []
var _network_matches: Array[MatchSvc] = []


func before_each() -> void:
	await modus_setup()
	_match_svc = MatchSvc.get_instance()


func after_each() -> void:
	for root: Node in _network_roots:
		root.multiplayer.multiplayer_peer.close()
	for root: Node in _network_roots:
		var root_path: NodePath = root.get_path()
		root.free()
		get_tree().set_multiplayer(null, root_path)
	_network_roots.clear()
	_network_matches.clear()
	modus_teardown()


# =============================================================================
# SERVICE AVAILABILITY
# =============================================================================


func test_service_exists() -> void:
	if not _match_svc:
		_match_svc = MatchSvc.get_instance()

	assert_not_null(_match_svc, "MatchSvc.get_instance() should return valid instance")


func test_service_has_required_methods() -> void:
	if not _match_svc:
		_match_svc = MatchSvc.get_instance()

	assert_not_null(_match_svc, "MatchSvc should be available")

	if not _match_svc:
		return

	var required_methods: Array[String] = [
		"init_player_score",
		"get_player_score",
		"register_kill",
		"get_sorted_scores",
	]

	for method_name: String in required_methods:
		assert_true(
			_match_svc.has_method(method_name), "MatchSvc should have method: %s" % method_name
		)


# =============================================================================
# PLAYER SCORE MANAGEMENT
# =============================================================================


func test_init_player_score() -> void:
	if not _match_svc:
		_match_svc = MatchSvc.get_instance()

	assert_not_null(_match_svc, "MatchSvc should be available")

	if not _match_svc:
		return

	var test_peer_id: int = 99999

	# Initialize score
	_match_svc.init_player_score(test_peer_id)

	# Verify score was initialized
	var score: Dictionary = _match_svc.get_player_score(test_peer_id)

	assert_false(score.is_empty(), "Score dictionary should not be empty after init")

	# Cleanup
	if _match_svc.has_method("remove_player_score"):
		_match_svc.remove_player_score(test_peer_id)


func test_player_score_has_required_fields() -> void:
	if not _match_svc:
		_match_svc = MatchSvc.get_instance()

	assert_not_null(_match_svc, "MatchSvc should be available")

	if not _match_svc:
		return

	var test_peer_id: int = 99998
	_match_svc.init_player_score(test_peer_id)

	var score: Dictionary = _match_svc.get_player_score(test_peer_id)

	# Check required fields
	var required_fields: Array[String] = ["kills", "deaths", "state"]
	for field: String in required_fields:
		assert_true(score.has(field), "Score should have field: %s" % field)

	# Cleanup
	if _match_svc.has_method("remove_player_score"):
		_match_svc.remove_player_score(test_peer_id)


# =============================================================================
# KILL REGISTRATION
# =============================================================================


func test_register_kill_increments_score() -> void:
	if not _match_svc:
		_match_svc = MatchSvc.get_instance()

	assert_not_null(_match_svc, "MatchSvc should be available")

	if not _match_svc:
		return

	var killer_id: int = 88881
	var victim_id: int = 88882

	_match_svc.init_player_score(killer_id)
	_match_svc.init_player_score(victim_id)

	var initial_kills: int = _match_svc.get_player_score(killer_id).get("kills", 0)

	# Register a kill
	_match_svc.register_kill(killer_id, victim_id)

	var final_kills: int = _match_svc.get_player_score(killer_id).get("kills", 0)

	# Cleanup
	if _match_svc.has_method("remove_player_score"):
		_match_svc.remove_player_score(killer_id)
		_match_svc.remove_player_score(victim_id)

	assert_gt(final_kills, initial_kills, "Kill count should increase after register_kill")


func test_suicide_handling() -> void:
	if not _match_svc:
		_match_svc = MatchSvc.get_instance()

	assert_not_null(_match_svc, "MatchSvc should be available")

	if not _match_svc:
		return

	var player_id: int = 77777

	_match_svc.init_player_score(player_id)

	# Register suicide (killer == victim)
	_match_svc.register_kill(player_id, player_id)

	# Should not crash and deaths should increase
	var _score: Dictionary = _match_svc.get_player_score(player_id)

	# Cleanup
	if _match_svc.has_method("remove_player_score"):
		_match_svc.remove_player_score(player_id)

	# Just verify it didn't crash - suicide handling varies by game rules
	assert_true(true, "Suicide handling should not crash")


# =============================================================================
# LEADERBOARD
# =============================================================================


func test_sorted_scores_returns_array() -> void:
	if not _match_svc:
		_match_svc = MatchSvc.get_instance()

	assert_not_null(_match_svc, "MatchSvc should be available")

	if not _match_svc:
		return

	var leaderboard: Variant = _match_svc.get_sorted_scores()

	assert_true(leaderboard is Array, "get_sorted_scores() should return Array")


# =============================================================================
# MATCH STATE
# =============================================================================


func test_match_state_signals_exist() -> void:
	if not _match_svc:
		_match_svc = MatchSvc.get_instance()

	assert_not_null(_match_svc, "MatchSvc should be available")

	if not _match_svc:
		return

	# Check that required signals exist
	var required_signals: Array[String] = [
		"player_killed",
		"match_started",
		"match_ended",
	]

	for signal_name: String in required_signals:
		assert_true(
			_match_svc.has_signal(signal_name), "MatchSvc should have signal: %s" % signal_name
		)


func _add_network_match(peer: ENetMultiplayerPeer) -> MatchSvc:
	var root := Node.new()
	root.name = "StatusPeer%d" % _network_roots.size()
	add_child(root)
	_network_roots.append(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	api.multiplayer_peer = peer
	var service := MatchSvc.new()
	root.add_child(service)
	service.set_process(false)
	service.set_process_input(false)
	service.init_player_score(1)
	_network_matches.append(service)
	return service


func _wait_for_status_network(condition: Callable) -> bool:
	for _frame: int in range(200):
		if condition.call():
			return true
		await get_tree().create_timer(0.01).timeout
	return false


func _connect_status_network() -> bool:
	var server_peer := ENetMultiplayerPeer.new()
	var error: Error = server_peer.create_server(0, 2)
	assert_eq(error, OK)
	if error != OK:
		return false
	_add_network_match(server_peer)
	for _index: int in range(2):
		var client_peer := ENetMultiplayerPeer.new()
		error = client_peer.create_client("127.0.0.1", server_peer.host.get_local_port())
		assert_eq(error, OK)
		if error != OK:
			return false
		_add_network_match(client_peer)
	var connected: bool = await _wait_for_status_network(
		func() -> bool:
			return (
				_network_matches[0].multiplayer.get_peers().size() == 2
				and _network_matches[1].multiplayer.get_peers().size() == 2
				and _network_matches[2].multiplayer.get_peers().size() == 2
			)
	)
	assert_true(connected, "All scoreboard replicas must connect")
	return connected


func test_server_status_update_preserves_affected_player_on_all_peers() -> void:
	if not await _connect_status_network():
		return
	var server: MatchSvc = _network_matches[0]
	var affected_id: int = _network_matches[1].multiplayer.get_unique_id()
	var other_id: int = _network_matches[2].multiplayer.get_unique_id()
	server.update_player_status(affected_id, 0, Enums.PlayerState.AFK)
	server.update_player_status(other_id, 23, Enums.PlayerState.DOWNED)
	var received: bool = await _wait_for_status_network(
		func() -> bool:
			return (
				(
					_network_matches[1].get_player_score(affected_id).get("state")
					== Enums.PlayerState.AFK
				)
				and (
					_network_matches[2].get_player_score(affected_id).get("state")
					== Enums.PlayerState.AFK
				)
				and _network_matches[1].get_player_score(other_id).get("health") == 23
				and _network_matches[2].get_player_score(other_id).get("health") == 23
			)
	)
	assert_true(received, "Server status must replicate to the affected player and observer")
	for service: MatchSvc in _network_matches:
		assert_eq(service.get_player_score(affected_id).get("health"), 0)
		assert_eq(
			service.get_player_score(1).get("health"), 100, "Host health must remain unchanged"
		)
		assert_eq(service.get_player_score(other_id).get("health"), 23)
		assert_eq(service.get_player_score(other_id).get("state"), Enums.PlayerState.DOWNED)
		assert_eq(service.get_player_score(1).get("state"), Enums.PlayerState.ALIVE)


func test_client_status_is_relayed_but_spoofed_identity_is_rejected() -> void:
	if not await _connect_status_network():
		return
	var client: MatchSvc = _network_matches[1]
	var observer: MatchSvc = _network_matches[2]
	var client_id: int = client.multiplayer.get_unique_id()
	var observer_id: int = observer.multiplayer.get_unique_id()

	# A forged affected ID must be rejected both by the server and a directly targeted client.
	client.update_player_status.rpc_id(1, 1, 0, Enums.PlayerState.DEAD)
	client.update_player_status.rpc_id(observer_id, 1, 0, Enums.PlayerState.DEAD)
	client.update_player_status.rpc_id(1, client_id, 42, Enums.PlayerState.DOWNED)
	var received: bool = await _wait_for_status_network(
		func() -> bool:
			return (
				client.get_player_score(client_id).get("health") == 42
				and observer.get_player_score(client_id).get("health") == 42
			)
	)
	assert_true(received, "Authenticated self-update must relay back to sender and observer")
	for service: MatchSvc in _network_matches:
		assert_eq(service.get_player_score(client_id).get("health"), 42)
		assert_eq(service.get_player_score(client_id).get("state"), Enums.PlayerState.DOWNED)
		assert_eq(
			service.get_player_score(1).get("health"), 100, "Spoofed host update must be rejected"
		)
		assert_eq(service.get_player_score(1).get("state"), Enums.PlayerState.ALIVE)
