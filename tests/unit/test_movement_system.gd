extends GutTest

## Unit tests for MODUS Movement System
## Tests bunny hopping, air strafing, rocket jumping, slide, dodge, and speed calculations

const AdvancedMovementClass := preload("res://game/entities/player/advanced_movement.gd")
const RocketJumpSystemClass := preload("res://game/entities/player/rocket_jump_system.gd")
const DodgeSystemClass := preload("res://game/entities/player/dodge_system.gd")


class GroundedAdvancedMovement:
	extends AdvancedMovement
	var grounded_for_test: bool = false

	func _is_player_grounded() -> bool:
		return grounded_for_test


var player: CharacterBody3D
var advanced_movement: GroundedAdvancedMovement
var rocket_jump_system: RocketJumpSystemClass
var dodge_system: DodgeSystemClass


func before_each() -> void:
	# Create player character body
	player = CharacterBody3D.new()
	player.name = "TestPlayer"
	add_child_autofree(player)

	# Create advanced movement system
	advanced_movement = GroundedAdvancedMovement.new()
	advanced_movement.name = "AdvancedMovement"
	player.add_child(advanced_movement)

	# Create rocket jump system
	rocket_jump_system = RocketJumpSystem.new()
	rocket_jump_system.name = "RocketJumpSystem"
	player.add_child(rocket_jump_system)

	# Create dodge system
	dodge_system = DodgeSystem.new()
	dodge_system.name = "DodgeSystem"
	player.add_child(dodge_system)

	# Wait for ready
	await get_tree().process_frame


func test_navigation_stop_prevents_horizontal_slide_and_preserves_fall_velocity() -> void:
	var movement := MovementComponent.new()
	player.add_child(movement)
	# Allow deferred navigation initialization to finish before fixture teardown.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	movement.set_target_position(Vector3(100, 0, 100))
	movement.can_dash = true
	movement.dash(Vector3.RIGHT)
	player.velocity = Vector3(8, -4, 6)
	var start_position := player.global_position

	movement.stop()
	assert_eq(
		player.velocity, Vector3(0, -4, 0), "Stopping cancels horizontal momentum, not gravity"
	)
	await get_tree().physics_frame
	player.move_and_slide()
	assert_eq(player.global_position.x, start_position.x)
	assert_eq(player.global_position.z, start_position.z)
	assert_lt(player.global_position.y, start_position.y, "A stopped airborne body still falls")


# ============================================================================
# Bunny Hopping Tests
# ============================================================================


func test_bunny_hop_increases_speed() -> void:
	# Setup: Player on ground with horizontal velocity
	player.velocity = Vector3(5, 0, 0)
	var initial_speed: float = Vector2(player.velocity.x, player.velocity.z).length()

	# Simulate good timing (just landed)
	advanced_movement.ground_time = 0.05
	advanced_movement.grounded_for_test = true

	# Execute bunny hop
	var result_velocity: Vector3 = advanced_movement.try_bunny_hop(player.velocity, 5.5)
	var final_speed: float = Vector2(result_velocity.x, result_velocity.z).length()

	# Verify speed increased
	assert_gt(final_speed, initial_speed, "Bunny hop should increase horizontal speed")


func test_bunny_hop_respects_speed_cap() -> void:
	# Setup: Player at max speed
	player.velocity = Vector3(20, 0, 0)  # Above cap

	# Simulate good timing
	advanced_movement.ground_time = 0.05
	advanced_movement.grounded_for_test = true

	# Execute bunny hop
	var result_velocity: Vector3 = advanced_movement.try_bunny_hop(player.velocity, 5.5)
	var final_speed: float = Vector2(result_velocity.x, result_velocity.z).length()

	# Verify speed didn't increase beyond cap
	assert_lte(
		final_speed, advanced_movement.bhop_speed_cap + 1.0, "Bunny hop should respect speed cap"
	)


func test_bunny_hop_bad_timing_resets_chain() -> void:
	# Setup: Player with consecutive jumps
	advanced_movement.consecutive_jumps = 3
	advanced_movement.ground_time = 0.5  # Bad timing (too long on ground)
	advanced_movement.grounded_for_test = true

	# Execute bunny hop
	advanced_movement.try_bunny_hop(player.velocity, 5.5)

	# Verify chain reset
	assert_eq(
		advanced_movement.consecutive_jumps, 0, "Bad timing should reset consecutive jump chain"
	)


