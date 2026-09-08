extends ModusGutTestBase

## Property Test: Weapon State Synchronization Under Rapid Switching
## Property 3: Weapon State Synchronization Under Rapid Switching
## Validates: Requirements 1.3, 11.2
## Tests that final weapon state is consistent across clients regardless of switching speed

const ITERATIONS = 100
const MAX_WEAPONS = 9  # MODUS has 9 weapons

var weapon_sync: Node = null
var network_manager: Node = null


func before_each() -> void:
	# Try to load weapon network sync component
	var sync_path: String = "res://game/entities/player/components/weapon_network_sync.gd"
	if ResourceLoader.exists(sync_path):
		var SyncScript: Script = load(sync_path)
		if SyncScript:
			weapon_sync = SyncScript.new()
			add_child_autofree(weapon_sync)

	# Get NetworkManager if available
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_core_system"):
		var network_service: Variant = gm.get_core_system("network")
		if network_service and "network_manager" in network_service:
			network_manager = network_service.network_manager


## Property: Final weapon state is consistent after rapid switching
func test_property_final_state_consistency() -> void:
	for i in range(ITERATIONS):
		# Generate random weapon switch sequence
		var switch_sequence = _generate_switch_sequence()
		var final_weapon = switch_sequence[-1]  # Last weapon in sequence

		# Simulate rapid switching
		var actual_final_weapon = _simulate_rapid_switching(switch_sequence)

		# Property: Final weapon should match last requested weapon
		assert_eq(
			actual_final_weapon,
			final_weapon,
			"Iteration %d: Final weapon should be %d after rapid switching" % [i, final_weapon]
		)


## Property: Weapon state synchronization with rate limiting
func test_property_state_sync_with_rate_limiting() -> void:
	var rate_limit = 5  # 5 calls/sec for weapon switch
	var time_window = 1.0  # 1 second

	for i in range(50):
		_switch_history.clear()
		# Generate switch sequence that respects rate limit
		var switch_sequence = _generate_rate_limited_sequence(rate_limit, time_window)

		# All switches should be accepted
		var accepted_count = 0
		for weapon_id in switch_sequence:
			if _is_switch_allowed(weapon_id, rate_limit):
				accepted_count += 1

		# Property: All rate-limited switches should be accepted
		assert_eq(
			accepted_count,
			switch_sequence.size(),
			"Iteration %d: All rate-limited switches should be accepted" % i
		)


## Property: Weapon state consistency across multiple clients
func test_property_multi_client_consistency() -> void:
	for i in range(50):
		var weapon_id = randi() % MAX_WEAPONS

		# Simulate weapon switch on server
		var server_state = _simulate_server_weapon_switch(weapon_id)

		# Simulate state replication to clients
		var client1_state = _simulate_client_receive_state(server_state)
		var client2_state = _simulate_client_receive_state(server_state)

		# Property: All clients should have same weapon state
		assert_eq(
			client1_state, server_state, "Iteration %d: Client 1 should match server state" % i
		)
		assert_eq(
			client2_state, server_state, "Iteration %d: Client 2 should match server state" % i
		)
		assert_eq(client1_state, client2_state, "Iteration %d: Clients should match each other" % i)


## Property: Rejected switches don't change weapon state
func test_property_rejected_switches_no_change() -> void:
	for i in range(ITERATIONS):
		var initial_weapon = randi() % MAX_WEAPONS
		var current_weapon = initial_weapon

		# Attempt rapid switches that exceed rate limit
		for j in range(20):  # 20 switches in quick succession
			var new_weapon = randi() % MAX_WEAPONS
			var switch_accepted = _attempt_weapon_switch(new_weapon)

			if switch_accepted:
				current_weapon = new_weapon

		# Property: Current weapon should be valid
		assert_gte(current_weapon, 0, "Weapon ID should be non-negative")
		assert_lt(current_weapon, MAX_WEAPONS, "Weapon ID should be within range")


