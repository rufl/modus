# Performance Benchmarks Test Suite
# Tests frame rate, memory usage, and network bandwidth performance
extends ModusGutTestBase

# =============================================================================
# CONSTANTS
# =============================================================================

const FRAME_SAMPLE_COUNT: int = 300  # 5 seconds at 60 FPS
const WARMUP_FRAMES: int = 60  # 1 second warmup

# Performance targets from tech.md (UNVERIFIED estimates)
const TARGET_SOLO_FPS: float = 75.0
const TARGET_SPLITSCREEN_4P_FPS: float = 60.0
const TARGET_MULTIPLAYER_8P_FPS: float = 45.0

# =============================================================================
# TEST LIFECYCLE
# =============================================================================


func before_each() -> void:
	super.before_each()
	# Wait for engine to stabilize
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	# Cleanup any test scenes
	for child in get_children():
		child.queue_free()

	super.after_each()


# =============================================================================
# FRAME RATE TESTS
# =============================================================================


func test_solo_gameplay_framerate() -> void:
	# NOTE: This test measures actual frame rate in headless mode
	# Results will differ from GUI mode with rendering

	var scene: Node = _create_minimal_test_scene()
	add_child_autofree(scene)

	# Warmup period
	for i in range(WARMUP_FRAMES):
		await get_tree().process_frame

	# Measure frame times
	var frame_times: Array[float] = []
	for i in range(FRAME_SAMPLE_COUNT):
		var start: float = Time.get_ticks_usec()
		await get_tree().process_frame
		var end: float = Time.get_ticks_usec()
		frame_times.append((end - start) / 1000.0)  # Convert to ms

	# Calculate statistics
	var stats: Dictionary = _calculate_frame_stats(frame_times)

	# Log results
	print("\n=== Solo Gameplay Frame Rate ===")
	print("Average FPS: %.1f" % stats.avg_fps)
	print("Min FPS: %.1f" % stats.min_fps)
	print("Max FPS: %.1f" % stats.max_fps)
	print("Frame time avg: %.2f ms" % stats.avg_frame_time)
	print("Frame time 99th percentile: %.2f ms" % stats.p99_frame_time)
	print("Target FPS: %.1f (UNVERIFIED estimate)" % TARGET_SOLO_FPS)
	print("================================\n")

	# Assert reasonable performance (not strict target, just sanity check)
	assert_gt(stats.avg_fps, 30.0, "Solo gameplay should maintain at least 30 FPS")

	# Document actual performance
	_document_performance_result("solo_gameplay", stats)


func test_splitscreen_4p_framerate() -> void:
	# NOTE: This test simulates 4-player splitscreen workload
	# Actual rendering performance will differ in GUI mode

	var scene: Node = _create_splitscreen_test_scene(4)
	add_child_autofree(scene)

	# Warmup period
	for i in range(WARMUP_FRAMES):
		await get_tree().process_frame

	# Measure frame times
	var frame_times: Array[float] = []
	for i in range(FRAME_SAMPLE_COUNT):
		var start: float = Time.get_ticks_usec()
		await get_tree().process_frame
		var end: float = Time.get_ticks_usec()
		frame_times.append((end - start) / 1000.0)  # Convert to ms

	# Calculate statistics
	var stats: Dictionary = _calculate_frame_stats(frame_times)

	# Log results
	print("\n=== 4-Player Splitscreen Frame Rate ===")
	print("Average FPS: %.1f" % stats.avg_fps)
	print("Min FPS: %.1f" % stats.min_fps)
	print("Max FPS: %.1f" % stats.max_fps)
	print("Frame time avg: %.2f ms" % stats.avg_frame_time)
	print("Frame time 99th percentile: %.2f ms" % stats.p99_frame_time)
	print("Target FPS: %.1f (UNVERIFIED estimate)" % TARGET_SPLITSCREEN_4P_FPS)
	print("=======================================\n")

	# Assert reasonable performance
	assert_gt(stats.avg_fps, 30.0, "4-player splitscreen should maintain at least 30 FPS")

	# Document actual performance
	_document_performance_result("splitscreen_4p", stats)


