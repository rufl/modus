class_name TargetingFeedback
extends Control

signal lock_on_toggled(enabled: bool)
signal target_acquired_feedback(target: Node3D)
signal target_lost_feedback

@export var enable_target_sounds: bool = true
@export var enable_off_screen_indicators: bool = true
@export var enable_target_tooltips: bool = true
@export var indicator_distance_from_edge: float = 50.0
@export var tooltip_offset: Vector2 = Vector2(20, -20)
@export_group("Accessibility")
@export var colorblind_mode: bool = false
@export var highlight_intensity: float = 1.0
@export var highlights_enabled: bool = true
@export_group("Colors")
@export var target_color: Color = Color.RED
@export var enemy_color: Color = Color.YELLOW
@export var ally_color: Color = Color.GREEN

var is_locked_on: bool = false
var current_target: Node3D = null
var targeting_system: Node = null
var camera: Camera3D = null
var player: Node3D = null
var off_screen_indicators: Dictionary = {}  # target -> indicator Control
var target_tooltip: Control = null
var tooltip_label: Label = null


func _ready() -> void:
	# Prevent blocking mouse input
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create tooltip
	_create_tooltip()

	# Find targeting systems
	call_deferred("_find_targeting_systems")


func _process(_delta: float) -> void:
	if not enable_off_screen_indicators:
		return

	# Update off-screen indicators
	_update_off_screen_indicators()

	# Update tooltip position
	_update_tooltip_position()


func _find_targeting_systems() -> void:
	## Find targeting systems from player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Get targeting system
	if player.has_node("TargetingSystem"):
		targeting_system = player.get_node("TargetingSystem")
		if targeting_system.has_signal("target_acquired"):
			targeting_system.target_acquired.connect(_on_target_acquired)
		if targeting_system.has_signal("target_lost"):
			targeting_system.target_lost.connect(_on_target_lost)

	# Find camera - look for various common camera locations
	camera = _find_camera(player)


func _find_camera(node: Node) -> Camera3D:
	## Recursively find camera in node tree
	if node is Camera3D:
		return node

	# Check common camera paths
	var paths := ["Camera3D", "CameraController/Camera3D", "Head/Camera3D", "camera_pivot/Camera3D"]
	for camera_path: String in paths:
		var cam := node.get_node_or_null(camera_path) as Camera3D
		if cam:
			return cam

	# Recursive search
	for child in node.get_children():
		var cam := _find_camera(child)
		if cam:
			return cam

	return null


func _create_tooltip() -> void:
	## Create target info tooltip
	target_tooltip = Control.new()
	target_tooltip.name = "TargetTooltip"
	target_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_tooltip.visible = false
	add_child(target_tooltip)

	# Background panel
	var panel := Panel.new()
	panel.name = "Background"
	panel.custom_minimum_size = Vector2(200, 60)
	target_tooltip.add_child(panel)

	# Tooltip label
	tooltip_label = Label.new()
	tooltip_label.name = "Label"
	tooltip_label.position = Vector2(10, 10)
	tooltip_label.add_theme_font_size_override("font_size", 14)
	target_tooltip.add_child(tooltip_label)


func _update_off_screen_indicators() -> void:
	## Update positions of off-screen target indicators
	if not camera:
		camera = _find_camera(player) if player else null
		if not camera:
			return

	# Get all enemies in scene
	var all_targets: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var viewport_size := get_viewport_rect().size

	# Clean up indicators for targets that no longer exist
	var targets_to_remove: Array = []
	for target: Variant in off_screen_indicators.keys():
		if not is_instance_valid(target) or not all_targets.has(target):
			targets_to_remove.append(target)

	for target: Variant in targets_to_remove:
		var indicator: Control = off_screen_indicators[target]
		indicator.queue_free()
		off_screen_indicators.erase(target)

	# Update or create indicators for current targets
	for target in all_targets:
		if not is_instance_valid(target):
			continue

		# Check if target is on screen
		var target_pos: Vector3 = target.global_position
		if target.has_method("get_head_position"):
			target_pos = target.get_head_position()

		var screen_pos := camera.unproject_position(target_pos)
		var is_behind := (
			camera.global_transform.basis.z.dot(target_pos - camera.global_position) > 0
		)

		var is_on_screen := (
			not is_behind
			and screen_pos.x >= 0
			and screen_pos.x <= viewport_size.x
			and screen_pos.y >= 0
			and screen_pos.y <= viewport_size.y
		)

		if is_on_screen:
			# Hide indicator if on screen
			if off_screen_indicators.has(target):
				off_screen_indicators[target].visible = false
		else:
			# Show/create indicator if off screen
			var indicator := _get_or_create_indicator(target)
			indicator.visible = true

			# Calculate edge position
			var edge_pos := _calculate_edge_position(screen_pos, viewport_size, is_behind)
			indicator.position = edge_pos


