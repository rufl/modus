extends Node

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])



signal screen_opened(screen_id: String, screen: Control)
signal screen_closed(screen_id: String)
signal modal_shown(modal_id: String, modal: Control)
signal modal_dismissed(modal_id: String)
signal transition_started(from_screen: String, to_screen: String)
signal transition_completed(screen_id: String)
signal navigation_changed(stack_size: int)

enum TransitionType { NONE, FADE, SLIDE_LEFT, SLIDE_RIGHT, SLIDE_UP, SLIDE_DOWN, DISSOLVE, SCALE }

const LAYER_SCREENS: int = 10
const LAYER_MODALS: int = 20
const LAYER_TOOLTIPS: int = 30

var _screen_stack: Array[Dictionary] = []
var _current_screen: Control = null
var _current_screen_id: String = ""
var _modal_stack: Array[Dictionary] = []
var _screen_cache: Dictionary = {}
var _transitioning: bool = false
var _screen_layer: CanvasLayer = null
var _modal_layer: CanvasLayer = null
var _tooltip_layer: CanvasLayer = null
var _transitions_enabled: bool = true
var _transition_duration: float = 0.3
var _default_transition: TransitionType = TransitionType.FADE
var _max_cache_size: int = 5


func is_transitioning() -> bool:
	return _transitioning


## Canvas layers for different UI depths

## Transition settings (loaded from config)

## Maximum cached screens

# ============================================================================
# LIFECYCLE
# ============================================================================


func _ready() -> void:
	name = "UIManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_layers()
	_load_config()

	# Managed by UISystem - no need for global registration
	_log("[UIManager] Initialized", "UIManager")

	# Register events with GameManager
	_register_events()


func _setup_layers() -> void:
	# Screen layer (base UI)
	_screen_layer = CanvasLayer.new()
	_screen_layer.name = "UIScreenLayer"
	_screen_layer.layer = LAYER_SCREENS
	add_child(_screen_layer)

	# Modal layer (dialogs, popups)
	_modal_layer = CanvasLayer.new()
	_modal_layer.name = "UIModalLayer"
	_modal_layer.layer = LAYER_MODALS
	add_child(_modal_layer)

	# Tooltip layer (hints, tooltips)
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "UITooltipLayer"
	_tooltip_layer.layer = LAYER_TOOLTIPS
	add_child(_tooltip_layer)


func _load_config() -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		return

	# Temporarily disabled for debugging
	_transitions_enabled = cfg.get_value("ui.transitions.enabled", false)
	_transition_duration = cfg.get_value("ui.transitions.duration", 0.3)

	# Temporarily none for debugging
	var transition_type: String = cfg.get_value("ui.transitions.type", "none")
	_default_transition = _parse_transition_type(transition_type)


func _register_events() -> void:
	# GameManager handles event registration internally
	# Events can be emitted directly without pre-registration
	pass


# ============================================================================
# SCREEN NAVIGATION
# ============================================================================

## Open a screen, replacing the current one (no stack push)


func open_screen(
	screen_path: String, params: Dictionary = {}, transition: TransitionType = TransitionType.FADE
) -> Control:
	if _transitioning:
		push_warning("[UIManager] Cannot open screen during transition")
		return null

	var screen_id: String = _get_screen_id(screen_path)
	var previous_id: String = _current_screen_id

	# Emit transition start
	transition_started.emit(previous_id, screen_id)

	# Close current screen
	if _current_screen:
		await _close_screen_internal(_current_screen, transition)

	# Open new screen
	var screen: Control = await _open_screen_internal(screen_path, params, transition)

	if screen:
		_current_screen = screen
		_current_screen_id = screen_id

		# Update navigation stack (replace mode - clear stack)
		_screen_stack.clear()
		_screen_stack.append({"path": screen_path, "id": screen_id, "params": params})

		screen_opened.emit(screen_id, screen)
		navigation_changed.emit(_screen_stack.size())

		if GameManager:
			GameManager.emit_event("screen_opened", {"screen_id": screen_id})

		transition_completed.emit(screen_id)

	return screen


## Push a screen onto the stack (preserves previous for back navigation)