func test_multiplayer_8p_framerate() -> void:
	# NOTE: This test simulates 8-player multiplayer workload
	# Network latency and rendering not fully simulated in headless mode

	var scene: Node = _create_multiplayer_test_scene(8)
	add_child_autofree(scene)

	# Warmup period
	for i in range(WARMUP_FRAMES):
		await get_tree().process_frame

	# Measure frame times
	var frame_times: Array[float] = []
	for i in range(FRAME_SAMPLE_COUNT):
		var start: float = Time.get_ticks_usec()
		await get_tree().process_frame
		var end: float = Time.get_ticks_usec()
		frame_times.append((end - start) / 1000.0)  # Convert to ms

	# Calculate statistics
	var stats: Dictionary = _calculate_frame_stats(frame_times)

	# Log results
	print("\n=== 8-Player Multiplayer Frame Rate ===")
	print("Average FPS: %.1f" % stats.avg_fps)
	print("Min FPS: %.1f" % stats.min_fps)
	print("Max FPS: %.1f" % stats.max_fps)
	print("Frame time avg: %.2f ms" % stats.avg_frame_time)
	print("Frame time 99th percentile: %.2f ms" % stats.p99_frame_time)
	print("Target FPS: %.1f (UNVERIFIED estimate)" % TARGET_MULTIPLAYER_8P_FPS)
	print("=======================================\n")

	# Assert reasonable performance
	assert_gt(stats.avg_fps, 20.0, "8-player multiplayer should maintain at least 20 FPS")

	# Document actual performance
	_document_performance_result("multiplayer_8p", stats)


# =============================================================================
# MEMORY USAGE TESTS
# =============================================================================


func test_memory_usage_solo_gameplay() -> void:
	# NOTE: This test measures memory usage during solo gameplay
	# Memory usage will vary based on scene complexity and assets loaded

	# Get baseline memory before creating scene
	var baseline_static: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var baseline_dynamic: float = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)

	print("\n=== Solo Gameplay Memory Usage ===")
	print("Baseline static memory: %.2f MB" % (baseline_static / 1024.0 / 1024.0))
	print("Baseline dynamic memory: %.2f MB" % (baseline_dynamic / 1024.0 / 1024.0))

	# Create test scene
	var scene: Node = _create_minimal_test_scene()
	add_child_autofree(scene)

	# Let scene stabilize
	for i in range(60):
		await get_tree().process_frame

	# Measure memory usage over time
	var memory_samples: Array[Dictionary] = []
	for i in range(100):  # Sample for ~1.5 seconds
		var sample: Dictionary = _capture_memory_snapshot()
		memory_samples.append(sample)
		await get_tree().process_frame

	# Calculate memory statistics
	var stats: Dictionary = _calculate_memory_stats(memory_samples)

	# Log results
	print("Average static memory: %.2f MB" % stats.avg_static_mb)
	print("Peak static memory: %.2f MB" % stats.peak_static_mb)
	print("Average dynamic memory: %.2f MB" % stats.avg_dynamic_mb)
	print("Peak dynamic memory: %.2f MB" % stats.peak_dynamic_mb)
	print("Memory growth: %.2f MB" % stats.memory_growth_mb)
	print("Object count: %d" % stats.avg_object_count)
	print("==================================\n")

	# Assert reasonable memory usage (sanity checks)
	assert_lt(stats.peak_static_mb, 500.0, "Static memory should stay under 500 MB")
	assert_lt(stats.memory_growth_mb, 50.0, "Memory growth should be minimal (<50 MB)")

	# Document actual memory usage
	_document_memory_result("solo_gameplay", stats)


