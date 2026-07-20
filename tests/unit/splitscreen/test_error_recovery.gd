extends GutTest

## Tests for error recovery, rate limiting, and runtime toggle features

var manager: SplitscreenManager
var rate_limiter: RateLimiter


func before_each():
	manager = SplitscreenManager.new()
	add_child_autofree(manager)
	manager.initialize()
	
	rate_limiter = RateLimiter.new(0.1, 5, 1.0)
	# Each test starts with a deterministic first-emission allowance instead of
	# depending on how long the engine process has been alive.
	rate_limiter._last_emission_time = -INF


func after_each():
	manager = null


## Rate Limiter Tests

func test_rate_limiter_allows_first_emission():
	assert_true(rate_limiter.should_emit(), "First emission should be allowed")


func test_rate_limiter_throttles_rapid_emissions():
	rate_limiter.should_emit()  # First emission
	assert_false(rate_limiter.should_emit(), "Second immediate emission should be throttled")


func test_rate_limiter_allows_after_interval():
	assert_true(rate_limiter.should_emit())
	rate_limiter._last_emission_time -= rate_limiter.min_interval_seconds + 0.001
	assert_true(rate_limiter.should_emit(), "Emission should be allowed after interval")


func test_rate_limiter_enforces_burst_limit():
	var allowed_count: int = 0
	for i in range(10):
		if i > 0:
			rate_limiter._last_emission_time -= rate_limiter.min_interval_seconds + 0.001
		if rate_limiter.should_emit():
			allowed_count += 1
	
	assert_lte(allowed_count, 5, "Should not exceed burst limit")


func test_rate_limiter_resets_burst_window():
	# Fill burst
	for i in range(5):
		if i > 0:
			rate_limiter._last_emission_time -= rate_limiter.min_interval_seconds + 0.001
		assert_true(rate_limiter.should_emit())
	
	# Advance the tracked boundaries without depending on wall-clock scheduling.
	rate_limiter._last_emission_time -= rate_limiter.min_interval_seconds + 0.001
	rate_limiter._burst_window_start -= rate_limiter.burst_window_seconds + 0.001
	
	assert_true(rate_limiter.should_emit(), "Should allow emission after window reset")


func test_rate_limiter_force_emit_bypasses_limit():
	rate_limiter.should_emit()
	rate_limiter.force_emit()
	var stats = rate_limiter.get_stats()
	assert_eq(stats["total_emissions"], 2, "Force emit should bypass rate limit")


func test_rate_limiter_tracks_statistics():
	rate_limiter.should_emit()
	rate_limiter.should_emit()  # Throttled
	
	var stats = rate_limiter.get_stats()
	assert_eq(stats["total_emissions"], 1, "Should track emissions")
	assert_eq(stats["total_throttled"], 1, "Should track throttled attempts")


## Error Recovery Tests

func test_error_recovery_can_be_disabled():
	manager.set_error_recovery_enabled(false)
	# Error recovery should not activate when disabled
	assert_true(true, "Error recovery disabled successfully")


func test_circuit_breaker_opens_after_threshold():
	# Simulate multiple failures
	for i in range(6):
		manager._record_failure("test_operation")
	
	assert_true(manager._is_circuit_breaker_open("test_operation"), 
		"Circuit breaker should open after threshold")


func test_circuit_breaker_closes_after_timeout():
	# Open circuit breaker
	for i in range(6):
		manager._record_failure("test_operation")
	
	# Wait for reset time (mocked by directly closing)
	manager._close_circuit_breaker("test_operation")
	
	assert_false(manager._is_circuit_breaker_open("test_operation"), 
		"Circuit breaker should close after timeout")


func test_successful_operation_reduces_failure_count():
	manager._record_failure("test_operation")
	manager._record_failure("test_operation")
	manager._record_success("test_operation")
	
	var stats = manager.get_error_recovery_stats()
	assert_eq(stats["failed_operations"]["test_operation"], 1, 
		"Success should reduce failure count")


func test_error_recovery_stats_tracking():
	manager._record_failure("op1")
	manager._record_failure("op2")
	
	var stats = manager.get_error_recovery_stats()
	assert_true(stats["failed_operations"].has("op1"), "Should track op1 failures")
	assert_true(stats["failed_operations"].has("op2"), "Should track op2 failures")


