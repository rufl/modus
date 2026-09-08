extends ModusGutTestBase

## Unit Tests for PerformanceLogger
## Tests CSV file creation, format, statistical calculations, and GameManager integration

var logger: PerformanceLogger = null
var test_log_dir: String = "user://test_performance_logs"


func before_each() -> void:
	# Create fresh logger instance
	logger = PerformanceLogger.new()
	add_child_autofree(logger)

	# Clean up any existing test logs
	_cleanup_test_logs()


func after_each() -> void:
	# Stop logging if active
	if logger and logger.is_logging:
		logger.stop_logging()

	# Clean up test logs
	_cleanup_test_logs()


func _cleanup_test_logs() -> void:
	## Remove test log files
	if DirAccess.dir_exists_absolute(test_log_dir):
		var dir: DirAccess = DirAccess.open(test_log_dir)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()


## Test: CSV file creation and format
func test_csv_file_creation_and_format() -> void:
	# Start logging with custom session name
	var session_name: String = "test_session_csv"
	var file_path: String = logger.start_logging(session_name)

	# Verify file path returned
	assert_string_contains(file_path, session_name, "File path should contain session name")
	assert_string_ends_with(file_path, ".csv", "File should have .csv extension")

	# Verify file exists
	assert_true(FileAccess.file_exists(file_path), "CSV file should be created")

	# Stop logging to flush data
	logger.stop_logging()

	# Read and verify CSV format
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	assert_not_null(file, "Should be able to open CSV file for reading")

	if file:
		var header: String = file.get_line()
		assert_eq(
			header,
			"Time,FPS,FrameTime,Memory,ActivePools,VisibleEnemies",
			"CSV header should match expected format"
		)
		file.close()


## Test: Statistical calculations - average
func test_statistical_calculation_average() -> void:
	# Test average calculation with known values
	var test_samples: Array[float] = [10.0, 20.0, 30.0, 40.0, 50.0]
	var expected_avg: float = 30.0

	var calculated_avg: float = logger._calculate_average(test_samples)
	assert_almost_eq(calculated_avg, expected_avg, 0.01, "Average should be calculated correctly")


## Test: Statistical calculations - min
func test_statistical_calculation_min() -> void:
	# Test min calculation with known values
	var test_samples: Array[float] = [50.0, 10.0, 30.0, 20.0, 40.0]
	var expected_min: float = 10.0

	var calculated_min: float = logger._calculate_min(test_samples)
	assert_eq(calculated_min, expected_min, "Minimum should be calculated correctly")


## Test: Statistical calculations - max
func test_statistical_calculation_max() -> void:
	# Test max calculation with known values
	var test_samples: Array[float] = [10.0, 50.0, 30.0, 20.0, 40.0]
	var expected_max: float = 50.0

	var calculated_max: float = logger._calculate_max(test_samples)
	assert_eq(calculated_max, expected_max, "Maximum should be calculated correctly")


## Test: Statistical calculations with empty array
func test_statistical_calculations_empty_array() -> void:
	var empty_samples: Array[float] = []

	assert_eq(logger._calculate_average(empty_samples), 0.0, "Average of empty array should be 0")
	assert_eq(logger._calculate_min(empty_samples), 0.0, "Min of empty array should be 0")
	assert_eq(logger._calculate_max(empty_samples), 0.0, "Max of empty array should be 0")


## Test: Statistics summary generation
func test_statistics_summary_generation() -> void:
	# Start logging
	var session_name: String = "test_session_stats"
	var file_path: String = logger.start_logging(session_name)

	# Manually add some sample data
	logger.fps_samples = [60.0, 59.0, 58.0, 60.0, 61.0]
	logger.memory_samples = [100.0, 105.0, 110.0, 108.0, 102.0]
	logger.frame_time_samples = [16.67, 16.95, 17.24, 16.67, 16.39]
	logger.frame_count = 5

	# Stop logging (triggers statistics write)
	logger.stop_logging()

	# Read file and verify statistics section
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	assert_not_null(file, "Should be able to open file")

	if file:
		var content: String = file.get_as_text()
		file.close()

		# Verify statistics section exists
		assert_string_contains(content, "# Statistics", "Should contain statistics section")
		assert_string_contains(content, "avg_fps", "Should contain avg_fps")
		assert_string_contains(content, "min_fps", "Should contain min_fps")
		assert_string_contains(content, "max_fps", "Should contain max_fps")
		assert_string_contains(content, "avg_frame_time", "Should contain avg_frame_time")
		assert_string_contains(content, "max_frame_time", "Should contain max_frame_time")
		assert_string_contains(content, "avg_memory", "Should contain avg_memory")
		assert_string_contains(content, "max_memory", "Should contain max_memory")
		assert_string_contains(content, "total_frames", "Should contain total_frames")
		assert_string_contains(content, "duration", "Should contain duration")