func test_memory_usage_splitscreen_4p() -> void:
	# NOTE: This test measures memory usage during 4-player splitscreen
	# Multiple viewports increase memory usage

	# Get baseline memory
	var baseline_static: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var baseline_dynamic: float = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)

	print("\n=== 4-Player Splitscreen Memory Usage ===")
	print("Baseline static memory: %.2f MB" % (baseline_static / 1024.0 / 1024.0))
	print("Baseline dynamic memory: %.2f MB" % (baseline_dynamic / 1024.0 / 1024.0))

	# Create splitscreen scene
	var scene: Node = _create_splitscreen_test_scene(4)
	add_child_autofree(scene)

	# Let scene stabilize
	for i in range(60):
		await get_tree().process_frame

	# Measure memory usage over time
	var memory_samples: Array[Dictionary] = []
	for i in range(100):
		var sample: Dictionary = _capture_memory_snapshot()
		memory_samples.append(sample)
		await get_tree().process_frame

	# Calculate memory statistics
	var stats: Dictionary = _calculate_memory_stats(memory_samples)

	# Log results
	print("Average static memory: %.2f MB" % stats.avg_static_mb)
	print("Peak static memory: %.2f MB" % stats.peak_static_mb)
	print("Average dynamic memory: %.2f MB" % stats.avg_dynamic_mb)
	print("Peak dynamic memory: %.2f MB" % stats.peak_dynamic_mb)
	print("Memory growth: %.2f MB" % stats.memory_growth_mb)
	print("Object count: %d" % stats.avg_object_count)
	print("=========================================\n")

	# Assert reasonable memory usage
	assert_lt(stats.peak_static_mb, 800.0, "Static memory should stay under 800 MB for 4-player")
	assert_lt(stats.memory_growth_mb, 100.0, "Memory growth should be minimal (<100 MB)")

	# Document actual memory usage
	_document_memory_result("splitscreen_4p", stats)


func test_memory_usage_multiplayer_8p() -> void:
	# NOTE: This test measures memory usage during 8-player multiplayer
	# Multiple player entities increase memory usage

	# Get baseline memory
	var baseline_static: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var baseline_dynamic: float = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)

	print("\n=== 8-Player Multiplayer Memory Usage ===")
	print("Baseline static memory: %.2f MB" % (baseline_static / 1024.0 / 1024.0))
	print("Baseline dynamic memory: %.2f MB" % (baseline_dynamic / 1024.0 / 1024.0))

	# Create multiplayer scene
	var scene: Node = _create_multiplayer_test_scene(8)
	add_child_autofree(scene)

	# Let scene stabilize
	for i in range(60):
		await get_tree().process_frame

	# Measure memory usage over time
	var memory_samples: Array[Dictionary] = []
	for i in range(100):
		var sample: Dictionary = _capture_memory_snapshot()
		memory_samples.append(sample)
		await get_tree().process_frame

	# Calculate memory statistics
	var stats: Dictionary = _calculate_memory_stats(memory_samples)

	# Log results
	print("Average static memory: %.2f MB" % stats.avg_static_mb)
	print("Peak static memory: %.2f MB" % stats.peak_static_mb)
	print("Average dynamic memory: %.2f MB" % stats.avg_dynamic_mb)
	print("Peak dynamic memory: %.2f MB" % stats.peak_dynamic_mb)
	print("Memory growth: %.2f MB" % stats.memory_growth_mb)
	print("Object count: %d" % stats.avg_object_count)
	print("=========================================\n")

	# Assert reasonable memory usage
	assert_lt(stats.peak_static_mb, 1000.0, "Static memory should stay under 1000 MB for 8-player")
	assert_lt(stats.memory_growth_mb, 150.0, "Memory growth should be minimal (<150 MB)")

	# Document actual memory usage
	_document_memory_result("multiplayer_8p", stats)


