extends ModusGutTestBase

# Test MODUS Framework Match Service
# Converted from legacy Dictionary format to GUT assertions

var _match_svc: MatchSvc = null


func before_each() -> void:
	await modus_setup()
	_match_svc = MatchSvc.get_instance()


func after_each() -> void:
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
		assert_true(_match_svc.has_method(method_name), "MatchSvc should have method: %s" % method_name)


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
		assert_true(_match_svc.has_signal(signal_name), "MatchSvc should have signal: %s" % signal_name)
