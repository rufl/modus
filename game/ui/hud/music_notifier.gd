extends PanelContainer

## Displays a "Now Playing" notification when music changes

var _label: Label
var _tween: Tween


func _ready() -> void:
	name = "MusicNotifier"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Layout settings - Anchor to bottom right with margin
	# We want it to be in the bottom right corner, growing towards top-left
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	# Simple stylebox
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

	_label = Label.new()
	_label.text = "Now Playing: Unknown"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_label)

	modulate.a = 0.0

	# Connect to Audio System
	_connect_audio()


func _exit_tree() -> void:
	# Cleanup: disconnect from audio system
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager:
		var audio: Node = manager.get_core_system("audio")
		if audio and audio.has_signal("music_changed"):
			if audio.music_changed.is_connected(_on_music_changed):
				audio.music_changed.disconnect(_on_music_changed)


func _connect_audio() -> void:
	# Wait for GameManager to be ready if needed
	var manager: Node = get_node_or_null("/root/GameManager")
	if not manager:
		push_warning("[MusicNotifier] GameManager not found")
		return

	# Wait for GameManager to be in READY or RUNNING state
	if manager.has_method("get_state") and manager.get_state() == 0:  # State.INITIALIZING
		if manager.has_signal("state_changed"):
			await manager.state_changed
		else:
			# Fallback: wait a bit
			await get_tree().create_timer(1.0).timeout

	var audio: Node = manager.get_core_system("audio")
	if audio:
		if audio.has_signal("music_changed"):
			audio.music_changed.connect(_on_music_changed)
			print("[MusicNotifier] Connected to audio system music_changed signal")
		else:
			push_warning("[MusicNotifier] Audio system has no music_changed signal")

		# If music is already playing, show it
		if audio.has_method("get_current_song_name"):
			var song: String = audio.get_current_song_name()
			if not song.is_empty():
				_on_music_changed(song)
	else:
		push_warning("[MusicNotifier] Audio system not available")


func _on_music_changed(song_name: String) -> void:
	if _label:
		_label.text = "Now Playing: " + song_name

	_show_notification()


func _show_notification() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	# Animation sequence
	_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	_tween.tween_interval(4.0)
	_tween.tween_property(self, "modulate:a", 0.0, 1.5)