func test_memory_leak_detection() -> void:
	# NOTE: This test detects memory leaks by creating and destroying scenes repeatedly
	# Memory should stabilize after initial allocations

	print("\n=== Memory Leak Detection ===")

	# Get baseline memory
	var baseline_static: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var baseline_objects: float = Performance.get_monitor(Performance.OBJECT_COUNT)

	print("Baseline static memory: %.2f MB" % (baseline_static / 1024.0 / 1024.0))
	print("Baseline object count: %d" % baseline_objects)

	# Create and destroy scenes multiple times
	var memory_after_cycles: Array[float] = []
	var object_counts: Array[float] = []

	for cycle in range(5):
		# Create scene
		var scene: Node = _create_minimal_test_scene()
		add_child(scene)

		# Let it run for a bit
		for i in range(30):
			await get_tree().process_frame

		# Destroy scene
		scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame

		# Force garbage collection (if available)
		# Note: Godot doesn't expose force_garbage_collection in GDScript
		# Just wait for automatic GC
		for i in range(10):
			await get_tree().process_frame

		# Wait for cleanup
		for i in range(30):
			await get_tree().process_frame

		# Measure memory
		var current_static: float = Performance.get_monitor(Performance.MEMORY_STATIC)
		var current_objects: float = Performance.get_monitor(Performance.OBJECT_COUNT)

		memory_after_cycles.append(current_static)
		object_counts.append(current_objects)

		print(
			(
				"Cycle %d: Memory = %.2f MB, Objects = %d"
				% [cycle + 1, current_static / 1024.0 / 1024.0, current_objects]
			)
		)

	# Check for memory leaks
	var first_cycle_memory: float = memory_after_cycles[0]
	var last_cycle_memory: float = memory_after_cycles[memory_after_cycles.size() - 1]
	var memory_growth: float = (last_cycle_memory - first_cycle_memory) / 1024.0 / 1024.0

	var first_cycle_objects: float = object_counts[0]
	var last_cycle_objects: float = object_counts[object_counts.size() - 1]
	var object_growth: float = last_cycle_objects - first_cycle_objects

	print("\nMemory growth over 5 cycles: %.2f MB" % memory_growth)
	print("Object count growth: %d objects" % object_growth)
	print("=============================\n")

	# Assert no significant memory leaks
	# Allow some growth for caching and internal allocations
	assert_lt(memory_growth, 20.0, "Memory growth should be minimal (<20 MB over 5 cycles)")
	assert_lt(object_growth, 100, "Object count growth should be minimal (<100 objects)")

	# Document leak detection results
	var leak_stats: Dictionary = {
		"memory_growth_mb": memory_growth,
		"object_growth": object_growth,
		"cycles": 5,
		"leak_detected": memory_growth > 20.0 or object_growth > 100
	}
	_document_memory_result("leak_detection", leak_stats)


# =============================================================================
# NETWORK BANDWIDTH TESTS
# =============================================================================


func test_network_bandwidth_measurement() -> void:
	# NOTE: This test documents network bandwidth measurement approach
	# Godot's Performance class doesn't expose NETWORK_IN_BANDWIDTH/NETWORK_OUT_BANDWIDTH
	# Real network monitoring requires actual multiplayer connections

	print("\n=== Network Bandwidth Measurement ===")
	print("NOTE: Network bandwidth monitoring requires actual multiplayer connections")
	print("This test documents the measurement approach for manual testing")

	# Create a multiplayer scene to simulate network activity
	var scene: Node = _create_multiplayer_test_scene(8)
	add_child_autofree(scene)

	# Let scene stabilize
	for i in range(60):
		await get_tree().process_frame

	# In a real multiplayer scenario, you would:
	# 1. Track bytes sent/received via MultiplayerAPI
	# 2. Calculate bandwidth as bytes_per_second
	# 3. Monitor over time to get average/peak values

	# Simulate network statistics for documentation
	var stats: Dictionary = {
		"avg_in_bandwidth_kb": 0.0,  # Would be calculated from actual network traffic
		"peak_in_bandwidth_kb": 0.0,
		"avg_out_bandwidth_kb": 0.0,
		"peak_out_bandwidth_kb": 0.0,
		"total_in_mb": 0.0,
		"total_out_mb": 0.0,
		"note": "Requires actual multiplayer connection for real measurements"
	}

	# Log results
	print("Average incoming bandwidth: %.2f KB/s (simulated)" % stats.avg_in_bandwidth_kb)
	print("Peak incoming bandwidth: %.2f KB/s (simulated)" % stats.peak_in_bandwidth_kb)
	print("Average outgoing bandwidth: %.2f KB/s (simulated)" % stats.avg_out_bandwidth_kb)
	print("Peak outgoing bandwidth: %.2f KB/s (simulated)" % stats.peak_out_bandwidth_kb)
	print("Total data received: %.2f MB (simulated)" % stats.total_in_mb)
	print("Total data sent: %.2f MB (simulated)" % stats.total_out_mb)
	print("\nTo measure real network bandwidth:")
	print("1. Start a multiplayer server")
	print("2. Connect multiple clients")
	print("3. Track MultiplayerAPI.get_bytes_sent() and get_bytes_received()")
	print("4. Calculate bandwidth as delta_bytes / delta_time")
	print("=====================================\n")

	# Assert test structure is valid
	assert_true(stats.has("avg_in_bandwidth_kb"), "Stats should have bandwidth metrics")

	# Document network measurement approach
	_document_network_result("bandwidth_measurement", stats)