func test_bunny_hop_good_timing_increments_chain() -> void:
	# Setup: Player with good timing
	advanced_movement.consecutive_jumps = 2
	advanced_movement.ground_time = 0.05  # Good timing
	advanced_movement.grounded_for_test = true
	player.velocity = Vector3(5, 0, 0)

	# Execute bunny hop
	advanced_movement.try_bunny_hop(player.velocity, 5.5)

	# Verify chain incremented
	assert_eq(
		advanced_movement.consecutive_jumps, 3, "Good timing should increment consecutive jumps"
	)


func test_bunny_hop_emits_signal() -> void:
	# Setup
	watch_signals(advanced_movement)
	advanced_movement.ground_time = 0.05
	advanced_movement.grounded_for_test = true
	player.velocity = Vector3(5, 0, 0)

	# Execute bunny hop
	advanced_movement.try_bunny_hop(player.velocity, 5.5)

	# Verify signal emitted
	assert_signal_emitted(advanced_movement, "movement_technique_used")


# ============================================================================
# Air Strafing Tests
# ============================================================================


func test_air_strafe_allows_direction_change() -> void:
	# Setup: Player in air moving forward
	player.velocity = Vector3(0, 5, -10)
	var input_dir := Vector2(1, 0)  # Strafe right
	var wish_dir := Vector3(1, 0, 0).normalized()

	# Apply air movement
	var result: Vector3 = advanced_movement.apply_air_movement(
		player.velocity, input_dir, wish_dir, 0.016
	)

	# Verify horizontal velocity changed
	assert_gt(result.x, player.velocity.x, "Air strafe should allow direction change")


func test_air_strafe_respects_speed_cap() -> void:
	# Setup: Player at high speed
	player.velocity = Vector3(15, 5, 0)
	var input_dir := Vector2(1, 0)
	var wish_dir := Vector3(1, 0, 0).normalized()

	# Apply air movement multiple times
	for i: int in range(10):
		player.velocity = advanced_movement.apply_air_movement(
			player.velocity, input_dir, wish_dir, 0.016
		)

	# Verify speed capped
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	assert_lte(
		horizontal_speed,
		advanced_movement.max_air_speed + 1.0,
		"Air strafe should respect speed cap"
	)


func test_air_strafe_no_input_maintains_velocity() -> void:
	# Setup: Player in air with no input
	player.velocity = Vector3(5, 5, -5)
	var initial_velocity: Vector3 = player.velocity
	var input_dir := Vector2.ZERO
	var wish_dir := Vector3.ZERO

	# Apply air movement
	var result: Vector3 = advanced_movement.apply_air_movement(
		player.velocity, input_dir, wish_dir, 0.016
	)

	# Verify velocity mostly maintained (small changes from air control are ok)
	assert_almost_eq(
		result.x, initial_velocity.x, 0.5, "No input should maintain horizontal velocity"
	)


# ============================================================================
# Rocket Jumping Tests
# ============================================================================


func test_rocket_jump_applies_force() -> void:
	# Setup: Explosion near player
	var explosion_pos := Vector3(0, 0, 0)
	var player_pos := Vector3(2, 0, 2)
	var base_force := 10.0

	# Apply explosion force
	var boost: Vector3 = rocket_jump_system.apply_explosion_force(
		explosion_pos, player_pos, base_force
	)

	# Verify force applied
	assert_gt(boost.length(), 0.0, "Rocket jump should apply force")


func test_rocket_jump_direction_away_from_explosion() -> void:
	# Setup: Explosion below player
	var explosion_pos := Vector3(0, 0, 0)
	var player_pos := Vector3(0, 5, 0)
	var base_force := 10.0

	# Apply explosion force
	var boost: Vector3 = rocket_jump_system.apply_explosion_force(
		explosion_pos, player_pos, base_force
	)

	# Verify direction is upward (away from explosion)
	assert_gt(boost.y, 0.0, "Rocket jump should propel player away from explosion")