func push_screen(
	screen_path: String,
	params: Dictionary = {},
	transition: TransitionType = TransitionType.SLIDE_LEFT
) -> Control:
	if _transitioning:
		push_warning("[UIManager] Cannot push screen during transition")
		return null

	var screen_id: String = _get_screen_id(screen_path)
	var previous_id: String = _current_screen_id

	transition_started.emit(previous_id, screen_id)

	# Hide current screen (but keep in cache)
	if _current_screen:
		await _hide_screen_internal(_current_screen, transition)
		_cache_screen(_current_screen_id, _current_screen)

	# Open new screen
	var screen: Control = await _open_screen_internal(screen_path, params, transition)

	if screen:
		_current_screen = screen
		_current_screen_id = screen_id

		# Add to stack
		_screen_stack.append({"path": screen_path, "id": screen_id, "params": params})

		screen_opened.emit(screen_id, screen)
		navigation_changed.emit(_screen_stack.size())

		if GameManager:
			GameManager.emit_event("screen_opened", {"screen_id": screen_id})

		transition_completed.emit(screen_id)

	return screen


## Go back to the previous screen in the stack


func back(transition: TransitionType = TransitionType.SLIDE_RIGHT) -> bool:
	if _transitioning:
		return false

	if _screen_stack.size() <= 1:
		var logger: Node = GameManager.get_core_system("logger")
		if logger and logger.has_method("debug"):
			logger.debug("[UIManager] Cannot go back - at root screen", "UIManager")
		return false

	var closing_entry: Dictionary = _screen_stack.pop_back()
	var previous_entry: Dictionary = _screen_stack.back()

	transition_started.emit(closing_entry.id, previous_entry.id)

	# Close current
	if _current_screen:
		await _close_screen_internal(_current_screen, transition)
		screen_closed.emit(closing_entry.id)

		if GameManager:
			GameManager.emit_event("screen_closed", {"screen_id": closing_entry.id})

	# Restore previous from cache or reload
	var previous_screen: Control = _get_cached_screen(previous_entry.id)
	if not previous_screen:
		previous_screen = await _open_screen_internal(
			previous_entry.path, previous_entry.params, transition
		)
	else:
		# CRITICAL: Add to tree FIRST, because anchor presets only work
		# when the Control is inside the scene tree
		_screen_layer.add_child(previous_screen)
		await _show_screen_internal(previous_screen, transition)

	if previous_screen:
		_current_screen = previous_screen
		_current_screen_id = previous_entry.id

		screen_opened.emit(previous_entry.id, previous_screen)
		navigation_changed.emit(_screen_stack.size())
		transition_completed.emit(previous_entry.id)

	return true


## Check if we can go back


func can_go_back() -> bool:
	return _screen_stack.size() > 1


## Get current screen ID


func get_current_screen_id() -> String:
	return _current_screen_id


## Get navigation stack depth


func get_stack_depth() -> int:
	return _screen_stack.size()


## Clear all screens and navigation


func clear_all() -> void:
	# Close all modals
	while not _modal_stack.is_empty():
		await dismiss_modal()

	# Close current screen
	if _current_screen:
		_current_screen.queue_free()
		_current_screen = null
		_current_screen_id = ""

	# Clear cache
	for screen: Control in _screen_cache.values():
		if is_instance_valid(screen):
			screen.queue_free()
	_screen_cache.clear()

	# Clear stack
	_screen_stack.clear()
	navigation_changed.emit(0)


# ============================================================================
# MODAL HANDLING
# ============================================================================

## Show a modal dialog