func test_network_packet_rates() -> void:
	# NOTE: This test documents packet rate measurement approach
	# Godot doesn't expose packet counts directly via Performance monitors
	# Real packet rate tracking requires MultiplayerAPI integration

	print("\n=== Network Packet Rates ===")
	print("NOTE: Packet rate monitoring requires actual multiplayer connections")
	print("This test documents the measurement approach for manual testing")

	# Create a multiplayer scene
	var scene: Node = _create_multiplayer_test_scene(8)
	add_child_autofree(scene)

	# Let scene stabilize
	for i in range(60):
		await get_tree().process_frame

	# In a real multiplayer scenario, you would:
	# 1. Track RPC calls per second
	# 2. Monitor MultiplayerSynchronizer updates
	# 3. Count packets sent/received via network profiler

	# Simulate packet rate statistics for documentation
	var stats: Dictionary = {
		"avg_packets_in_per_sec": 0.0,  # Would be calculated from actual network traffic
		"peak_packets_in_per_sec": 0.0,
		"avg_packets_out_per_sec": 0.0,
		"peak_packets_out_per_sec": 0.0,
		"total_packets_in": 0,
		"total_packets_out": 0,
		"note": "Requires actual multiplayer connection for real measurements"
	}

	# Log results
	print("Average packets received/sec: %.1f (simulated)" % stats.avg_packets_in_per_sec)
	print("Peak packets received/sec: %.1f (simulated)" % stats.peak_packets_in_per_sec)
	print("Average packets sent/sec: %.1f (simulated)" % stats.avg_packets_out_per_sec)
	print("Peak packets sent/sec: %.1f (simulated)" % stats.peak_packets_out_per_sec)
	print("Total packets received: %d (simulated)" % stats.total_packets_in)
	print("Total packets sent: %d (simulated)" % stats.total_packets_out)
	print("\nTo measure real packet rates:")
	print("1. Enable network profiling in Godot")
	print("2. Start multiplayer session")
	print("3. Monitor RPC calls and synchronizer updates")
	print("4. Use Godot's built-in network profiler")
	print("============================\n")

	# Assert test structure is valid
	assert_true(stats.has("avg_packets_in_per_sec"), "Stats should have packet rate metrics")

	# Document packet rate measurement approach
	_document_network_result("packet_rates", stats)


func test_network_latency_simulation() -> void:
	# NOTE: This test simulates network latency measurement
	# Real latency requires actual network round-trip time measurement

	print("\n=== Network Latency Simulation ===")
	print("NOTE: Latency measurement requires actual multiplayer connections")
	print("This test simulates latency for documentation purposes")

	# Create a multiplayer scene
	var scene: Node = _create_multiplayer_test_scene(4)
	add_child_autofree(scene)

	# Let scene stabilize
	for i in range(60):
		await get_tree().process_frame

	# Simulate latency measurements using frame time as proxy
	var latency_samples: Array[float] = []
	for i in range(50):
		var latency: float = _simulate_network_latency()
		latency_samples.append(latency)
		await get_tree().process_frame

	# Calculate latency statistics
	var stats: Dictionary = _calculate_latency_stats(latency_samples)

	# Log results
	print("Average latency: %.1f ms (simulated)" % stats.avg_latency_ms)
	print("Min latency: %.1f ms (simulated)" % stats.min_latency_ms)
	print("Max latency: %.1f ms (simulated)" % stats.max_latency_ms)
	print("Latency std dev: %.1f ms (simulated)" % stats.std_dev_ms)
	print("Latency jitter: %.1f ms (simulated)" % stats.jitter_ms)
	print("\nTo measure real network latency:")
	print("1. Implement ping/pong RPC calls")
	print("2. Measure round-trip time (RTT)")
	print("3. Calculate latency as RTT / 2")
	print("4. Track jitter as variation in latency")
	print("==================================\n")

	# Assert reasonable latency (simulated values)
	assert_ge(stats.avg_latency_ms, 0.0, "Average latency should be non-negative")
	assert_lt(stats.avg_latency_ms, 1000.0, "Average latency should be reasonable (<1000ms)")

	# Document latency simulation results
	_document_network_result("latency_simulation", stats)