func _get_or_create_indicator(target: Node3D) -> Control:
	## Get existing indicator or create new one
	if off_screen_indicators.has(target):
		return off_screen_indicators[target]

	# Create new indicator (arrow shape using polygon)
	var indicator := Control.new()
	indicator.name = "OffScreenIndicator_%s" % target.name
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create colored arrow
	var arrow := ColorRect.new()
	arrow.size = Vector2(20, 20)
	arrow.pivot_offset = Vector2(10, 10)

	# Set color based on target type
	if target == current_target:
		arrow.color = target_color
	else:
		arrow.color = enemy_color

	indicator.add_child(arrow)
	add_child(indicator)
	off_screen_indicators[target] = indicator

	return indicator


func _calculate_edge_position(
	screen_pos: Vector2, viewport_size: Vector2, is_behind: bool
) -> Vector2:
	## Calculate position on screen edge for off-screen target
	var center := viewport_size / 2
	var target_screen_pos := screen_pos

	# If target is behind camera, flip the direction
	if is_behind:
		target_screen_pos = center - (screen_pos - center)

	var direction := (target_screen_pos - center).normalized()
	var edge_pos := center

	# Calculate intersection with screen edges

	# Check horizontal edges
	if abs(direction.x) > abs(direction.y):
		# Left or right edge
		if direction.x > 0:
			edge_pos.x = viewport_size.x - indicator_distance_from_edge
		else:
			edge_pos.x = indicator_distance_from_edge

		if abs(direction.x) > 0.001:
			var t := (edge_pos.x - center.x) / direction.x
			edge_pos.y = center.y + direction.y * t
	else:
		# Top or bottom edge
		if direction.y > 0:
			edge_pos.y = viewport_size.y - indicator_distance_from_edge
		else:
			edge_pos.y = indicator_distance_from_edge

		if abs(direction.y) > 0.001:
			var t := (edge_pos.y - center.y) / direction.y
			edge_pos.x = center.x + direction.x * t

	# Clamp to screen bounds
	edge_pos.x = clamp(
		edge_pos.x, indicator_distance_from_edge, viewport_size.x - indicator_distance_from_edge
	)
	edge_pos.y = clamp(
		edge_pos.y, indicator_distance_from_edge, viewport_size.y - indicator_distance_from_edge
	)

	return edge_pos


func _update_tooltip_position() -> void:
	## Update tooltip position to follow current target
	if not enable_target_tooltips or not target_tooltip.visible:
		return

	if not current_target or not is_instance_valid(current_target) or not camera:
		target_tooltip.visible = false
		return

	# Get screen position
	var screen_pos := camera.unproject_position(current_target.global_position)
	target_tooltip.position = screen_pos + tooltip_offset


# Signal Handlers


func _on_target_acquired(enemy: Node3D) -> void:
	call_deferred("_deferred_on_target_acquired", enemy)


func _deferred_on_target_acquired(enemy: Node3D) -> void:
	## Handle target acquired
	current_target = enemy

	# Play target acquisition sound
	if enable_target_sounds:
		_play_target_acquired_sound()

	# Show tooltip
	if enable_target_tooltips:
		_show_target_tooltip(enemy)

	# Update off-screen indicator color
	if off_screen_indicators.has(enemy):
		var indicator: Control = off_screen_indicators[enemy]
		var arrow := indicator.get_child(0) as ColorRect
		if arrow:
			arrow.color = target_color

	target_acquired_feedback.emit(enemy)


func _on_target_lost(_previous_enemy: Node3D) -> void:
	call_deferred("_deferred_on_target_lost", _previous_enemy)


