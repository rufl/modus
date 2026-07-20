class_name DownedStateHUD
extends Control

const GIVE_UP_TIME: float = 1.0

var _bleedout_container: Control = null
var _bleedout_timer_bar: ProgressBar = null
var _bleedout_timer_label: Label = null
var _revive_progress_bar: ProgressBar = null
var _revive_prompt_label: Label = null
var _downed_overlay: ColorRect = null
var _local_player: Node = null
var _is_player_downed: bool = false
var _nearby_downed_player: Node = null
var _give_up_timer: float = 0.0
var _give_up_prompt_label: Label = null


func _ready() -> void:
	_create_ui()
	hide()  # Hidden by default

	# Wait for player to be ready
	await get_tree().process_frame
	_connect_to_player()


func _create_ui() -> void:
	# Screen overlay for downed state (red vignette)
	_downed_overlay = ColorRect.new()
	_downed_overlay.name = "DownedOverlay"
	_downed_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_downed_overlay.color = Color(0.5, 0.0, 0.0, 0.0)  # Start transparent
	_downed_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_downed_overlay)

	# Center container for bleedout info
	_bleedout_container = Control.new()
	_bleedout_container.name = "BleedoutContainer"
	_bleedout_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bleedout_container.position = Vector2(-200, -150)
	_bleedout_container.size = Vector2(400, 120)
	add_child(_bleedout_container)

	# "DOWNED" title
	var title_label: Label = Label.new()
	title_label.text = "DOWNED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.position = Vector2(0, 0)
	title_label.size = Vector2(400, 40)
	_bleedout_container.add_child(title_label)

	# Bleedout timer label
	_bleedout_timer_label = Label.new()
	_bleedout_timer_label.name = "BleedoutTimerLabel"
	_bleedout_timer_label.text = "Bleedout: 30s"
	_bleedout_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bleedout_timer_label.add_theme_font_size_override("font_size", 24)
	_bleedout_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_bleedout_timer_label.position = Vector2(0, 45)
	_bleedout_timer_label.size = Vector2(400, 30)
	_bleedout_container.add_child(_bleedout_timer_label)

	# Bleedout timer bar
	_bleedout_timer_bar = ProgressBar.new()
	_bleedout_timer_bar.name = "BleedoutTimerBar"
	_bleedout_timer_bar.min_value = 0
	_bleedout_timer_bar.max_value = 100
	_bleedout_timer_bar.value = 100
	_bleedout_timer_bar.show_percentage = false
	_bleedout_timer_bar.position = Vector2(50, 80)
	_bleedout_timer_bar.size = Vector2(300, 20)

	# Style the bar
	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bar_style.corner_radius_bottom_left = 4
	bar_style.corner_radius_bottom_right = 4
	bar_style.corner_radius_top_left = 4
	bar_style.corner_radius_top_right = 4
	_bleedout_timer_bar.add_theme_stylebox_override("background", bar_style)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.2, 0.2, 1.0)
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	_bleedout_timer_bar.add_theme_stylebox_override("fill", fill_style)

	_bleedout_container.add_child(_bleedout_timer_bar)

	# Give Up Prompt
	_give_up_prompt_label = Label.new()
	_give_up_prompt_label.text = "Hold [G] to Give Up"
	_give_up_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_give_up_prompt_label.add_theme_font_size_override("font_size", 18)
	_give_up_prompt_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	_give_up_prompt_label.position = Vector2(0, 105)
	_give_up_prompt_label.size = Vector2(400, 25)
	_bleedout_container.add_child(_give_up_prompt_label)

	_bleedout_container.hide()

	# Revive progress bar (shown when being revived)
	_revive_progress_bar = ProgressBar.new()
	_revive_progress_bar.name = "ReviveProgressBar"
	_revive_progress_bar.min_value = 0
	_revive_progress_bar.max_value = 100
	_revive_progress_bar.value = 0
	_revive_progress_bar.show_percentage = false
	_revive_progress_bar.set_anchors_preset(Control.PRESET_CENTER)
	_revive_progress_bar.position = Vector2(-150, 50)
	_revive_progress_bar.size = Vector2(300, 25)

	var revive_fill: StyleBoxFlat = StyleBoxFlat.new()
	revive_fill.bg_color = Color(0.2, 0.8, 0.2, 1.0)
	revive_fill.corner_radius_bottom_left = 4
	revive_fill.corner_radius_bottom_right = 4
	revive_fill.corner_radius_top_left = 4
	revive_fill.corner_radius_top_right = 4
	_revive_progress_bar.add_theme_stylebox_override("fill", revive_fill)
	_revive_progress_bar.add_theme_stylebox_override("background", bar_style)

	add_child(_revive_progress_bar)
	_revive_progress_bar.hide()

	# Revive prompt (shown when near downed ally)
	_revive_prompt_label = Label.new()
	_revive_prompt_label.name = "RevivePromptLabel"
	_revive_prompt_label.text = "Hold [E] to revive"
	_revive_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_revive_prompt_label.add_theme_font_size_override("font_size", 20)
	_revive_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
	_revive_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	_revive_prompt_label.position = Vector2(-150, 100)
	_revive_prompt_label.size = Vector2(300, 30)
	add_child(_revive_prompt_label)
	_revive_prompt_label.hide()