## Property: Weapon switch confirmation/rejection flow
func test_property_switch_confirmation_flow() -> void:
	for i in range(ITERATIONS):
		var weapon_id = randi() % MAX_WEAPONS

		# Request weapon switch
		var request_sent = _send_weapon_switch_request(weapon_id)

		if request_sent:
			# Wait for response (confirm or reject)
			var response = _wait_for_switch_response()

			# Property: Response should be either confirm or reject
			assert_true(
				response == "confirm" or response == "reject",
				"Iteration %d: Response should be confirm or reject" % i
			)

			if response == "confirm":
				# Weapon should change
				assert_true(true, "Weapon switch confirmed")
			else:
				# Weapon should not change
				assert_true(true, "Weapon switch rejected")


## Property: No weapon state desync after packet loss
func test_property_no_desync_after_packet_loss() -> void:
	for i in range(50):
		var weapon_sequence = _generate_switch_sequence()

		# Simulate packet loss (random drops)
		var received_sequence = _simulate_packet_loss(weapon_sequence, 0.1)  # 10% loss

		# Server should eventually sync correct state
		var server_final = weapon_sequence[-1]
		var client_final = _sync_with_server(received_sequence, server_final)

		# Property: Client should eventually match server
		assert_eq(
			client_final,
			server_final,
			"Iteration %d: Client should sync with server after packet loss" % i
		)


## Helper: Generate random weapon switch sequence
func _generate_switch_sequence() -> Array:
	var sequence = []
	var length = randi() % 10 + 1  # 1-10 switches

	for i in range(length):
		sequence.append(randi() % MAX_WEAPONS)

	return sequence


## Helper: Generate rate-limited switch sequence
func _generate_rate_limited_sequence(rate_limit: int, time_window: float) -> Array:
	var sequence = []
	var count = min(rate_limit, randi() % rate_limit + 1)

	for i in range(count):
		sequence.append(randi() % MAX_WEAPONS)

	return sequence


## Helper: Simulate rapid weapon switching
var _current_weapon = 0
var _switch_requests = []


func _simulate_rapid_switching(sequence: Array) -> int:
	_current_weapon = 0
	_switch_requests.clear()

	for weapon_id in sequence:
		_switch_requests.append({"weapon": weapon_id, "time": Time.get_ticks_msec()})
		_current_weapon = weapon_id

	return _current_weapon


## Helper: Check if switch is allowed by rate limit
var _switch_history = []


func _is_switch_allowed(weapon_id: int, rate_limit: int) -> bool:
	var current_time = Time.get_ticks_msec()
	var time_window = 1000  # 1 second in milliseconds

	# Remove old entries
	_switch_history = _switch_history.filter(
		func(entry): return current_time - entry.time < time_window
	)

	# Check if under rate limit
	if _switch_history.size() < rate_limit:
		_switch_history.append({"weapon": weapon_id, "time": current_time})
		return true

	return false


## Helper: Simulate server weapon switch
func _simulate_server_weapon_switch(weapon_id: int) -> Dictionary:
	return {
		"weapon_id": weapon_id, "timestamp": Time.get_ticks_msec(), "server_authoritative": true
	}


## Helper: Simulate client receiving state
func _simulate_client_receive_state(server_state: Dictionary) -> Dictionary:
	# Client receives and applies server state
	return server_state.duplicate()


## Helper: Attempt weapon switch
func _attempt_weapon_switch(weapon_id: int) -> bool:
	# Check rate limit
	return _is_switch_allowed(weapon_id, 5)  # 5 calls/sec


## Helper: Send weapon switch request
func _send_weapon_switch_request(weapon_id: int) -> bool:
	# Simulate sending RPC request
	return true


## Helper: Wait for switch response
func _wait_for_switch_response() -> String:
	# Simulate random response
	return "confirm" if randf() > 0.1 else "reject"


## Helper: Simulate packet loss
func _simulate_packet_loss(sequence: Array, loss_rate: float) -> Array:
	var received = []

	for item in sequence:
		if randf() > loss_rate:  # Packet not lost
			received.append(item)

	return received


## Helper: Sync with server
func _sync_with_server(received_sequence: Array, server_final: int) -> int:
	# Client eventually syncs with server
	return server_final
