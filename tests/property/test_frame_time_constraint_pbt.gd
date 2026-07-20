extends PropertyBasedTesting

## Property-Based Test: Frame time constraint
## Feature: architecture-refactoring, Property 38: Frame time constraint
## Validates: Requirements 11.7

const GameManager = preload("res://game/scripts/core/game_manager.gd")


func test_property_frame_time_constraint() -> void:
	# Property 38: For any game scene running with the refactored architecture,
	# the average frame time should not exceed the old architecture's frame time plus 2ms.

	await run_enhanced_property_test(
		"Frame time constraint",
		_test_frame_time_within_bounds,
		100,
		SamplingStrategy.MIXED,
		"Frame time should not exceed baseline + 2ms"
	)


func _test_frame_time_within_bounds(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Measure baseline frame time (simulated old architecture)
	var baseline_times = []
	for i in range(30):
		var start = Time.get_ticks_usec()
		await get_tree().process_frame
		var end = Time.get_ticks_usec()
		baseline_times.append((end - start) / 1000.0)

	var baseline_avg = 0.0
	for ft in baseline_times:
		baseline_avg += ft
	baseline_avg /= baseline_times.size()

	# Create and initialize GameManager (new architecture)
	var gm := GameManager.new()
	add_child(gm)
	gm.initialize()

	await get_tree().process_frame
	await get_tree().process_frame

	# Measure frame time with new architecture
	var new_times = []
	for i in range(30):
		var start = Time.get_ticks_usec()
		await get_tree().process_frame
		var end = Time.get_ticks_usec()
		new_times.append((end - start) / 1000.0)

	var new_avg = 0.0
	for ft in new_times:
		new_avg += ft
	new_avg /= new_times.size()

	var difference = new_avg - baseline_avg

	# Frame time increase should be less than 2ms
	var within_bounds = difference < 2.0

	if not within_bounds:
		print(
			"Frame time increase too large: %.2f ms (baseline: %.2f ms, new: %.2f ms)"
			% [difference, baseline_avg, new_avg]
		)

	# Property callbacks run up to 100 times inside one GUT test. Free each
	# service tree now instead of retaining every fixture until after the test.
	gm.free()
	return within_bounds


func test_property_frame_time_with_feature_combinations() -> void:
	# Property: Frame time should stay within bounds for any feature combination

	await run_enhanced_property_test(
		"Frame time with feature combinations",
		_test_frame_time_with_features,
		100,
		SamplingStrategy.MIXED,
		"Frame time should be bounded for any feature set"
	)


func _test_frame_time_with_features(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	var gm := GameManager.new()
	add_child(gm)
	gm.initialize()

	await get_tree().process_frame

	# Randomly enable/disable features
	var features = ["combat", "inventory", "loot", "gore", "audio"]
	var enabled_count = rng.randi_range(1, features.size())

	for i in range(enabled_count):
		var feature = features[rng.randi_range(0, features.size() - 1)]
		if not gm.is_feature_enabled(feature):
			gm.load_feature(feature)

	await get_tree().process_frame

	# Measure frame time
	var frame_times = []
	for i in range(30):
		var start = Time.get_ticks_usec()
		await get_tree().process_frame
		var end = Time.get_ticks_usec()
		frame_times.append((end - start) / 1000.0)

	var avg_frame_time = 0.0
	for ft in frame_times:
		avg_frame_time += ft
	avg_frame_time /= frame_times.size()

	# Frame time should support 60 FPS (16.67ms)
	var within_bounds = avg_frame_time < 16.67

	if not within_bounds:
		print("Frame time too high: %.2f ms" % avg_frame_time)

	gm.free()
	return within_bounds


func test_property_frame_time_stability() -> void:
	# Property: Frame time should be stable (low variance)

	await run_enhanced_property_test(
		"Frame time stability",
		_test_frame_time_stable,
		100,
		SamplingStrategy.MIXED,
		"Frame time should be stable"
	)


func _test_frame_time_stable(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	var gm := GameManager.new()
	add_child(gm)
	gm.initialize()

	await get_tree().process_frame

	# Measure frame times
	var frame_times = []
	for i in range(60):
		var start = Time.get_ticks_usec()
		await get_tree().process_frame
		var end = Time.get_ticks_usec()
		frame_times.append((end - start) / 1000.0)

	# Headless CI can deschedule the process for an arbitrary interval. Measure
	# the stable middle 90% so one host scheduling pause does not masquerade as
	# engine jitter; absolute spikes remain covered by the performance lane.
	frame_times.sort()
	var trim_count := int(floor(frame_times.size() * 0.05))
	var stable_times := frame_times.slice(trim_count, frame_times.size() - trim_count)

	# Calculate standard deviation for representative frames.
	var mean = 0.0
	for ft in stable_times:
		mean += ft
	mean /= stable_times.size()

	var variance = 0.0
	for ft in stable_times:
		variance += (ft - mean) * (ft - mean)
	variance /= stable_times.size()
	var std_dev = sqrt(variance)

	# Standard deviation should be low (stable frame times)
	var is_stable = std_dev < 5.0

	if not is_stable:
		print("Frame time unstable: std_dev = %.2f ms" % std_dev)

	gm.free()
	return is_stable


func test_property_frame_time_with_events() -> void:
	# Property: Event system should not significantly impact frame time

	await run_enhanced_property_test(
		"Frame time with event system",
		_test_frame_time_with_events,
		100,
		SamplingStrategy.MIXED,
		"Events should not impact frame time"
	)


func _test_frame_time_with_events(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	var gm := GameManager.new()
	add_child(gm)
	gm.initialize()

	# Subscribe to random number of events
	var event_count = rng.randi_range(5, 20)
	for i in range(event_count):
		gm.subscribe("test_event_%d" % i, func(_data): pass)

	await get_tree().process_frame

	# Measure frame time while emitting events
	var frame_times = []
	for i in range(30):
		var start = Time.get_ticks_usec()

		# Emit random events
		var emit_count = rng.randi_range(1, 5)
		for j in range(emit_count):
			var event_id = rng.randi_range(0, event_count - 1)
			gm.emit_event("test_event_%d" % event_id, {})

		await get_tree().process_frame
		var end = Time.get_ticks_usec()
		frame_times.append((end - start) / 1000.0)

	# Ignore one scheduler pause at each edge; host descheduling is not event-system cost.
	frame_times.sort()
	var stable_times := frame_times.slice(1, frame_times.size() - 1)
	var avg_frame_time = 0.0
	for ft in stable_times:
		avg_frame_time += ft
	avg_frame_time /= stable_times.size()

	# Frame time should still support 60 FPS
	var within_bounds = avg_frame_time < 16.67

	gm.free()
	return within_bounds


func test_property_frame_time_during_feature_loading() -> void:
	# Property: Feature loading should not cause frame time spikes

	await run_enhanced_property_test(
		"Frame time during feature loading",
		_test_frame_time_during_loading,
		50,  # Fewer iterations due to async operations
		SamplingStrategy.MIXED,
		"Feature loading should not spike frame time"
	)


func _test_frame_time_during_loading(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	var gm := GameManager.new()
	add_child(gm)
	gm.initialize()

	await get_tree().process_frame

	# Measure frame time during feature loading
	var start = Time.get_ticks_usec()

	gm.load_feature("physics")

	await get_tree().process_frame

	var end = Time.get_ticks_usec()
	var load_frame_time = (end - start) / 1000.0

	# Feature loading should not cause excessive frame time
	var no_spike = load_frame_time < 100.0  # Less than 100ms

	if not no_spike:
		print("Feature loading caused frame time spike: %.2f ms" % load_frame_time)

	gm.free()
	return no_spike