func _connect_to_player() -> void:
	# Find local player
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D and node.is_multiplayer_authority():
			_local_player = node
			break

	if _local_player:
		# Connect to downed handler signals if available
		if _local_player.has_node("DownedHandler"):
			var handler: DownedStateHandler = _local_player.get_node("DownedHandler")
			handler.revived.connect(_on_player_revived)
			handler.bleedout_expired.connect(_on_player_died)
			handler.revive_progress_changed.connect(_on_revive_progress_changed)
			handler.time_remaining.connect(_on_time_remaining)

		# Hide entirely if no downed state to show
		if not _is_player_downed:
			hide()


func _process(delta: float) -> void:
	if not _local_player or not is_instance_valid(_local_player):
		return

	# Check if player is downed
	if "is_downed" in _local_player and _local_player.is_downed:
		_update_downed_ui()
		_handle_give_up_input(delta)
	else:
		_check_nearby_downed_allies()
		_give_up_timer = 0.0


func _handle_give_up_input(delta: float) -> void:
	# Use G key instead of jump/space to avoid conflict with spectator mode
	if Input.is_key_pressed(KEY_G):
		_give_up_timer += delta

		# Show visual feedback on the bleedout bar or a separate bar
		# For now, let's just use the bleedout bar color or text
		if _bleedout_timer_bar:
			_bleedout_timer_bar.modulate = Color(1, 0, 0, 1)  # Red warning
			_give_up_prompt_label.text = "Giving Up... %.1f" % (GIVE_UP_TIME - _give_up_timer)

		if _give_up_timer >= GIVE_UP_TIME:
			# Trigger give up
			_give_up_timer = 0.0
			if _local_player.has_node("DownedHandler"):
				_local_player.get_node("DownedHandler").request_bleedout()
	else:
		_give_up_timer = 0.0
		if _bleedout_timer_bar:
			_bleedout_timer_bar.modulate = Color(1, 1, 1, 1)
			_give_up_prompt_label.text = "Hold [G] to Give Up"


