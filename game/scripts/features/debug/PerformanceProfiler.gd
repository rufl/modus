extends CanvasLayer
class_name PerformanceProfiler

@export var enable_profiling: bool = true
@export var show_overlay: bool = false

var _debug_label: Label = null
var _background_panel: Panel = null


func _ready() -> void:
	layer = 100  # Render on top
	_create_debug_overlay()

	if show_overlay:
		show_debug_overlay()
	else:
		hide_debug_overlay()

	# Connect to GameManager.get_core_system("performance") signals if available
	# Note: GameManager.get_core_system("performance") doesn't emit these signals currently
	# Signals would need to be added to GameManager.get_core_system("performance") if needed


func _input(event: InputEvent) -> void:
	# Toggle overlay with F3
	if event.is_action_pressed("ui_text_completion_query"):  # F3 key
		toggle_overlay()


func _process(_delta: float) -> void:
	if not enable_profiling or not show_overlay or not _debug_label:
		return

	_update_debug_overlay()


func _create_debug_overlay() -> void:
	# Create semi-transparent background panel
	_background_panel = Panel.new()
	_background_panel.position = Vector2(10, 10)
	_background_panel.custom_minimum_size = Vector2(400, 200)

	# Create dark background style
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)
	style_box.border_color = Color(1, 1, 0, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4

	_background_panel.add_theme_stylebox_override("panel", style_box)
	add_child(_background_panel)

	# Create label
	_debug_label = Label.new()
	_debug_label.name = "PerformanceDebugOverlay"
	_debug_label.position = Vector2(20, 20)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.add_theme_color_override("font_color", Color.YELLOW)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 2)
	add_child(_debug_label)


func _update_debug_overlay() -> void:
	if not _debug_label:
		return

	var report: Dictionary = GameManager.get_core_system("performance").get_performance_report()

	var text: String = ""
	text += "=== Performance Metrics (F3 to toggle) ===\n"
	text += (
		"FPS: %.1f (Avg: %.1f, Min: %.1f, Max: %.1f)\n"
		% [report.fps.current, report.fps.average, report.fps.min, report.fps.max]
	)
	text += "Frame Time: %.2f ms (Target: 16.67 ms)\n" % report.frame_time_ms
	text += "Memory: %.1f MB\n" % report.memory_mb
	text += "Objects: %d | Nodes: %d\n" % [report.object_count, report.node_count]
	text += "Orphan Nodes: %d\n" % report.orphan_node_count
	text += "Frames: %d\n" % report.frame_count

	# Add enemy count
	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	text += "Enemies: %d\n" % enemy_count

	# Add pool stats if GameManager.get_core_system("pools") exists
	if (
		GameManager.get_core_system("pools")
		and GameManager.get_core_system("pools").has_method("get_pool_stats")
	):
		var pool_stats: Dictionary = GameManager.get_core_system("pools").get_pool_stats()
		if pool_stats.size() > 0:
			text += "\n--- Object Pools ---\n"
			for pool_name: String in pool_stats:
				var stats: Dictionary = pool_stats[pool_name]
				if stats.has("active") and stats.has("total"):
					text += "%s: %d/%d\n" % [pool_name, stats.active, stats.total]

	# Add warnings
	if report.fps.current < 45.0:  # warning_fps threshold
		text += "\n⚠ WARNING: Low FPS!"
	if report.memory_mb > 1500.0:  # warning_memory_mb threshold
		text += "\n⚠ WARNING: High memory usage!"
	if report.orphan_node_count > 100:
		text += "\n⚠ WARNING: Memory leak detected!"

	_debug_label.text = text

	# Adjust background size to fit text
	var text_size: Vector2 = _debug_label.get_minimum_size()
	_background_panel.custom_minimum_size = text_size + Vector2(20, 20)


func toggle_overlay() -> void:
	show_overlay = not show_overlay

	if show_overlay:
		show_debug_overlay()
	else:
		hide_debug_overlay()


func show_debug_overlay() -> void:
	show_overlay = true
	if _debug_label:
		_debug_label.show()
	if _background_panel:
		_background_panel.show()

	# Enable profiling in GameManager.get_core_system("performance")
	GameManager.get_core_system("performance").enable_profiling = true

	GameManager.get_core_system("logger").info(
		"[PerformanceProfiler] Debug overlay enabled", "Core"
	)


func hide_debug_overlay() -> void:
	show_overlay = false
	if _debug_label:
		_debug_label.hide()
	if _background_panel:
		_background_panel.hide()

	GameManager.get_core_system("logger").info(
		"[PerformanceProfiler] Debug overlay disabled", "Core"
	)


func _on_performance_warning(metric: String, value: float, threshold: float) -> void:
	GameManager.get_core_system("logger").info(
		"[PerformanceProfiler] WARNING: %s = %.1f (threshold: %.1f)" % [metric, value, threshold],
		"Core"
	)


func _on_performance_critical(metric: String, value: float, threshold: float) -> void:
	var msg: String = "[PerformanceProfiler] CRITICAL: %s = %.1f (threshold: %.1f)"
	push_warning(msg % [metric, value, threshold])


func generate_report() -> String:
	var report: Dictionary = GameManager.get_core_system("performance").get_performance_report()
	var recs: Array[String] = (
		GameManager.get_core_system("performance").get_optimization_recommendations()
	)

	var text: String = ""
	text += "=== Performance Optimization Report ===\n\n"

	# Performance metrics
	text += "## Performance Metrics\n"
	text += "- Current FPS: %.1f\n" % report.fps.current
	text += "- Average FPS: %.1f\n" % report.fps.average
	text += "- Min FPS: %.1f\n" % report.fps.min
	text += "- Max FPS: %.1f\n" % report.fps.max
	text += "- Frame Time: %.2f ms\n" % report.frame_time_ms
	text += "- Memory Usage: %.1f MB\n" % report.memory_mb
	text += "- Object Count: %d\n" % report.object_count
	text += "- Node Count: %d\n\n" % report.node_count

	# Performance status
	text += "## Performance Status\n"
	var target_fps: float = 60.0
	var warning_memory: float = 1500.0
	if report.fps.average >= target_fps:
		text += "✓ FPS meets target (%.0f FPS)\n" % target_fps
	else:
		text += "✗ FPS below target (%.0f FPS)\n" % target_fps

	if report.memory_mb < warning_memory:
		text += "✓ Memory usage acceptable\n"
	else:
		text += "✗ Memory usage high\n"

	text += "\n"

	# Recommendations
	text += "## Optimization Recommendations\n"
	for rec in recs:
		text += "- %s\n" % rec

	text += "\n=== End of Report ===\n"

	return text
