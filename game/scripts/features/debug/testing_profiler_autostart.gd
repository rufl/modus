extends Node

## Auto-start script for TestingTimeProfiler
## Add this as an autoload in project.godot to automatically initialize the profiler


func _ready() -> void:
	# Only initialize in debug builds or editor
	if not OS.is_debug_build() and not OS.has_feature("editor"):
		return

	# Wait for GameManager to be ready
	await get_tree().process_frame

	if not GameManager:
		push_error("[TestingProfilerAutostart] GameManager not found")
		return

	# Setup profiler and overlay
	var result: Dictionary = TestingProfilerIntegration.setup_all()

	var logger: Node = GameManager.get_core_system("logger")
	if result.get("profiler"):
		if logger:
			logger.info("Testing time profiler initialized", "TestingProfilerAutostart")

	if result.get("overlay"):
		if logger:
			logger.info("Testing time overlay initialized", "TestingProfilerAutostart")
