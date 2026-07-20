@tool
class_name LevelDebugOverlay
extends CanvasLayer

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])



signal overlay_toggled(enabled: bool)

var is_enabled: bool = false
var overlay_container: Control
var info_panel: PanelContainer
var channel_label: Label
var spawn_label: Label
var fps_label: Label
var level_root: Node3D = null
var channel_system: Node = null


func _ready() -> void:
	layer = 100  # On top of everything
	_create_ui()
	visible = false


func _create_ui() -> void:
	# Main container
	overlay_container = Control.new()
	overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_container)

	# Info panel (top-left)
	info_panel = PanelContainer.new()
	info_panel.position = Vector2(10, 10)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_container.add_child(info_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	info_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "🔧 DEBUG OVERLAY"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(title)

	# FPS
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(fps_label)

	# Channel info
	channel_label = Label.new()
	channel_label.text = "Channels: --"
	channel_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(channel_label)

	# Spawn info
	spawn_label = Label.new()
	spawn_label.text = "Spawns: --"
	spawn_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(spawn_label)

	# Set panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	info_panel.add_theme_stylebox_override("panel", style)


func _process(_delta: float) -> void:
	if not is_enabled:
		return

	# Update FPS
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# Update channel stats
	if channel_label and channel_system and "channels" in channel_system:
		var ch_count: int = channel_system.channels.size()
		channel_label.text = "Channels: %d active" % ch_count

	# Update spawn point stats
	if spawn_label:
		var player_spawns := get_tree().get_nodes_in_group("spawn_player").size()
		var enemy_spawns := get_tree().get_nodes_in_group("spawn_enemy").size()
		var item_spawns := get_tree().get_nodes_in_group("spawn_item").size()
		spawn_label.text = "Spawns: P:%d E:%d I:%d" % [player_spawns, enemy_spawns, item_spawns]

	# Request redraw for connection visualization
	overlay_container.queue_redraw()


## Setup with level references


func setup(root: Node3D, channels: Node) -> void:
	level_root = root
	channel_system = channels


## Toggle overlay visibility


func toggle() -> void:
	is_enabled = not is_enabled
	visible = is_enabled
	overlay_toggled.emit(is_enabled)

	if is_enabled:
		_log("[DebugOverlay] Enabled", "Log")
	else:
		_log("[DebugOverlay] Disabled", "Log")


## Enable the overlay


func enable() -> void:
	is_enabled = true
	visible = true
	overlay_toggled.emit(true)


## Disable the overlay


func disable() -> void:
	is_enabled = false
	visible = false
	overlay_toggled.emit(false)


## Draw channel connections (called during _draw)


func _draw_connections(control: Control) -> void:
	if not channel_system or not "channels" in channel_system:
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var channels: Dictionary = channel_system.channels

	for channel_name in channels:
		var channel_data: Dictionary = channels[channel_name]
		var sources: Array = channel_data.get("sources", [])
		var targets: Array = channel_data.get("targets", [])
		var color: Color = channel_data.get("color", Color.WHITE)

		for source in sources:
			if not is_instance_valid(source):
				continue

			var source_pos := camera.unproject_position(source.global_position)

			for target in targets:
				if not is_instance_valid(target):
					continue

				var target_pos := camera.unproject_position(target.global_position)

				# Check if on screen
				if not camera.is_position_in_frustum(source.global_position):
					continue
				if not camera.is_position_in_frustum(target.global_position):
					continue

				# Draw line
				control.draw_line(source_pos, target_pos, color, 2.0)

				# Draw arrow at midpoint
				var mid := (source_pos + target_pos) / 2.0
				var dir := (target_pos - source_pos).normalized()
				var perp := Vector2(-dir.y, dir.x)

				control.draw_polygon(
					[mid + dir * 10, mid - dir * 5 + perp * 5, mid - dir * 5 - perp * 5], [color]
				)


## Draw spawn point indicators


func _draw_spawn_markers(control: Control) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	# Draw player spawns
	for spawn in get_tree().get_nodes_in_group("spawn_player"):
		if spawn is Node3D:
			_draw_spawn_icon(control, camera, spawn, Color(0.2, 0.5, 1.0), "P")

	# Draw enemy spawns
	for spawn in get_tree().get_nodes_in_group("spawn_enemy"):
		if spawn is Node3D:
			_draw_spawn_icon(control, camera, spawn, Color(1.0, 0.3, 0.2), "E")

	# Draw item spawns
	for spawn in get_tree().get_nodes_in_group("spawn_item"):
		if spawn is Node3D:
			_draw_spawn_icon(control, camera, spawn, Color(1.0, 0.8, 0.2), "I")


func _draw_spawn_icon(
	control: Control, camera: Camera3D, spawn: Node3D, color: Color, letter: String
) -> void:
	if not camera.is_position_in_frustum(spawn.global_position):
		return

	var screen_pos := camera.unproject_position(spawn.global_position)
	var font := ThemeDB.fallback_font
	var offset := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, 16) / 2

	# Draw circle
	control.draw_circle(screen_pos, 20, color)
	control.draw_arc(screen_pos, 20, 0, TAU, 32, Color.WHITE, 2.0)

	# Draw letter (centered)
	if font:
		control.draw_string(
			font,
			screen_pos - offset + Vector2(0, 5),
			letter,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16,
			Color.WHITE
		)


## Handle input for toggling


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# F3 to toggle debug overlay
		if event.keycode == KEY_F3 and not Engine.is_editor_hint():
			toggle()
