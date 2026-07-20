@tool
extends Control
class_name SkillTreeNodeUI

signal node_clicked(skill_id: String)
signal node_hovered(skill_id: String)
signal node_unhovered(skill_id: String)

const COLOR_LOCKED = Color(0.3, 0.3, 0.3)
const COLOR_AVAILABLE = Color(1.0, 0.8, 0.2)
const COLOR_UNLOCKED = Color(0.4, 0.8, 0.4)
const COLOR_MAXED = Color(0.9, 0.6, 0.2)  # For multi-point skills if we had them

@export var skill_id: String = ""
@export var is_circle: bool = true

var _bg_rect: Control  # Changed from ColorRect to Panel (Control)
var _border: ReferenceRect
var _icon: TextureRect
var _label: Label
var _current_state: int = 0  # 0=locked, 1=available, 2=unlocked


func _set_is_circle(value: bool) -> void:
	is_circle = value
	if _bg_rect:
		var style: StyleBoxFlat = _bg_rect.get_theme_stylebox("panel")
		if style:
			var radius: int = 40 if is_circle else 5
			style.corner_radius_top_left = radius
			style.corner_radius_top_right = radius
			style.corner_radius_bottom_right = radius
			style.corner_radius_bottom_left = radius


# Node state colors

# UI References


func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	pivot_offset = custom_minimum_size / 2

	_setup_visuals()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


func _process(_delta: float) -> void:
	# Pulse animation for available nodes
	if _current_state == 1:  # AVAILABLE
		var t: float = Time.get_ticks_msec() / 1000.0
		var pulse: float = 0.8 + 0.2 * sin(t * 5.0)
		if _bg_rect:
			_bg_rect.modulate = Color(1.2, 1.2, 1.2, 1.0) * pulse  # Brightness pulse


func _setup_visuals() -> void:
	# Background (Using Panel with StyleBox for circle)
	_bg_rect = Panel.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 40
	style.corner_radius_top_right = 40
	style.corner_radius_bottom_right = 40
	style.corner_radius_bottom_left = 40
	style.bg_color = COLOR_LOCKED
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.1, 0.1)
	style.anti_aliasing = true

	_bg_rect.add_theme_stylebox_override("panel", style)
	add_child(_bg_rect)

	# Icon
	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Padding
	_icon.offset_left = 16
	_icon.offset_top = 16
	_icon.offset_right = -16
	_icon.offset_bottom = -16
	add_child(_icon)

	# Selection/Hover Border (Ring)
	_border = ReferenceRect.new()  # Using RefRect as placeholder or switch to another Panel
	# Better to use a separate Panel for ring or just modify style border
	# Let's use the style border for state, and a separate highlight for selection
	# Keeping _border variable but using it as a Highlight Ring

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = 5
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func setup(skill: SkillNode, unlocked: bool, available: bool) -> void:
	skill_id = skill.skill_id
	_label.text = skill.display_name

	# Load icon if available
	if skill.icon_path and ResourceLoader.exists(skill.icon_path):
		_icon.texture = load(skill.icon_path)

	set_state(unlocked, available)


func set_state(unlocked: bool, available: bool) -> void:
	var style: StyleBoxFlat = _bg_rect.get_theme_stylebox("panel")
	_bg_rect.modulate = Color.WHITE  # Reset pulse

	if unlocked:
		style.bg_color = COLOR_UNLOCKED
		style.border_color = Color.WHITE
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		_current_state = 2
		_label.modulate = Color(1, 1, 1, 1)
	elif available:
		style.bg_color = COLOR_AVAILABLE
		style.border_color = Color(1, 1, 0.6)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		_current_state = 1
		_label.modulate = Color(1, 1, 1, 0.8)
	else:
		style.bg_color = COLOR_LOCKED
		style.border_color = Color(0.1, 0.1, 0.1)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		_current_state = 0
		_label.modulate = Color(1, 1, 1, 0.5)


func _draw() -> void:
	pass  # No custom draw needed with StyleBox


func _on_mouse_entered() -> void:
	scale = Vector2(1.1, 1.1)
	node_hovered.emit(skill_id)


func _on_mouse_exited() -> void:
	scale = Vector2(1.0, 1.0)
	node_unhovered.emit(skill_id)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		node_clicked.emit(skill_id)