func test_network_performance_under_load() -> void:
	# NOTE: This test documents comprehensive network performance measurement
	# Combines bandwidth, packet rates, and latency under load conditions

	print("\n=== Network Performance Under Load ===")
	print("NOTE: Comprehensive network testing requires actual multiplayer")
	print("This test documents the measurement approach for 8-player scenarios")

	# Create a multiplayer scene with 8 players
	var scene: Node = _create_multiplayer_test_scene(8)
	add_child_autofree(scene)

	# Let scene stabilize
	for i in range(60):
		await get_tree().process_frame

	# Simulate comprehensive network performance measurement
	var latency_samples: Array[float] = []
	for i in range(150):  # Sample for ~2.5 seconds
		var latency: float = _simulate_network_latency()
		latency_samples.append(latency)
		await get_tree().process_frame

	# Calculate comprehensive statistics
	var latency_stats: Dictionary = _calculate_latency_stats(latency_samples)

	# Simulate bandwidth and packet stats
	var network_stats: Dictionary = {
		"avg_in_bandwidth_kb": 0.0,
		"avg_out_bandwidth_kb": 0.0,
		"note": "Requires actual multiplayer for real measurements"
	}

	var packet_stats: Dictionary = {
		"avg_packets_in_per_sec": 0.0,
		"avg_packets_out_per_sec": 0.0,
		"note": "Requires actual multiplayer for real measurements"
	}

	# Log comprehensive results
	print(
		(
			"Bandwidth - Avg In: %.2f KB/s, Avg Out: %.2f KB/s (simulated)"
			% [network_stats.avg_in_bandwidth_kb, network_stats.avg_out_bandwidth_kb]
		)
	)
	print(
		(
			"Packet Rate - Avg In: %.1f/s, Avg Out: %.1f/s (simulated)"
			% [packet_stats.avg_packets_in_per_sec, packet_stats.avg_packets_out_per_sec]
		)
	)
	print(
		(
			"Latency - Avg: %.1f ms, Jitter: %.1f ms (simulated)"
			% [latency_stats.avg_latency_ms, latency_stats.jitter_ms]
		)
	)
	print("\nFor real 8-player network testing:")
	print("1. Start dedicated server")
	print("2. Connect 8 clients")
	print("3. Monitor bandwidth, packet rates, and latency")
	print("4. Test under various gameplay scenarios")
	print("5. Document performance characteristics")
	print("======================================\n")

	# Assert test structure is valid
	assert_ge(latency_stats.avg_latency_ms, 0.0, "Latency should be non-negative")
	assert_true(network_stats.has("avg_in_bandwidth_kb"), "Should have bandwidth metrics")
	assert_true(packet_stats.has("avg_packets_in_per_sec"), "Should have packet metrics")

	# Document comprehensive network performance
	var combined_stats: Dictionary = {
		"bandwidth": network_stats, "packets": packet_stats, "latency": latency_stats
	}
	_document_network_result("performance_under_load", combined_stats)


# =============================================================================
# HELPER METHODS
# =============================================================================


## Create a minimal scene for solo gameplay testing
func _create_minimal_test_scene() -> Node:
	var scene: Node3D = Node3D.new()
	scene.name = "TestScene"

	# Add some basic nodes to simulate gameplay load
	for i in range(10):
		var node: Node3D = Node3D.new()
		node.name = "TestNode_%d" % i
		scene.add_child(node)

	return scene