func _update_downed_ui() -> void:
	if not _is_player_downed:
		_is_player_downed = true
		show()
		_bleedout_container.show()
		_downed_overlay.color.a = 0.3  # Show red overlay

	# Update bleedout timer using new API
	if _local_player.has_node("DownedHandler"):
		var handler: DownedStateHandler = _local_player.get_node("DownedHandler")

		# get_bleedout_progress returns 0.0 (just downed) to 1.0 (about to expire)
		var bleedout_progress: float = handler.get_bleedout_progress()
		var remaining_time: float = handler.bleedout_timer

		_bleedout_timer_label.text = "Bleedout: %ds" % ceili(remaining_time)
		# Bar shows time remaining (100% = full time, 0% = expired)
		_bleedout_timer_bar.value = (1.0 - bleedout_progress) * 100.0

		# Color based on bleedout progress
		var fill_color: Color = Color(0.8, 0.2, 0.2)
		if bleedout_progress > 0.66:  # Less than 10s remaining (at 30s max)
			fill_color = Color(1.0, 0.0, 0.0)  # Critical red
			# Pulse effect
			var pulse: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
			_bleedout_timer_bar.modulate.a = pulse
		elif bleedout_progress > 0.33:  # Less than 20s remaining
			fill_color = Color(1.0, 0.5, 0.0)  # Warning orange
			_bleedout_timer_bar.modulate.a = 1.0
		else:
			_bleedout_timer_bar.modulate.a = 1.0

		var current_fill: StyleBoxFlat = _bleedout_timer_bar.get_theme_stylebox("fill")
		var fill_style: StyleBoxFlat
		if current_fill:
			fill_style = current_fill.duplicate()
		else:
			fill_style = StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		_bleedout_timer_bar.add_theme_stylebox_override("fill", fill_style)

		# Update revive progress if being revived (using new API)
		if handler.is_being_revived and handler.revive_progress > 0:
			_revive_progress_bar.show()
			_revive_progress_bar.value = handler.revive_progress * 100.0
		else:
			_revive_progress_bar.hide()


func _check_nearby_downed_allies() -> void:
	if _is_player_downed:
		_is_player_downed = false
		_bleedout_container.hide()
		_revive_progress_bar.hide()
		_downed_overlay.color.a = 0.0

	# Check for nearby downed players
	_nearby_downed_player = null
	var min_dist: float = 3.0  # Revive range

	for node: Node in get_tree().get_nodes_in_group("player"):
		if node == _local_player:
			continue
		if not node is CharacterBody3D:
			continue
		if not "is_downed" in node or not node.is_downed:
			continue

		var dist: float = _local_player.global_position.distance_to(node.global_position)
		if dist < min_dist:
			_nearby_downed_player = node
			min_dist = dist

	# Show revive prompt if near downed ally
	if _nearby_downed_player:
		show()
		_revive_prompt_label.show()

		# Show revive progress if we're actively reviving (using new API)
		if _nearby_downed_player.has_node("DownedHandler"):
			var handler: DownedStateHandler = _nearby_downed_player.get_node("DownedHandler")
			if handler.is_being_revived and handler.revive_progress > 0:
				_revive_progress_bar.value = handler.revive_progress * 100.0
				_revive_progress_bar.show()
			else:
				_revive_progress_bar.hide()
	else:
		_revive_prompt_label.hide()
		_revive_progress_bar.hide()

		# Hide entirely if no downed state to show
		if not _is_player_downed:
			hide()


func _on_revive_progress_changed(progress: float) -> void:
	if _revive_progress_bar:
		_revive_progress_bar.value = progress * 100.0
		if progress > 0:
			_revive_progress_bar.show()


func _on_time_remaining(seconds: float) -> void:
	if _bleedout_timer_label:
		_bleedout_timer_label.text = "Bleedout: %ds" % seconds


func _on_player_revived() -> void:
	_is_player_downed = false
	_bleedout_container.hide()
	_revive_progress_bar.hide()
	_downed_overlay.color.a = 0.0

	# Show "REVIVED" message briefly
	var revived_label: Label = Label.new()
	revived_label.text = "REVIVED!"
	revived_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revived_label.add_theme_font_size_override("font_size", 48)
	revived_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	revived_label.set_anchors_preset(Control.PRESET_CENTER)
	revived_label.position = Vector2(-150, -50)
	revived_label.size = Vector2(300, 60)
	add_child(revived_label)

	var tween: Tween = create_tween()
	tween.tween_property(revived_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(revived_label.queue_free)


func _on_player_died() -> void:
	_is_player_downed = false
	_bleedout_container.hide()
	_revive_progress_bar.hide()
	hide()
