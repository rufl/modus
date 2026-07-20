extends PropertyBasedTesting

## Property-Based Test: GameManager State Transitions
## Feature: architecture-refactoring, Property: Valid state transitions
## Validates: Requirements 2.1

const GameManager = preload("res://game/scripts/core/game_manager.gd")

# Valid state transitions based on GameManager design
# INITIALIZING -> READY (via initialize())
# READY -> RUNNING (via change_state())
# RUNNING -> PAUSED (via change_state())
# PAUSED -> RUNNING (via change_state())
# Any state -> SHUTTING_DOWN (via shutdown())
const VALID_TRANSITIONS = {
	0: [1, 4],  # INITIALIZING -> READY or SHUTTING_DOWN
	1: [2, 4],  # READY -> RUNNING or SHUTTING_DOWN
	2: [3, 4],  # RUNNING -> PAUSED or SHUTTING_DOWN
	3: [2, 4],  # PAUSED -> RUNNING or SHUTTING_DOWN
	4: []       # SHUTTING_DOWN -> (terminal state)
}


func test_property_valid_state_transitions():
	# Property: For any sequence of valid state transitions,
	# the GameManager should accept them and emit state_changed signals
	
	await run_enhanced_property_test(
		"Valid state transitions",
		_test_valid_transition_sequence,
		100,
		SamplingStrategy.MIXED,
		"GameManager should accept all valid state transitions"
	)


func _test_valid_transition_sequence(test_data: Dictionary) -> bool:
	var gm = GameManager.new()
	add_child_autofree(gm)
	
	# Generate a sequence of valid state transitions
	var rng = get_seeded_rng(test_data.get("iteration", 0))
	var transition_count = rng.randi_range(1, 10)
	
	var current_state = 0  # INITIALIZING
	var transitions_succeeded = true
	
	for i in range(transition_count):
		# Get valid next states for current state
		var valid_next_states = VALID_TRANSITIONS.get(current_state, [])
		
		if valid_next_states.is_empty():
			# Terminal state reached
			break
		
		# Pick a random valid next state
		var next_state = valid_next_states[rng.randi_range(0, valid_next_states.size() - 1)]
		
		# Perform the transition
		var old_state = gm.get_state()
		
		# Special handling for INITIALIZING -> READY transition
		if current_state == 0 and next_state == 1:
			gm.initialize()
		# Special handling for any state -> SHUTTING_DOWN
		elif next_state == 4:
			gm.shutdown()
		else:
			gm.change_state(next_state)
		
		# Verify the transition succeeded
		var new_state = gm.get_state()
		if new_state != next_state:
			transitions_succeeded = false
			break
		
		current_state = next_state
	
	return transitions_succeeded

func test_property_state_changed_signal_emission():

	# Property: For any valid state transition, the state_changed signal
	# should be emitted with correct old_state and new_state parameters
	
	await run_enhanced_property_test(
		"State changed signal emission",
		_test_state_changed_signal,
		100,
		SamplingStrategy.MIXED,
		"GameManager should emit state_changed signal for all transitions"
	)

func _test_state_changed_signal(test_data: Dictionary) -> bool:

	var gm = GameManager.new()
	var old_state = gm.get_state()
	var rng = get_seeded_rng(test_data.get("iteration", 0))
	
	# Track signal emissions
	var signal_state := {"emitted": false, "old": -1, "new": -1}
	
	gm.state_changed.connect(func(old_state, new_state):
		signal_state.emitted = true
		signal_state.old = old_state
		signal_state.new = new_state
	)
	add_child_autofree(gm)
	
	# Start in INITIALIZING, transition to READY
	gm.initialize()
	var new_state = gm.get_state()
	
	# Verify signal was emitted with correct parameters
	var result = signal_state.emitted and signal_state.old == old_state and signal_state.new == new_state
	
	return result


func test_property_same_state_no_signal():
	# Property: Transitioning to the same state should not emit state_changed signal
	
	await run_enhanced_property_test(
		"Same state no signal",
		_test_same_state_no_signal,
		100,
		SamplingStrategy.MIXED,
		"GameManager should not emit signal when transitioning to same state"
	)


func _test_same_state_no_signal(test_data: Dictionary) -> bool:
	var gm = GameManager.new()
	add_child_autofree(gm)
	
	# Initialize to READY state
	gm.initialize()
	var current_state = gm.get_state()
	
	# Track signal emissions
	var signal_count = 0
	gm.state_changed.connect(func(_old, _new):
		signal_count += 1
	)
	
	# Try to transition to the same state
	gm.change_state(current_state)
	
	# Verify no signal was emitted
	var result = signal_count == 0
	
	return result


func test_property_shutdown_from_any_state():
	# Property: shutdown() should work from any state and transition to SHUTTING_DOWN
	
	await run_enhanced_property_test(
		"Shutdown from any state",
		_test_shutdown_from_any_state,
		100,
		SamplingStrategy.MIXED,
		"GameManager should shutdown from any state"
	)


func _test_shutdown_from_any_state(test_data: Dictionary) -> bool:
	var gm = GameManager.new()
	add_child_autofree(gm)
	
	var rng = get_seeded_rng(test_data.get("iteration", 0))
	
	# Randomly transition to a state
	var target_state = rng.randi_range(0, 3)  # Don't start in SHUTTING_DOWN
	
	match target_state:
		0:  # INITIALIZING (default)
			pass
		1:  # READY
			gm.initialize()
		2:  # RUNNING
			gm.initialize()
			gm.change_state(2)
		3:  # PAUSED
			gm.initialize()
			gm.change_state(2)
			gm.change_state(3)
	
	# Now shutdown from this state
	gm.shutdown()
	
	# Verify we're in SHUTTING_DOWN state
	var result = gm.get_state() == 4
	
	return result


func test_property_initialize_idempotent():
	# Property: Calling initialize() multiple times should be idempotent
	# (only the first call should have effect)
	
	await run_enhanced_property_test(
		"Initialize idempotent",
		_test_initialize_idempotent,
		100,
		SamplingStrategy.MIXED,
		"GameManager initialize() should be idempotent"
	)


func _test_initialize_idempotent(test_data: Dictionary) -> bool:
	var gm = GameManager.new()
	add_child_autofree(gm)
	
	var rng = get_seeded_rng(test_data.get("iteration", 0))
	var call_count = rng.randi_range(2, 10)
	
	# Call initialize multiple times
	for i in range(call_count):
		gm.initialize()
	
	# Should still be in READY state
	var result = gm.get_state() == 1
	
	return result


func test_property_state_transition_sequence_consistency():
	# Property: A sequence of state transitions should result in predictable final state
	
	await run_enhanced_property_test(
		"State transition sequence consistency",
		_test_transition_sequence_consistency,
		100,
		SamplingStrategy.MIXED,
		"GameManager state transitions should be consistent"
	)


func _test_transition_sequence_consistency(test_data: Dictionary) -> bool:
	var gm = GameManager.new()
	add_child_autofree(gm)
	
	# Perform a known sequence: INITIALIZING -> READY -> RUNNING -> PAUSED -> RUNNING
	gm.initialize()  # INITIALIZING -> READY
	if gm.get_state() != 1:
		return false
	
	gm.change_state(2)  # READY -> RUNNING
	if gm.get_state() != 2:
		return false
	
	gm.change_state(3)  # RUNNING -> PAUSED
	if gm.get_state() != 3:
		return false
	
	gm.change_state(2)  # PAUSED -> RUNNING
	if gm.get_state() != 2:
		return false
	
	return true