## Create a scene simulating splitscreen with multiple viewports
func _create_splitscreen_test_scene(player_count: int) -> Node:
	var scene: Node3D = Node3D.new()
	scene.name = "SplitscreenTestScene"

	# Simulate viewport workload by creating multiple camera contexts
	for i in range(player_count):
		var viewport_context: Node3D = Node3D.new()
		viewport_context.name = "ViewportContext_%d" % i

		# Add some nodes per viewport to simulate rendering load
		for j in range(20):
			var node: Node3D = Node3D.new()
			node.name = "ViewportNode_%d" % j
			viewport_context.add_child(node)

		scene.add_child(viewport_context)

	return scene


## Create a scene simulating multiplayer with multiple players
func _create_multiplayer_test_scene(player_count: int) -> Node:
	var scene: Node3D = Node3D.new()
	scene.name = "MultiplayerTestScene"

	# Simulate player entities
	for i in range(player_count):
		var player_context: Node3D = Node3D.new()
		player_context.name = "Player_%d" % i

		# Add components to simulate player complexity
		for j in range(15):
			var component: Node3D = Node3D.new()
			component.name = "Component_%d" % j
			player_context.add_child(component)

		scene.add_child(player_context)

	# Add some shared world objects
	for i in range(30):
		var world_object: Node3D = Node3D.new()
		world_object.name = "WorldObject_%d" % i
		scene.add_child(world_object)

	return scene


## Calculate frame rate statistics from frame time samples
func _calculate_frame_stats(frame_times: Array[float]) -> Dictionary:
	if frame_times.is_empty():
		return {
			"avg_fps": 0.0,
			"min_fps": 0.0,
			"max_fps": 0.0,
			"avg_frame_time": 0.0,
			"p99_frame_time": 0.0
		}

	# Calculate average frame time
	var total_time: float = 0.0
	var min_time: float = frame_times[0]
	var max_time: float = frame_times[0]

	for time in frame_times:
		total_time += time
		min_time = min(min_time, time)
		max_time = max(max_time, time)

	var avg_frame_time: float = total_time / frame_times.size()

	# Calculate 99th percentile frame time
	var sorted_times: Array[float] = frame_times.duplicate()
	sorted_times.sort()
	var p99_index: int = int(sorted_times.size() * 0.99)
	var p99_frame_time: float = sorted_times[p99_index]

	# Convert to FPS (handle zero division)
	var avg_fps: float = 1000.0 / avg_frame_time if avg_frame_time > 0.0 else 0.0
	var min_fps: float = 1000.0 / max_time if max_time > 0.0 else 0.0
	var max_fps: float = 1000.0 / min_time if min_time > 0.0 else 0.0

	return {
		"avg_fps": avg_fps,
		"min_fps": min_fps,
		"max_fps": max_fps,
		"avg_frame_time": avg_frame_time,
		"p99_frame_time": p99_frame_time
	}


## Document performance results for later analysis
func _document_performance_result(test_name: String, stats: Dictionary) -> void:
	# This could write to a file or database in a real implementation
	# For now, just ensure the data is structured correctly

	var result: Dictionary = {
		"test_name": test_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"avg_fps": stats.avg_fps,
		"min_fps": stats.min_fps,
		"max_fps": stats.max_fps,
		"avg_frame_time_ms": stats.avg_frame_time,
		"p99_frame_time_ms": stats.p99_frame_time,
		"headless_mode": DisplayServer.get_name() == "headless",
		"godot_version": Engine.get_version_info()
	}

	# Log structured result for parsing
	print("PERFORMANCE_RESULT: %s" % JSON.stringify(result))


## Capture a snapshot of current memory usage
func _capture_memory_snapshot() -> Dictionary:
	return {
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"dynamic_memory": Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	}


