class_name TestingProfilerIntegration
extends RefCounted

## Integration helper for TestingTimeProfiler
## Call this from GameManager or a debug feature to set up the profiler


static func setup_profiler() -> TestingTimeProfiler:
	# Create profiler instance
	var profiler := TestingTimeProfiler.new()
	profiler.name = "TestingTimeProfiler"

	# Add to scene tree
	GameManager.add_child(profiler)

	# Register as core system
	GameManager.register_core_system("testing_time_profiler", profiler)

	# Register console commands if console exists
	var console_registry: Variant = GameManager.get_core_system("console_command_registry")
	if console_registry:
		TestingProfilerCommands.register_commands(console_registry)

	var logger := GameManager.get_core_system("logger")
	if logger:
		logger.info("[TestingProfiler] Testing time profiler initialized", "Debug")

	return profiler


static func setup_overlay() -> TestingTimeOverlay:
	# Load and instantiate overlay scene
	var overlay_scene: PackedScene = load(
		"res://game/scripts/features/debug/testing_time_overlay.tscn"
	)
	if not overlay_scene:
		push_error("[TestingProfiler] Failed to load overlay scene")
		return null

	var overlay: TestingTimeOverlay = overlay_scene.instantiate()

	# Add to scene tree (as child of root to persist across scenes)
	GameManager.get_tree().root.add_child(overlay)

	var logger := GameManager.get_core_system("logger")
	if logger:
		logger.info("[TestingProfiler] Testing time overlay initialized", "Debug")

	return overlay


static func setup_all() -> Dictionary:
	var profiler: TestingTimeProfiler = setup_profiler()
	var overlay: TestingTimeOverlay = setup_overlay()

	return {"profiler": profiler, "overlay": overlay}