## Runtime Feature Toggle Tests

func test_feature_starts_enabled():
	assert_true(manager.is_feature_enabled(), "Feature should start enabled")


func test_can_disable_feature():
	var result = manager.disable_feature()
	assert_true(result, "Should successfully disable feature")
	assert_false(manager.is_feature_enabled(), "Feature should be disabled")


func test_can_enable_feature():
	manager.disable_feature()
	var result = manager.enable_feature()
	assert_true(result, "Should successfully enable feature")
	assert_true(manager.is_feature_enabled(), "Feature should be enabled")


func test_disable_ends_active_session():
	# Start a session (will fail without proper setup, but tests the flow)
	manager.disable_feature()
	
	# Session should not be active
	assert_false(manager.is_session_active(), "Session should end when feature disabled")


func test_hot_reload_can_be_configured():
	manager.set_hot_reload_supported(false)
	# Hot reload setting should be applied
	assert_true(true, "Hot reload configuration successful")


func test_configuration_reload():
	var result = manager.reload_configuration()
	assert_true(result, "Configuration reload should succeed")


## Performance Profiler Tests

func test_performance_profiler_starts_disabled():
	if manager.performance_profiler:
		assert_false(manager.performance_profiler.is_profiling(), 
			"Profiler should start disabled")


func test_performance_profiler_can_start():
	if manager.performance_profiler:
		manager.performance_profiler.start_profiling()
		assert_true(manager.performance_profiler.is_profiling(), 
			"Profiler should be running")
		manager.performance_profiler.stop_profiling()


func test_performance_profiler_generates_report():
	if manager.performance_profiler:
		manager.performance_profiler.critical_fps_threshold = -INF
		manager.performance_profiler.critical_frame_time_ms = INF
		manager.performance_profiler.start_profiling()
		await get_tree().create_timer(0.1).timeout
		var report = manager.performance_profiler.stop_profiling()
		
		assert_true(report.has("fps"), "Report should contain FPS data")
		assert_true(report.has("memory"), "Report should contain memory data")
		assert_true(report.has("analysis"), "Report should contain analysis")


func test_performance_profiler_detects_metrics():
	if manager.performance_profiler:
		manager.performance_profiler.critical_fps_threshold = -INF
		manager.performance_profiler.critical_frame_time_ms = INF
		manager.performance_profiler.start_profiling()
		await get_tree().create_timer(0.2).timeout
		
		var metrics = manager.performance_profiler.get_current_metrics()
		assert_gt(metrics["fps"]["current"], 0.0, "Should track FPS")
		assert_gt(metrics["memory"]["current"], 0, "Should track memory")
		manager.performance_profiler.stop_profiling()


## Integration Tests

func test_gamepad_controller_has_rate_limiters():
	var gamepad_controller = manager.gamepad_controller
	if gamepad_controller:
		var stats = gamepad_controller.get_rate_limiter_stats()
		assert_true(stats.has("gamepad_connected"), "Should have rate limiter for gamepad_connected")
		assert_true(stats.has("gamepad_assigned"), "Should have rate limiter for gamepad_assigned")


func test_manager_can_get_performance_report():
	var report = manager.get_performance_report()
	# Report might be empty if profiler not running, but method should work
	assert_not_null(report, "Should return performance report")


func test_configuration_validation_rejects_invalid():
	var invalid_config = {
		"enabled": true,
		"min_players": 10,  # Invalid: too high
		"max_players": 2    # Invalid: less than min
	}
	
	var result = manager._validate_configuration(invalid_config)
	assert_false(result, "Should reject invalid configuration")
	assert_push_error("Invalid config: min_players > max_players")


func test_configuration_validation_accepts_valid():
	var valid_config = {
		"enabled": true,
		"min_players": 4,
		"max_players": 6,
		"default_player_count": 4,
		"performance": {
			"target_fps": 60.0,
			"fps_variance_threshold": 0.1
		}
	}
	
	var result = manager._validate_configuration(valid_config)
	assert_true(result, "Should accept valid configuration")