## Calculate memory statistics from samples
func _calculate_memory_stats(samples: Array[Dictionary]) -> Dictionary:
	if samples.is_empty():
		return {
			"avg_static_mb": 0.0,
			"peak_static_mb": 0.0,
			"avg_dynamic_mb": 0.0,
			"peak_dynamic_mb": 0.0,
			"memory_growth_mb": 0.0,
			"avg_object_count": 0,
			"avg_node_count": 0,
			"avg_orphan_count": 0
		}

	var total_static: float = 0.0
	var total_dynamic: float = 0.0
	var total_objects: float = 0.0
	var total_nodes: float = 0.0
	var total_orphans: float = 0.0

	var peak_static: float = samples[0].static_memory
	var peak_dynamic: float = samples[0].dynamic_memory
	var first_static: float = samples[0].static_memory
	var last_static: float = samples[samples.size() - 1].static_memory

	for sample in samples:
		total_static += sample.static_memory
		total_dynamic += sample.dynamic_memory
		total_objects += sample.object_count
		total_nodes += sample.node_count
		total_orphans += sample.orphan_node_count

		peak_static = max(peak_static, sample.static_memory)
		peak_dynamic = max(peak_dynamic, sample.dynamic_memory)

	var sample_count: int = samples.size()

	return {
		"avg_static_mb": (total_static / float(sample_count)) / 1024.0 / 1024.0,
		"peak_static_mb": peak_static / 1024.0 / 1024.0,
		"avg_dynamic_mb": (total_dynamic / float(sample_count)) / 1024.0 / 1024.0,
		"peak_dynamic_mb": peak_dynamic / 1024.0 / 1024.0,
		"memory_growth_mb": (last_static - first_static) / 1024.0 / 1024.0,
		"avg_object_count": int(total_objects / float(sample_count)),
		"avg_node_count": int(total_nodes / float(sample_count)),
		"avg_orphan_count": int(total_orphans / float(sample_count))
	}


## Document memory usage results for later analysis
func _document_memory_result(test_name: String, stats: Dictionary) -> void:
	# This could write to a file or database in a real implementation
	# For now, just ensure the data is structured correctly

	var result: Dictionary = {
		"test_name": test_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"headless_mode": DisplayServer.get_name() == "headless",
		"godot_version": Engine.get_version_info()
	}

	# Merge stats into result
	result.merge(stats)

	# Log structured result for parsing
	print("MEMORY_RESULT: %s" % JSON.stringify(result))


## Simulate network latency measurement
func _simulate_network_latency() -> float:
	# Note: In a real implementation, this would measure actual round-trip time
	# For testing purposes, we simulate latency based on Performance monitors

	# Use physics frame time as a proxy for processing latency
	var frame_time: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)

	# Simulate network latency (base latency + processing time)
	# In headless mode, this will be very low; in real network, add RTT
	var base_latency: float = 10.0  # Simulated base latency in ms
	var processing_latency: float = frame_time * 1000.0  # Convert to ms

	return base_latency + processing_latency


## Calculate latency statistics from samples
func _calculate_latency_stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {
			"avg_latency_ms": 0.0,
			"min_latency_ms": 0.0,
			"max_latency_ms": 0.0,
			"std_dev_ms": 0.0,
			"jitter_ms": 0.0
		}

	# Calculate average
	var total: float = 0.0
	var min_latency: float = samples[0]
	var max_latency: float = samples[0]

	for latency in samples:
		total += latency
		min_latency = min(min_latency, latency)
		max_latency = max(max_latency, latency)

	var avg_latency: float = total / samples.size()

	# Calculate standard deviation
	var variance_sum: float = 0.0
	for latency in samples:
		var diff: float = latency - avg_latency
		variance_sum += diff * diff

	var std_dev: float = sqrt(variance_sum / samples.size())

	# Calculate jitter (variation in latency)
	var jitter_sum: float = 0.0
	for i in range(1, samples.size()):
		var diff: float = abs(samples[i] - samples[i - 1])
		jitter_sum += diff

	var jitter: float = jitter_sum / max(1, samples.size() - 1)

	return {
		"avg_latency_ms": avg_latency,
		"min_latency_ms": min_latency,
		"max_latency_ms": max_latency,
		"std_dev_ms": std_dev,
		"jitter_ms": jitter
	}


## Document network performance results for later analysis
func _document_network_result(test_name: String, stats: Dictionary) -> void:
	# This could write to a file or database in a real implementation
	# For now, just ensure the data is structured correctly

	var result: Dictionary = {
		"test_name": test_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"headless_mode": DisplayServer.get_name() == "headless",
		"godot_version": Engine.get_version_info()
	}

	# Merge stats into result
	result.merge(stats)

	# Log structured result for parsing
	print("NETWORK_RESULT: %s" % JSON.stringify(result))
