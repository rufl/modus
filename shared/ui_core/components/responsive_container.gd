@tool
class_name ResponsiveContainer
extends MarginContainer

signal breakpoint_changed(new_breakpoint: Breakpoint)
signal orientation_changed(is_portrait: bool)

enum Breakpoint {
	MOBILE,  # < 600px
	TABLET,  # 600-1024px
	DESKTOP,  # 1024-1920px
	LARGE,  # > 1920px
}
enum Orientation {
	LANDSCAPE,
	PORTRAIT,
}

@export_group("Breakpoints")
@export var mobile_max: int = 600
@export var tablet_max: int = 1024
@export var desktop_max: int = 1920
@export_group("Margins")
@export var mobile_margins: Vector4 = Vector4(8, 8, 8, 8)
@export var tablet_margins: Vector4 = Vector4(16, 16, 16, 16)
@export var desktop_margins: Vector4 = Vector4(24, 24, 24, 24)
@export var large_margins: Vector4 = Vector4(32, 32, 32, 32)
@export_group("Content")
@export var max_content_width: int = 1200
@export var center_content: bool = true
@export var dpi_aware: bool = false
@export_group("Safe Areas")
@export var use_safe_areas: bool = true

var _current_breakpoint: Breakpoint = Breakpoint.DESKTOP
var _current_orientation: int = Orientation.LANDSCAPE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Connect to viewport resize
	get_viewport().size_changed.connect(_on_viewport_resized)

	# Initial update
	_update_layout()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_update_layout()


# ============================================================================
# LAYOUT
# ============================================================================


func _on_viewport_resized() -> void:
	_update_layout()


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var new_breakpoint: Breakpoint = _calculate_breakpoint(viewport_size.x)
	var new_orientation: int = _calculate_orientation(viewport_size)

	# Check for breakpoint change
	if new_breakpoint != _current_breakpoint:
		_current_breakpoint = new_breakpoint
		breakpoint_changed.emit(new_breakpoint)

	# Check for orientation change
	var is_portrait_now: bool = new_orientation == Orientation.PORTRAIT
	if new_orientation != _current_orientation:
		_current_orientation = new_orientation
		orientation_changed.emit(is_portrait_now)

	# Apply margins
	_apply_margins()

	# Apply safe areas
	if use_safe_areas:
		_apply_safe_areas()

	# Apply content width clamping
	_apply_content_width(viewport_size)


func _calculate_breakpoint(width: float) -> Breakpoint:
	if width <= mobile_max:
		return Breakpoint.MOBILE
	if width <= tablet_max:
		return Breakpoint.TABLET
	if width <= desktop_max:
		return Breakpoint.DESKTOP
	return Breakpoint.LARGE


func _calculate_orientation(viewport_size: Vector2) -> int:
	return Orientation.PORTRAIT if viewport_size.y > viewport_size.x else Orientation.LANDSCAPE


func _apply_margins() -> void:
	var margins: Vector4 = _get_margins_for_breakpoint(_current_breakpoint)

	# Apply DPI scaling if enabled
	if dpi_aware:
		var dpi_scale_factor: float = _get_dpi_scale()
		margins *= dpi_scale_factor

	add_theme_constant_override("margin_left", int(margins.x))
	add_theme_constant_override("margin_top", int(margins.y))
	add_theme_constant_override("margin_right", int(margins.z))
	add_theme_constant_override("margin_bottom", int(margins.w))


func _get_margins_for_breakpoint(bp: Breakpoint) -> Vector4:
	match bp:
		Breakpoint.MOBILE:
			return mobile_margins
		Breakpoint.TABLET:
			return tablet_margins
		Breakpoint.DESKTOP:
			return desktop_margins
		Breakpoint.LARGE:
			return large_margins
	return desktop_margins


func _apply_safe_areas() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var screen_size: Vector2i = DisplayServer.screen_get_size()

	# Only apply if safe area is different from full screen
	if safe_area.size != screen_size:
		var left: int = safe_area.position.x
		var top: int = safe_area.position.y
		var right: int = screen_size.x - (safe_area.position.x + safe_area.size.x)
		var bottom: int = screen_size.y - (safe_area.position.y + safe_area.size.y)

		# Add to existing margins
		var current_left: int = get_theme_constant("margin_left")
		var current_top: int = get_theme_constant("margin_top")
		var current_right: int = get_theme_constant("margin_right")
		var current_bottom: int = get_theme_constant("margin_bottom")

		add_theme_constant_override("margin_left", current_left + left)
		add_theme_constant_override("margin_top", current_top + top)
		add_theme_constant_override("margin_right", current_right + right)
		add_theme_constant_override("margin_bottom", current_bottom + bottom)


func _apply_content_width(viewport_size: Vector2) -> void:
	if max_content_width <= 0:
		return

	# Calculate available width after margins
	var margins: Vector4 = _get_margins_for_breakpoint(_current_breakpoint)
	var available: float = viewport_size.x - margins.x - margins.z

	if available > max_content_width:
		var extra: float = available - max_content_width
		if center_content:
			var side_margin: int = int(extra / 2)
			add_theme_constant_override("margin_left", int(margins.x) + side_margin)
			add_theme_constant_override("margin_right", int(margins.z) + side_margin)


func _get_dpi_scale() -> float:
	var base_dpi: float = 96.0
	var actual_dpi: float = DisplayServer.screen_get_dpi()

	if actual_dpi <= 0:
		return 1.0

	return clampf(actual_dpi / base_dpi, 0.75, 2.0)


# ============================================================================
# ACCESSORS
# ============================================================================

## Get the current breakpoint


func get_breakpoint() -> Breakpoint:
	return _current_breakpoint


## Get the current breakpoint as a string


func get_breakpoint_name() -> String:
	match _current_breakpoint:
		Breakpoint.MOBILE:
			return "mobile"
		Breakpoint.TABLET:
			return "tablet"
		Breakpoint.DESKTOP:
			return "desktop"
		Breakpoint.LARGE:
			return "large"
	return "unknown"


## Check if currently in portrait orientation


func is_portrait() -> bool:
	return _current_orientation == Orientation.PORTRAIT


## Check if currently in landscape orientation


func is_landscape() -> bool:
	return _current_orientation == Orientation.LANDSCAPE


## Check if at or below a certain breakpoint


func is_at_or_below(bp: Breakpoint) -> bool:
	return _current_breakpoint <= bp


## Check if at or above a certain breakpoint


func is_at_or_above(bp: Breakpoint) -> bool:
	return _current_breakpoint >= bp


## Check if is mobile


func is_mobile() -> bool:
	return _current_breakpoint == Breakpoint.MOBILE


## Check if is tablet or smaller


func is_tablet_or_smaller() -> bool:
	return _current_breakpoint <= Breakpoint.TABLET


## Get the current DPI scale factor


func get_dpi_scale() -> float:
	return _get_dpi_scale() if dpi_aware else 1.0


func _exit_tree() -> void:
	# Disconnect viewport signal to prevent memory leak
	var viewport := get_viewport()
	if viewport and viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.disconnect(_on_viewport_resized)