func test_rocket_jump_respects_max_velocity() -> void:
	# Setup: Very strong explosion
	var explosion_pos := Vector3(0, 0, 0)
	var player_pos := Vector3(0.5, 0, 0)  # Very close
	var base_force := 1000.0  # Huge force

	# Apply explosion force
	var boost: Vector3 = rocket_jump_system.apply_explosion_force(
		explosion_pos, player_pos, base_force
	)

	# Verify capped at max
	assert_lte(
		boost.length(),
		rocket_jump_system.max_boost_velocity + 0.1,
		"Rocket jump should respect max velocity"
	)


func test_rocket_jump_respects_min_velocity() -> void:
	# Setup: Weak explosion far away
	var explosion_pos := Vector3(0, 0, 0)
	var player_pos := Vector3(100, 0, 0)  # Very far
	var base_force := 1.0  # Weak force

	# Apply explosion force
	var boost: Vector3 = rocket_jump_system.apply_explosion_force(
		explosion_pos, player_pos, base_force
	)

	# Verify meets minimum
	assert_gte(
		boost.length(),
		rocket_jump_system.min_boost_velocity - 0.1,
		"Rocket jump should meet min velocity"
	)


func test_rocket_jump_sets_state() -> void:
	# Setup
	var explosion_pos := Vector3(0, 0, 0)
	var player_pos := Vector3(2, 0, 2)

	# Apply explosion force
	rocket_jump_system.apply_explosion_force(explosion_pos, player_pos, 10.0)

	# Verify state set
	assert_true(
		rocket_jump_system.is_rocket_jumping, "Rocket jump should set is_rocket_jumping state"
	)


func test_rocket_jump_emits_signal() -> void:
	# Setup
	watch_signals(rocket_jump_system)
	var explosion_pos := Vector3(0, 0, 0)
	var player_pos := Vector3(2, 0, 2)

	# Apply explosion force
	rocket_jump_system.apply_explosion_force(explosion_pos, player_pos, 10.0)

	# Verify signal emitted
	assert_signal_emitted(rocket_jump_system, "rocket_jump_performed")


func test_rocket_jump_increases_air_control() -> void:
	# Setup: Start rocket jump
	rocket_jump_system.is_rocket_jumping = true

	# Get air control modifier
	var modifier: float = rocket_jump_system.get_air_control_modifier()

	# Verify increased
	assert_gt(modifier, 1.0, "Rocket jump should increase air control")


func test_rocket_jump_uses_canonical_json5_config() -> void:
	var data: Variant = JSON5Loader.load_file(RocketJumpSystemClass.CONFIG_PATH)
	assert_true(data is Dictionary, "Canonical gameplay JSON5 should parse")
	if not data is Dictionary:
		return

	var movement: Dictionary = data.get("movement", {})
	var cfg: Dictionary = movement.get("rocket_jump", {})
	assert_false(cfg.is_empty(), "Canonical gameplay config should define rocket_jump")
	assert_almost_eq(
		rocket_jump_system.velocity_multiplier,
		float(cfg.get("velocity_multiplier", 0.0)),
		0.001,
		"Rocket jump velocity multiplier should match canonical config"
	)
	assert_almost_eq(
		rocket_jump_system.max_boost_velocity,
		float(cfg.get("max_boost_velocity", 0.0)),
		0.001,
		"Rocket jump maximum boost should match canonical config"
	)


# ============================================================================
# Slide Mechanics Tests
# ============================================================================


func test_slide_requires_minimum_speed() -> void:
	# Setup: Player moving slowly
	player.velocity = Vector3(1, 0, 0)
	var forward_dir := Vector3(0, 0, -1)
	advanced_movement.grounded_for_test = true

	# Try to start slide
	var result: bool = advanced_movement.try_start_slide(player.velocity, forward_dir)

	# Verify slide didn't start
	assert_false(result, "Slide should require minimum speed")


func test_slide_starts_with_sufficient_speed() -> void:
	# Setup: Player moving fast enough
	player.velocity = Vector3(5, 0, 0)
	var forward_dir := Vector3(1, 0, 0)
	advanced_movement.grounded_for_test = true

	# Try to start slide
	var result: bool = advanced_movement.try_start_slide(player.velocity, forward_dir)

	# Verify slide started
	assert_true(result, "Slide should start with sufficient speed")
	assert_true(advanced_movement.is_sliding, "Slide state should be set")