## Test: Integration with GameManager services (graceful handling when unavailable)
func test_gamemanager_integration_graceful_fallback() -> void:
	# Test that logger handles missing GameManager gracefully
	# This should not crash even if GameManager is not available

	var active_pools: int = logger._get_active_pool_count()
	var visible_enemies: int = logger._get_visible_enemy_count()

	# Should return 0 when services unavailable, not crash
	assert_gte(active_pools, 0, "Should return non-negative pool count")
	assert_gte(visible_enemies, 0, "Should return non-negative enemy count")


## Test: Logging start/stop signals
func test_logging_signals() -> void:
	var received := {"started": false, "stopped": false, "session_name": "", "file_path": ""}

	# Mutable dictionary state survives callback closure assignment.
	logger.logging_started.connect(
		func(session: String) -> void:
			received.started = true
			received.session_name = session
	)

	logger.logging_stopped.connect(
		func(_session: String, path: String) -> void:
			received.stopped = true
			received.file_path = path
	)

	# Start and stop logging
	var session_name: String = "test_signals"
	var file_path: String = logger.start_logging(session_name)
	logger.stop_logging()

	# Verify signals
	assert_true(received.started, "logging_started signal should be emitted")
	assert_true(received.stopped, "logging_stopped signal should be emitted")
	assert_eq(received.session_name, session_name, "Signal should contain correct session name")
	assert_string_contains(
		received.file_path, session_name, "Signal should contain correct file path"
	)


## Test: Get current statistics without stopping
func test_get_current_statistics() -> void:
	# Start logging
	logger.start_logging("test_current_stats")

	# Add sample data
	logger.fps_samples = [60.0, 59.0, 61.0]
	logger.memory_samples = [100.0, 105.0, 102.0]
	logger.frame_time_samples = [16.67, 16.95, 16.39]
	logger.frame_count = 3

	# Get statistics while still logging
	var stats: Dictionary = logger.get_current_statistics()

	# Verify statistics returned
	assert_true(stats.has("avg_fps"), "Should have avg_fps")
	assert_true(stats.has("min_fps"), "Should have min_fps")
	assert_true(stats.has("max_fps"), "Should have max_fps")
	assert_true(stats.has("avg_memory"), "Should have avg_memory")
	assert_true(stats.has("max_memory"), "Should have max_memory")
	assert_true(stats.has("avg_frame_time"), "Should have avg_frame_time")
	assert_true(stats.has("max_frame_time"), "Should have max_frame_time")
	assert_true(stats.has("frame_count"), "Should have frame_count")
	assert_true(stats.has("duration"), "Should have duration")

	# Verify values are reasonable
	assert_almost_eq(stats.avg_fps, 60.0, 1.0, "Average FPS should be around 60")
	assert_eq(stats.frame_count, 3, "Frame count should match")

	# Logger should still be active
	assert_true(logger.is_logging, "Logger should still be active after getting stats")

	logger.stop_logging()


## Test: Prevent double start
func test_prevent_double_start() -> void:
	# Start logging
	var file_path1: String = logger.start_logging("test_double_start")
	assert_ne(file_path1, "", "First start should succeed")

	# Try to start again
	var file_path2: String = logger.start_logging("test_double_start_2")
	assert_eq(file_path2, "", "Second start should fail and return empty string")

	# Should still be logging the first session
	assert_true(logger.is_logging, "Should still be logging")

	logger.stop_logging()


## Test: Auto-generated session name
func test_auto_generated_session_name() -> void:
	# Start logging without providing session name
	var file_path: String = logger.start_logging("")

	# Should generate a session name with timestamp format
	assert_ne(file_path, "", "Should generate file path")
	assert_string_contains(file_path, "session_", "Should contain 'session_' prefix")

	logger.stop_logging()