func push_modal(modal_path: String, params: Dictionary = {}, block_input: bool = true) -> Control:
	var modal_id: String = _get_screen_id(modal_path)

	# Load modal scene
	var scene: PackedScene = null
	if FileAccess.file_exists(modal_path):
		scene = load(modal_path)

	var modal: Control = null

	if not scene:
		# Fallback: Create procedural modal for confirmation dialogs
		var logger: Node = GameManager.get_core_system("logger")
		if logger and logger.has_method("warning"):
			logger.warning(
				"[UIManager] Modal scene not found: %s - creating procedural fallback" % modal_path,
				"UIManager"
			)
		modal = _create_procedural_modal(params)
	else:
		modal = scene.instantiate()

	if not modal:
		push_error("[UIManager] Failed to create modal from path: %s" % modal_path)
		return null

	# Add backdrop if blocking
	var backdrop: ColorRect = null
	if block_input:
		backdrop = ColorRect.new()
		backdrop.name = "ModalBackdrop"
		backdrop.color = Color(0, 0, 0, 0.5)
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_modal_layer.add_child(backdrop)

		# Fade in backdrop
		backdrop.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(backdrop, "modulate:a", 1.0, 0.2)

	# Add modal
	_modal_layer.add_child(modal)

	# Apply params if modal has setup method
	if modal.has_method("setup"):
		modal.setup(params)

	# Animate in
	modal.modulate.a = 0.0
	modal.scale = Vector2(0.9, 0.9)
	modal.pivot_offset = modal.size / 2

	var modal_tween: Tween = create_tween().set_parallel()
	modal_tween.tween_property(modal, "modulate:a", 1.0, 0.2)
	modal_tween.tween_property(modal, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
	await modal_tween.finished

	# Track modal
	_modal_stack.append({"id": modal_id, "modal": modal, "backdrop": backdrop, "path": modal_path})

	modal_shown.emit(modal_id, modal)

	if GameManager:
		GameManager.emit_event("modal_shown", {"modal_id": modal_id})

	return modal


## Dismiss the topmost modal


func dismiss_modal() -> void:
	if _modal_stack.is_empty():
		return

	var entry: Dictionary = _modal_stack.pop_back()
	var modal: Control = entry.modal
	var backdrop: ColorRect = entry.backdrop

	# Animate out
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(modal, "modulate:a", 0.0, 0.15)
	tween.tween_property(modal, "scale", Vector2(0.9, 0.9), 0.15)

	if backdrop:
		tween.tween_property(backdrop, "modulate:a", 0.0, 0.15)

	await tween.finished

	modal.queue_free()
	if backdrop:
		backdrop.queue_free()

	modal_dismissed.emit(entry.id)

	if GameManager:
		GameManager.emit_event("modal_dismissed", {"modal_id": entry.id})


## Dismiss all modals


func dismiss_all_modals() -> void:
	while not _modal_stack.is_empty():
		await dismiss_modal()


## Check if any modal is open


func has_open_modal() -> bool:
	return not _modal_stack.is_empty()


# ============================================================================
# INTERNAL SCREEN MANAGEMENT
# ============================================================================


func _open_screen_internal(path: String, params: Dictionary, transition: TransitionType) -> Control:
	_transitioning = true

	# Check cache first
	var screen_id: String = _get_screen_id(path)
	var screen: Control = _get_cached_screen(screen_id)

	if not screen:
		# Load fresh
		var scene: PackedScene = load(path)
		if not scene:
			push_error("[UIManager] Failed to load screen: %s" % path)
			_transitioning = false
			return null

		screen = scene.instantiate()

	# Add to layer
	_screen_layer.add_child(screen)

	# Apply params if screen has setup method
	if screen.has_method("setup"):
		screen.setup(params)

	# Apply transition
	if _transitions_enabled and transition != TransitionType.NONE:
		await _apply_enter_transition(screen, transition)

	_transitioning = false
	return screen


func _close_screen_internal(screen: Control, transition: TransitionType) -> void:
	_transitioning = true

	if _transitions_enabled and transition != TransitionType.NONE:
		await _apply_exit_transition(screen, transition)

	screen.queue_free()
	_transitioning = false


func _hide_screen_internal(screen: Control, transition: TransitionType) -> void:
	_transitioning = true

	if _transitions_enabled and transition != TransitionType.NONE:
		await _apply_exit_transition(screen, transition)

	screen.get_parent().remove_child(screen)
	_transitioning = false


func _show_screen_internal(screen: Control, transition: TransitionType) -> void:
	_transitioning = true

	# CRITICAL: Reset position and ensure full-screen anchors before showing
	# This fixes layout issues when restoring cached screens that had exit transitions
	screen.position = Vector2.ZERO
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.modulate.a = 1.0
	screen.scale = Vector2.ONE

	if _transitions_enabled and transition != TransitionType.NONE:
		await _apply_enter_transition(screen, transition)

	_transitioning = false


# ============================================================================
# TRANSITIONS
# ============================================================================


func _apply_enter_transition(screen: Control, transition: TransitionType) -> void:
	var tween: Tween = create_tween()

	match transition:
		TransitionType.FADE:
			screen.modulate.a = 0.0
			tween.tween_property(screen, "modulate:a", 1.0, _transition_duration)

		TransitionType.SLIDE_LEFT:
			var start_pos: float = get_viewport().get_visible_rect().size.x
			screen.position.x = start_pos
			(
				tween
				. tween_property(screen, "position:x", 0.0, _transition_duration)
				. set_ease(Tween.EASE_OUT)
				. set_trans(Tween.TRANS_CUBIC)
			)

		TransitionType.SLIDE_RIGHT:
			var start_pos: float = -get_viewport().get_visible_rect().size.x
			screen.position.x = start_pos
			(
				tween
				. tween_property(screen, "position:x", 0.0, _transition_duration)
				. set_ease(Tween.EASE_OUT)
				. set_trans(Tween.TRANS_CUBIC)
			)

		TransitionType.SLIDE_UP:
			var start_pos: float = get_viewport().get_visible_rect().size.y
			screen.position.y = start_pos
			(
				tween
				. tween_property(screen, "position:y", 0.0, _transition_duration)
				. set_ease(Tween.EASE_OUT)
				. set_trans(Tween.TRANS_CUBIC)
			)

		TransitionType.SLIDE_DOWN:
			var start_pos: float = -get_viewport().get_visible_rect().size.y
			screen.position.y = start_pos
			(
				tween
				. tween_property(screen, "position:y", 0.0, _transition_duration)
				. set_ease(Tween.EASE_OUT)
				. set_trans(Tween.TRANS_CUBIC)
			)

		TransitionType.SCALE:
			screen.scale = Vector2(0.8, 0.8)
			screen.modulate.a = 0.0
			screen.pivot_offset = screen.size / 2
			tween.set_parallel()
			tween.tween_property(screen, "scale", Vector2.ONE, _transition_duration).set_ease(
				Tween.EASE_OUT
			)
			tween.tween_property(screen, "modulate:a", 1.0, _transition_duration)

		TransitionType.DISSOLVE:
			screen.modulate.a = 0.0
			tween.tween_property(screen, "modulate:a", 1.0, _transition_duration * 1.5)

	await tween.finished


func _apply_exit_transition(screen: Control, transition: TransitionType) -> void:
	var tween: Tween = create_tween()

	match transition:
		TransitionType.FADE:
			tween.tween_property(screen, "modulate:a", 0.0, _transition_duration)

		TransitionType.SLIDE_LEFT:
			var end_pos: float = -get_viewport().get_visible_rect().size.x
			(
				tween
				. tween_property(screen, "position:x", end_pos, _transition_duration)
				. set_ease(Tween.EASE_IN)
				. set_trans(Tween.TRANS_CUBIC)
			)

		TransitionType.SLIDE_RIGHT:
			var end_pos: float = get_viewport().get_visible_rect().size.x
			(
				tween
				. tween_property(screen, "position:x", end_pos, _transition_duration)
				. set_ease(Tween.EASE_IN)
				. set_trans(Tween.TRANS_CUBIC)
			)

		TransitionType.SLIDE_UP:
			var end_pos: float = -get_viewport().get_visible_rect().size.y
			(
				tween
				. tween_property(screen, "position:y", end_pos, _transition_duration)
				. set_ease(Tween.EASE_IN)
				. set_trans(Tween.TRANS_CUBIC)
			)

		TransitionType.SLIDE_DOWN:
			var end_pos: float = get_viewport().get_visible_rect().size.y
			(
				tween
				. tween_property(screen, "position:y", end_pos, _transition_duration)
				. set_ease(Tween.EASE_IN)
				. set_trans(Tween.TRANS_CUBIC)
			)

		TransitionType.SCALE:
			screen.pivot_offset = screen.size / 2
			tween.set_parallel()
			tween.tween_property(screen, "scale", Vector2(0.8, 0.8), _transition_duration).set_ease(
				Tween.EASE_IN
			)
			tween.tween_property(screen, "modulate:a", 0.0, _transition_duration)

		TransitionType.DISSOLVE:
			tween.tween_property(screen, "modulate:a", 0.0, _transition_duration * 1.5)

	await tween.finished


# ============================================================================
# CACHING
# ============================================================================


func _cache_screen(screen_id: String, screen: Control) -> void:
	# Enforce cache limit
	if _screen_cache.size() >= _max_cache_size:
		var oldest_key: String = _screen_cache.keys().front()
		var oldest: Control = _screen_cache[oldest_key]
		if is_instance_valid(oldest):
			oldest.queue_free()
		_screen_cache.erase(oldest_key)

	_screen_cache[screen_id] = screen


## Get a cached screen and remove it from cache
## Returns Control if found and valid, null if not cached or invalid
## Null is a valid return value indicating screen needs to be loaded
func _get_cached_screen(screen_id: String) -> Control:
	if not _screen_cache.has(screen_id):
		return null  # Screen not in cache

	var screen: Control = _screen_cache[screen_id]
	if not is_instance_valid(screen):
		_screen_cache.erase(screen_id)
		return null  # Cached screen is invalid

	# Remove from cache (will be re-added if needed)
	_screen_cache.erase(screen_id)
	return screen


# ============================================================================
# UTILITIES
# ============================================================================


func _get_screen_id(path: String) -> String:
	# Extract filename without extension as ID
	return path.get_file().get_basename()


func _parse_transition_type(type_name: String) -> TransitionType:
	match type_name.to_lower():
		"none":
			return TransitionType.NONE
		"fade":
			return TransitionType.FADE
		"slide_left":
			return TransitionType.SLIDE_LEFT
		"slide_right":
			return TransitionType.SLIDE_RIGHT
		"slide_up":
			return TransitionType.SLIDE_UP
		"slide_down":
			return TransitionType.SLIDE_DOWN
		"dissolve":
			return TransitionType.DISSOLVE
		"scale":
			return TransitionType.SCALE
		_:
			return TransitionType.FADE


## Set transition settings at runtime


func set_transitions_enabled(enabled: bool) -> void:
	_transitions_enabled = enabled


func set_transition_duration(duration: float) -> void:
	_transition_duration = clampf(duration, 0.05, 2.0)


func set_default_transition(transition: TransitionType) -> void:
	_default_transition = transition


## Create a procedural modal popup (fallback when scene doesn't exist)


func _create_procedural_modal(params: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ProceduralModal"
	panel.custom_minimum_size = Vector2(400, 200)
	panel.set_anchors_preset(Control.PRESET_CENTER)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	var title_label: Label = Label.new()
	title_label.text = params.get("title", "Confirm")
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Message
	var message_label: Label = Label.new()
	message_label.text = params.get("message", "Are you sure?")
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.y = 60
	vbox.add_child(message_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 20
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Buttons
	var button_hbox: HBoxContainer = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(button_hbox)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = params.get("cancel_text", "Cancel")
	cancel_btn.custom_minimum_size = Vector2(120, 48)
	cancel_btn.focus_mode = Control.FOCUS_ALL
	cancel_btn.pressed.connect(
		func() -> void:
			if params.has("on_cancel") and params.on_cancel is Callable:
				params.on_cancel.call()
			dismiss_modal()
	)
	button_hbox.add_child(cancel_btn)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = params.get("confirm_text", "Confirm")
	confirm_btn.custom_minimum_size = Vector2(120, 48)
	confirm_btn.focus_mode = Control.FOCUS_ALL
	confirm_btn.pressed.connect(
		func() -> void:
			if params.has("on_confirm") and params.on_confirm is Callable:
				params.on_confirm.call()
			dismiss_modal()
	)
	button_hbox.add_child(confirm_btn)

	return panel