func test_slide_respects_cooldown() -> void:
	# Setup: Start slide
	player.velocity = Vector3(5, 0, 0)
	advanced_movement.grounded_for_test = true
	advanced_movement.try_start_slide(player.velocity, Vector3(1, 0, 0))

	# End slide early (public method)
	advanced_movement.end_slide_early()

	# Try to slide again immediately
	var result: bool = advanced_movement.try_start_slide(player.velocity, Vector3(1, 0, 0))

	# Verify blocked by cooldown
	assert_false(result, "Slide should respect cooldown")


func test_slide_applies_friction() -> void:
	# Setup: Start slide
	player.velocity = Vector3(10, 0, 0)
	advanced_movement.is_sliding = true
	advanced_movement.slide_direction = Vector3(1, 0, 0)
	var initial_speed: float = player.velocity.length()

	# Apply slide movement over time
	for i: int in range(10):
		player.velocity = advanced_movement.apply_slide_movement(player.velocity, 0.1)

	# Verify speed decreased
	assert_lt(player.velocity.length(), initial_speed, "Slide should apply friction")


func test_slide_emits_signal() -> void:
	# Setup
	watch_signals(advanced_movement)
	player.velocity = Vector3(5, 0, 0)
	advanced_movement.grounded_for_test = true

	# Start slide
	advanced_movement.try_start_slide(player.velocity, Vector3(1, 0, 0))

	# Verify signal emitted
	assert_signal_emitted(advanced_movement, "movement_technique_used")


func test_slide_can_be_ended_early() -> void:
	# Setup: Start slide
	player.velocity = Vector3(5, 0, 0)
	advanced_movement.grounded_for_test = true
	advanced_movement.try_start_slide(player.velocity, Vector3(1, 0, 0))

	# End slide early
	advanced_movement.end_slide_early()

	# Verify slide ended
	assert_false(advanced_movement.is_sliding, "Slide should be able to end early")


# ============================================================================
# Dodge Mechanics Tests
# ============================================================================


func test_dodge_starts_with_direction() -> void:
	# Setup
	var direction := Vector3(1, 0, 0).normalized()

	# Start dodge
	dodge_system._start_dodge(direction)

	# Verify dodge started
	assert_true(dodge_system.is_dodging, "Dodge should start")
	assert_eq(dodge_system.dodge_direction, direction, "Dodge direction should be set")


func test_dodge_applies_movement() -> void:
	# Setup: Start dodge
	dodge_system.is_dodging = true
	dodge_system.dodge_direction = Vector3(1, 0, 0)
	player.velocity = Vector3.ZERO

	# Apply dodge movement
	var result: Vector3 = dodge_system.apply_dodge_movement(player.velocity)

	# Verify movement applied
	assert_gt(result.x, 0.0, "Dodge should apply movement in dodge direction")


func test_dodge_respects_cooldown() -> void:
	# Setup: Start and end dodge
	dodge_system._start_dodge(Vector3(1, 0, 0))
	dodge_system._end_dodge()

	# Check if can dodge
	var can_dodge: bool = dodge_system.can_dodge()

	# Verify blocked by cooldown
	assert_false(can_dodge, "Dodge should respect cooldown")


func test_dodge_reduced_speed_in_air() -> void:
	# Setup: Player in air
	player.velocity = Vector3(0, 5, 0)  # In air (positive Y velocity)
	dodge_system.is_dodging = true
	dodge_system.dodge_direction = Vector3(1, 0, 0)

	# Apply dodge movement
	var result: Vector3 = dodge_system.apply_dodge_movement(player.velocity)

	# Calculate expected speed (should be reduced)
	var expected_speed: float = dodge_system.dodge_speed * dodge_system.air_dodge_speed_multiplier

	# Verify reduced speed
	assert_almost_eq(result.x, expected_speed, 0.1, "Air dodge should have reduced speed")


func test_dodge_emits_signal() -> void:
	# Setup
	watch_signals(dodge_system)

	# Start dodge
	dodge_system._start_dodge(Vector3(1, 0, 0))

	# Verify signal emitted
	assert_signal_emitted(dodge_system, "dodge_performed")


func test_dodge_can_be_disabled() -> void:
	# Setup: Disable dodge
	dodge_system.enable_dodge = false

	# Check if can dodge
	var can_dodge: bool = dodge_system.can_dodge()

	# Verify disabled
	assert_false(can_dodge, "Dodge should be able to be disabled")


