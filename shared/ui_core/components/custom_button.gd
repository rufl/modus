@tool
class_name CustomButton
extends Button

signal hover_changed(is_hovered: bool)
signal animation_completed

@export_group("Animation")
@export var animate_enabled: bool = true
@export var animation_duration: float = 0.1
@export var hover_scale: float = 1.02
@export var press_scale: float = 0.98
@export_group("Audio")
@export var audio_enabled: bool = true
@export var hover_sound: String = "ui_hover"
@export var press_sound: String = "ui_select"
@export_group("Focus")
@export var focus_glow_color: Color = Color(0.5, 0.7, 1.0, 0.3)
@export var focus_glow_enabled: bool = true

var _base_scale: Vector2 = Vector2.ONE
var _current_tween: Tween = null
var _is_hovered: bool = false


func _ready() -> void:
	_base_scale = scale
	pivot_offset = size / 2

	# Connect signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	resized.connect(_on_resized)

	# Register with ThemeManager if available
	if not Engine.is_editor_hint():
		_register_theme()


func _register_theme() -> void:
	# Defer to ensure ThemeManager is ready
	await get_tree().process_frame

	var theme_mgr: Node = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.register_themeable(self)


func _on_resized() -> void:
	pivot_offset = size / 2


# ============================================================================
# HOVER ANIMATIONS
# ============================================================================


func _on_mouse_entered() -> void:
	_is_hovered = true
	hover_changed.emit(true)

	if animate_enabled and not _is_reduced_motion():
		_animate_hover_in()

	if audio_enabled and not Engine.is_editor_hint():
		_play_sound(hover_sound)


func _on_mouse_exited() -> void:
	_is_hovered = false
	hover_changed.emit(false)

	if animate_enabled and not _is_reduced_motion():
		_animate_hover_out()


func _animate_hover_in() -> void:
	_cancel_tween()
	_current_tween = create_tween()
	(
		_current_tween
		. tween_property(self, "scale", _base_scale * hover_scale, animation_duration)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)


func _animate_hover_out() -> void:
	_cancel_tween()
	_current_tween = create_tween()
	_current_tween.tween_property(self, "scale", _base_scale, animation_duration).set_ease(
		Tween.EASE_OUT
	)


# ============================================================================
# PRESS ANIMATIONS
# ============================================================================


func _on_button_down() -> void:
	if animate_enabled and not _is_reduced_motion():
		_animate_press_down()

	if audio_enabled and not Engine.is_editor_hint():
		_play_sound(press_sound)


func _on_button_up() -> void:
	if animate_enabled and not _is_reduced_motion():
		_animate_press_up()


func _animate_press_down() -> void:
	_cancel_tween()
	_current_tween = create_tween()
	(
		_current_tween
		. tween_property(self, "scale", _base_scale * press_scale, animation_duration * 0.5)
		. set_ease(Tween.EASE_OUT)
	)


func _animate_press_up() -> void:
	_cancel_tween()
	_current_tween = create_tween()

	# Spring back effect
	var target: Vector2 = _base_scale * hover_scale if _is_hovered else _base_scale

	(
		_current_tween
		. tween_property(self, "scale", target, animation_duration)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)

	_current_tween.finished.connect(func() -> void: animation_completed.emit(), CONNECT_ONE_SHOT)


# ============================================================================
# FOCUS HANDLING
# ============================================================================


func _on_focus_entered() -> void:
	if focus_glow_enabled and not _is_reduced_motion():
		_show_focus_glow()

	# Treat focus like hover for gamepad
	if not _is_hovered:
		_is_hovered = true
		hover_changed.emit(true)
		if animate_enabled and not _is_reduced_motion():
			_animate_hover_in()


func _on_focus_exited() -> void:
	if focus_glow_enabled:
		_hide_focus_glow()

	_is_hovered = false
	hover_changed.emit(false)
	if animate_enabled and not _is_reduced_motion():
		_animate_hover_out()


func _show_focus_glow() -> void:
	# Use modulate for simple glow effect
	# A more advanced implementation could use shaders
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.1, 1.1, 1.2, 1.0), 0.15)


func _hide_focus_glow() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)


# ============================================================================
# UTILITIES
# ============================================================================


func _cancel_tween() -> void:
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()
	_current_tween = null


func _play_sound(sound_id: String) -> void:
	if Engine.is_editor_hint():
		return

	var audio: Node = GameManager.get_core_system("audio")
	if audio and audio.has_method("play_sound"):
		audio.play_sound(sound_id)


func _is_reduced_motion() -> bool:
	if Engine.is_editor_hint():
		return false

	var theme_mgr: Node = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		return theme_mgr.is_reduced_motion()

	return false


## Set the base scale (useful if you want non-1.0 default)


func set_base_scale(new_scale: Vector2) -> void:
	_base_scale = new_scale
	scale = new_scale


## Force reset to idle state


func reset_animation() -> void:
	_cancel_tween()
	scale = _base_scale
	modulate = Color.WHITE
	_is_hovered = false


func _exit_tree() -> void:
	# Disconnect all signals to prevent memory leaks
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)
	if button_down.is_connected(_on_button_down):
		button_down.disconnect(_on_button_down)
	if button_up.is_connected(_on_button_up):
		button_up.disconnect(_on_button_up)
	if focus_entered.is_connected(_on_focus_entered):
		focus_entered.disconnect(_on_focus_entered)
	if focus_exited.is_connected(_on_focus_exited):
		focus_exited.disconnect(_on_focus_exited)
	if resized.is_connected(_on_resized):
		resized.disconnect(_on_resized)

	# Cancel any running tweens
	_cancel_tween()