func _deferred_on_target_lost(_previous_enemy: Node3D) -> void:
	## Handle target lost
	current_target = null

	# Hide tooltip
	if target_tooltip:
		target_tooltip.visible = false

	target_lost_feedback.emit()


func _play_target_acquired_sound() -> void:
	## Play sound effect when acquiring target
	# Use GameManager.get_core_system("audio") if available
	if (
		GameManager.get_core_system("audio")
		and GameManager.get_core_system("audio").has_method("play_ui_sound")
	):
		GameManager.get_core_system("audio").play_ui_sound("target_acquired")


func _show_target_tooltip(enemy: Node3D) -> void:
	## Show tooltip with target information
	if not tooltip_label:
		return

	# Get target info
	var info_text := ""

	# Name
	if enemy.has_method("get_display_name"):
		info_text += enemy.get_display_name()
	else:
		info_text += enemy.name

	# Health percentage
	if enemy.has_method("get_health_percentage"):
		var health_pct: float = enemy.get_health_percentage() * 100.0
		info_text += "\nHealth: %.0f%%" % health_pct
	elif enemy.has_node("HealthComponent"):
		var health_comp: Node = enemy.get_node("HealthComponent")
		if "current_health" in health_comp and "max_health" in health_comp:
			var curr: float = float(health_comp.current_health)
			var max_hp: float = float(health_comp.max_health)
			var health_pct: float = (curr / max_hp) * 100.0
			info_text += "\nHealth: %.0f%%" % health_pct

	# Level
	if enemy.has_method("get_level"):
		var level: int = enemy.get_level()
		info_text += "\nLevel: %d" % level

	tooltip_label.text = info_text
	target_tooltip.visible = true


# Public API


func toggle_lock_on() -> void:
	## Toggle target lock-on
	is_locked_on = not is_locked_on
	lock_on_toggled.emit(is_locked_on)


func is_target_locked() -> bool:
	## Check if target is locked on
	return is_locked_on


func set_colorblind_mode(enabled: bool) -> void:
	## Enable/disable colorblind-friendly colors
	colorblind_mode = enabled

	if enabled:
		# Use colorblind-friendly palette
		target_color = Color(1.0, 0.5, 0.0)  # Orange instead of red
		enemy_color = Color(0.0, 0.5, 1.0)  # Blue instead of yellow
		ally_color = Color(1.0, 1.0, 0.0)  # Yellow instead of green
	else:
		# Standard colors
		target_color = Color.RED
		enemy_color = Color.YELLOW
		ally_color = Color.GREEN


func set_highlight_intensity(intensity: float) -> void:
	## Set highlight intensity (0.0 to 1.0)
	highlight_intensity = clamp(intensity, 0.0, 1.0)


func set_highlights_enabled(enabled: bool) -> void:
	## Enable/disable all highlights
	highlights_enabled = enabled


func get_settings() -> Dictionary:
	## Get current settings
	return {
		"colorblind_mode": colorblind_mode,
		"highlight_intensity": highlight_intensity,
		"highlights_enabled": highlights_enabled,
		"target_sounds": enable_target_sounds,
		"off_screen_indicators": enable_off_screen_indicators,
		"target_tooltips": enable_target_tooltips
	}


func apply_settings(settings: Dictionary) -> void:
	## Apply settings from dictionary
	if settings.has("colorblind_mode"):
		set_colorblind_mode(settings.colorblind_mode)

	if settings.has("highlight_intensity"):
		set_highlight_intensity(settings.highlight_intensity)

	if settings.has("highlights_enabled"):
		set_highlights_enabled(settings.highlights_enabled)

	if settings.has("target_sounds"):
		enable_target_sounds = settings.target_sounds

	if settings.has("off_screen_indicators"):
		enable_off_screen_indicators = settings.off_screen_indicators

	if settings.has("target_tooltips"):
		enable_target_tooltips = settings.target_tooltips


func clear_all_indicators() -> void:
	## Clear all off-screen indicators
	for target_key: Variant in off_screen_indicators.keys():
		var indicator: Control = off_screen_indicators[target_key]
		if is_instance_valid(indicator):
			indicator.queue_free()
	off_screen_indicators.clear()