# ============================================================================
# Movement Speed Calculations Tests
# ============================================================================


func test_movement_stats_tracking() -> void:
	# Setup: Set player velocity
	player.velocity = Vector3(10, 0, 5)

	# Update speed tracking
	advanced_movement._update_speed_tracking()

	# Get stats
	var stats: Dictionary = advanced_movement.get_movement_stats()

	# Verify stats tracked
	assert_true(stats.has("horizontal_speed"), "Stats should track horizontal speed")
	assert_gt(stats.horizontal_speed, 0.0, "Horizontal speed should be calculated")


func test_peak_speed_tracking() -> void:
	# Setup: Set increasing velocities
	player.velocity = Vector3(5, 0, 0)
	advanced_movement._update_speed_tracking()

	player.velocity = Vector3(10, 0, 0)
	advanced_movement._update_speed_tracking()

	player.velocity = Vector3(7, 0, 0)
	advanced_movement._update_speed_tracking()

	# Get stats
	var stats: Dictionary = advanced_movement.get_movement_stats()

	# Verify peak tracked
	assert_almost_eq(stats.peak_speed, 10.0, 0.1, "Peak speed should track maximum speed reached")


func test_peak_speed_can_be_reset() -> void:
	# Setup: Set peak speed
	player.velocity = Vector3(15, 0, 0)
	advanced_movement._update_speed_tracking()

	# Reset peak speed
	advanced_movement.reset_peak_speed()

	# Verify reset
	var stats: Dictionary = advanced_movement.get_movement_stats()
	assert_eq(stats.peak_speed, 0.0, "Peak speed should be resettable")


func test_slide_cooldown_percentage() -> void:
	# Setup: Start and end slide
	player.velocity = Vector3(5, 0, 0)
	advanced_movement.grounded_for_test = true
	advanced_movement.try_start_slide(player.velocity, Vector3(1, 0, 0))
	advanced_movement._end_slide()

	# Get cooldown percentage
	var cooldown_pct: float = advanced_movement.get_slide_cooldown_percent()

	# Verify percentage is valid
	assert_gte(cooldown_pct, 0.0, "Cooldown percentage should be >= 0")
	assert_lte(cooldown_pct, 1.0, "Cooldown percentage should be <= 1")


func test_dodge_cooldown_percentage() -> void:
	# Setup: Start and end dodge
	dodge_system._start_dodge(Vector3(1, 0, 0))
	dodge_system._end_dodge()

	# Get cooldown percentage
	var cooldown_pct: float = dodge_system.get_dodge_cooldown_percent()

	# Verify percentage is valid
	assert_gte(cooldown_pct, 0.0, "Cooldown percentage should be >= 0")
	assert_lte(cooldown_pct, 1.0, "Cooldown percentage should be <= 1")


func test_dodge_stats_dictionary() -> void:
	# Setup
	dodge_system.is_dodging = true

	# Get stats
	var stats: Dictionary = dodge_system.get_stats()

	# Verify stats structure
	assert_true(stats.has("is_dodging"), "Stats should have is_dodging")
	assert_true(stats.has("can_dodge"), "Stats should have can_dodge")
	assert_true(stats.has("cooldown_remaining"), "Stats should have cooldown_remaining")
	assert_true(stats.has("input_mode"), "Stats should have input_mode")


func test_movement_stats_dictionary() -> void:
	# Setup
	player.velocity = Vector3(8, 0, 0)
	advanced_movement._update_speed_tracking()

	# Get stats
	var stats: Dictionary = advanced_movement.get_movement_stats()

	# Verify stats structure
	assert_true(stats.has("horizontal_speed"), "Stats should have horizontal_speed")
	assert_true(stats.has("peak_speed"), "Stats should have peak_speed")
	assert_true(stats.has("is_sliding"), "Stats should have is_sliding")
	assert_true(stats.has("consecutive_bhops"), "Stats should have consecutive_bhops")
	assert_true(stats.has("can_slide"), "Stats should have can_slide")


func test_movement_dictionary_restores_acceleration_configuration() -> void:
	var movement := MovementComponent.new()
	player.add_child(movement)
	movement.configure({"move_speed": 8.0, "acceleration": 24.0})
	assert_eq(movement.speed, 8.0)
	assert_eq(movement.acceleration, 24.0)
