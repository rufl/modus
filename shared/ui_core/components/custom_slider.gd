@tool
class_name CustomSlider
extends HSlider

signal value_committed(new_value: float)

@export_group("Binding")
@export var config_key: String = ""
@export var auto_save: bool = true
@export_group("Display")
@export var show_value: bool = true
@export var value_format: String = "%.0f"
@export var value_suffix: String = ""
@export var display_multiplier: float = 1.0
@export_group("Behavior")
@export var commit_delay: float = 0.0
@export var snap_on_release: bool = false
@export_group("Audio")
@export var audio_enabled: bool = true
@export var tick_sound: String = "ui_tick"
@export var tick_threshold: float = 0.05

var _value_label: Label = null
var _is_dragging: bool = false
var _last_tick_value: float = 0.0
var _commit_timer: Timer = null
var _pending_value: float = 0.0


func _ready() -> void:
	# Create value label
	if show_value:
		_create_value_label()

	# Create commit timer
	if commit_delay > 0:
		_commit_timer = Timer.new()
		_commit_timer.one_shot = true
		_commit_timer.timeout.connect(_on_commit_timer_timeout)
		add_child(_commit_timer)

	# Connect signals
	value_changed.connect(_on_value_changed)
	drag_started.connect(_on_internal_drag_started)
	drag_ended.connect(_on_internal_drag_ended)

	# Load from config
	if not Engine.is_editor_hint() and not config_key.is_empty():
		_load_from_config()

	# Register with ThemeManager
	if not Engine.is_editor_hint():
		_register_theme()

	_last_tick_value = value
	_update_value_label()


func _create_value_label() -> void:
	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.custom_minimum_size = Vector2(50, 0)

	# Position to the right of the slider
	# The parent should handle layout, but we set a tooltip as fallback
	tooltip_text = _format_value(value)

	# We can't easily add a sibling label from here
	# Instead, update the tooltip with the value


func _register_theme() -> void:
	await get_tree().process_frame

	var theme_mgr: Node = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.register_themeable(self)


# ============================================================================
# VALUE HANDLING
# ============================================================================


func _on_value_changed(new_value: float) -> void:
	_update_value_label()
	_play_tick_sound(new_value)

	if commit_delay > 0:
		_pending_value = new_value
		_commit_timer.start(commit_delay)
	else:
		_commit_value(new_value)


func _commit_value(val: float) -> void:
	value_committed.emit(val)

	if auto_save and not config_key.is_empty() and not Engine.is_editor_hint():
		_save_to_config(val)


func _on_commit_timer_timeout() -> void:
	_commit_value(_pending_value)


func _update_value_label() -> void:
	var display: String = _format_value(value)
	tooltip_text = display

	if _value_label:
		_value_label.text = display


func _format_value(val: float) -> String:
	var display_val: float = val * display_multiplier
	return (value_format % display_val) + value_suffix


# ============================================================================
# DRAG HANDLING
# ============================================================================


func _on_internal_drag_started() -> void:
	_is_dragging = true


func _on_internal_drag_ended() -> void:
	_is_dragging = false

	if snap_on_release and step > 0:
		value = snappedf(value, step)


# ============================================================================
# AUDIO
# ============================================================================


func _play_tick_sound(new_value: float) -> void:
	if not audio_enabled or Engine.is_editor_hint():
		return

	if absf(new_value - _last_tick_value) >= tick_threshold:
		_last_tick_value = new_value

		var audio: Node = GameManager.get_core_system("audio")
		if audio and audio.has_method("play_sound"):
			audio.play_sound(tick_sound)


# ============================================================================
# CONFIG PERSISTENCE
# ============================================================================


func _load_from_config() -> void:
	if config_key.is_empty():
		return

	var config: Node = GameManager.get_core_system("config")
	if not config or not config.has_method("get_value"):
		return

	var saved_value: float = config.get_value(config_key, value)
	set_value_no_signal(saved_value)
	_update_value_label()


func _save_to_config(val: float) -> void:
	if config_key.is_empty():
		return

	var config: Node = GameManager.get_core_system("config")
	if not config or not config.has_method("set_value"):
		return

	config.set_value(config_key, val, true)


# ============================================================================
# PUBLIC METHODS
# ============================================================================

## Set value without triggering signals


func set_value_silent(new_value: float) -> void:
	set_value_no_signal(new_value)
	_update_value_label()


## Bind to a config key


func bind_to_config(key: String, save_on_change: bool = true) -> void:
	config_key = key
	auto_save = save_on_change
	_load_from_config()


## Get the formatted display value


func get_display_value() -> String:
	return _format_value(value)


func _exit_tree() -> void:
	# Disconnect all signals to prevent memory leaks
	if value_changed.is_connected(_on_value_changed):
		value_changed.disconnect(_on_value_changed)
	if drag_started.is_connected(_on_internal_drag_started):
		drag_started.disconnect(_on_internal_drag_started)
	if drag_ended.is_connected(_on_internal_drag_ended):
		drag_ended.disconnect(_on_internal_drag_ended)

	# Clean up timer if it exists
	if _commit_timer and _commit_timer.timeout.is_connected(_on_commit_timer_timeout):
		_commit_timer.timeout.disconnect(_on_commit_timer_timeout)
