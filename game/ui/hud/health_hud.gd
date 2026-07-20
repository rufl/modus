extends Control

var armor_label: Label = null
var armor_bar: ProgressBar = null

@onready var health_label: Label = $VBoxContainer/HealthCount
@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar

var _max_health: float = 100.0
var _current_health: float = 100.0
var _max_armor: float = 200.0
var _current_armor: float = 0.0
var _critical_warning_playing: bool = false
var _low_warning_playing: bool = false
var _armor_low_warning_playing: bool = false

var _player_id: int = -1
var _health_changed_callback: Callable
var _armor_changed_callback: Callable


func _ready() -> void:
	_setup_ui_from_config()
	_update_visibility()

	# Listen for config changes
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc:
		ui_svc.hud_settings_changed.connect(_on_hud_settings_changed)
		ui_svc.theme_changed.connect(_on_theme_changed)

	# Wait for player to be ready, then connect
	await get_tree().process_frame
	_setup_armor_ui()
	_connect_to_player()


func _setup_ui_from_config() -> void:
	var ui_svc: Node = GameManager.get_core_system("ui")
	if not ui_svc:
		return

	var config: Dictionary = ui_svc.get_element_config("health_bar")

	# Apply scale
	var global_scale: float = ui_svc.get_hud_scale()
	var local_scale: float = config.get("scale", 1.0)
	scale = Vector2.ONE * global_scale * local_scale

	# Apply position offset if needed (assuming parent handles base positioning)
	var offset: Array = config.get("position_offset", [0, 0])
	if offset.size() >= 2:
		position += Vector2(offset[0], offset[1])

	_update_visibility()


func _on_hud_settings_changed() -> void:
	_setup_ui_from_config()


func _on_theme_changed() -> void:
	_update_health_display()


func _update_visibility() -> void:
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc:
		visible = ui_svc.is_hud_element_visible("health_bar")


func _setup_armor_ui() -> void:
	## Create armor display elements if they don't exist
	var vbox: VBoxContainer = get_node_or_null("VBoxContainer")
	if not vbox:
		return

	# Check if armor bar already exists
	armor_bar = vbox.get_node_or_null("ArmorBar")
	armor_label = vbox.get_node_or_null("ArmorLabel")

	if not armor_label:
		armor_label = Label.new()
		armor_label.name = "ArmorLabel"
		armor_label.add_theme_font_size_override("font_size", 14)
		var loc_svc: Node = GameManager.get_core_system("localization")
		armor_label.text = loc_svc.translate("hud_armor") if loc_svc else "Armor"
		armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(armor_label)
		vbox.move_child(armor_label, 0)  # Move to top

	if not armor_bar:
		armor_bar = ProgressBar.new()
		armor_bar.name = "ArmorBar"
		armor_bar.max_value = _max_armor
		armor_bar.value = 0
		armor_bar.show_percentage = false

		# Use theme accent color for armor if available
		var ui_svc: Node = GameManager.get_core_system("ui")
		var accent: Color = Color(0.3, 0.5, 1.0)
		if ui_svc:
			accent = ui_svc.get_theme_color("accent_color", accent)
		armor_bar.modulate = accent

		vbox.add_child(armor_bar)
		vbox.move_child(armor_bar, 1)  # After armor label

	# Initially hide armor if zero
	_update_armor_visibility()


func _connect_to_player() -> void:
	## Find our player to filter EventBus events
	var player: Node = get_parent()
	while player and not player is CharacterBody3D:
		player = player.get_parent()

	# Fallback: find local player via group
	if not player or not player.is_in_group("player"):
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		for p: Node in players:
			if p.is_multiplayer_authority():
				player = p
				break

	if not player:
		push_warning("[HealthHUD] Could not find player via parent or group")
		return

	# Store ID for filtering
	_player_id = player.get_instance_id()

	# Get initial values via Player property wrappers
	if "health" in player:
		_current_health = float(player.health)
		if "max_health" in player:
			_max_health = float(player.max_health)

	if "armor" in player:
		_current_armor = float(player.armor)
		if "max_armor" in player:
			_max_armor = float(player.max_armor)

	_update_health_display()
	_update_armor_display()
	_update_armor_visibility()

	# Create callable references for proper cleanup
	_health_changed_callback = func(params: Dictionary) -> void:
		if params.entity_id == _player_id:
			_on_health_changed(params.current, params.max)

	_armor_changed_callback = func(params: Dictionary) -> void:
		if params.entity_id == _player_id:
			_on_armor_changed(params.current, params.max)

	# Subscribe to EventBus
	GameManager.subscribe("health_changed", _health_changed_callback)
	GameManager.subscribe("armor_changed", _armor_changed_callback)

	set_process(false)


func _exit_tree() -> void:
	# Unsubscribe from GameManager events to prevent null callable errors
	if _health_changed_callback.is_valid():
		GameManager.unsubscribe("health_changed", _health_changed_callback)
	if _armor_changed_callback.is_valid():
		GameManager.unsubscribe("armor_changed", _armor_changed_callback)


func _process(_delta: float) -> void:
	## Fallback polling for legacy health property (only if HealthComponent not found)
	var player: Node = get_parent()
	while player and not player is CharacterBody3D:
		player = player.get_parent()

	if player and "health" in player:
		var health: float = float(player.health)
		if health != _current_health:
			_current_health = health
			_update_health_display()


func _on_health_changed(current: float, max_val: float) -> void:
	## Called when HealthComponent emits health_changed signal
	_current_health = current
	_max_health = max_val
	_update_health_display()


func _on_armor_changed(current: float, max_val: float) -> void:
	## Called when HealthComponent emits armor_changed signal
	_current_armor = current
	_max_armor = max_val
	_update_armor_display()
	_update_armor_visibility()


func _update_health_display() -> void:
	if health_label:
		health_label.text = str(int(_current_health))
	if health_bar:
		health_bar.max_value = _max_health
		health_bar.value = _current_health

	# Color based on health percentage
	var health_percent: float = _current_health / _max_health if _max_health > 0 else 0.0

	var ui_svc: Node = GameManager.get_core_system("ui")
	var danger_col: Color = Color(1.0, 0.3, 0.3)
	var warn_col: Color = Color(1.0, 0.7, 0.3)

	if ui_svc:
		danger_col = ui_svc.get_theme_color("danger_color", danger_col)
		warn_col = ui_svc.get_theme_color("primary_color", warn_col)
	var safe_col: Color = Color(0.3, 1.0, 0.3)  # Default safe green is usually fine/classic

	if health_percent <= 0.25:
		# Critical - danger color
		if health_label:
			health_label.add_theme_color_override("font_color", danger_col)
		if health_bar:
			health_bar.modulate = danger_col

		# Play critical health warning sound
		if GameManager.get_core_system("audio") and not _critical_warning_playing:
			GameManager.get_core_system("audio").play_sound_2d("pain", -8.0)
			_critical_warning_playing = true
			# Reset flag after cooldown
			await get_tree().create_timer(3.0).timeout
			_critical_warning_playing = false

		# Pulse animation for critical health
		_pulse_health_display()
	elif health_percent <= 0.5:
		# Low - warning color
		if health_label:
			health_label.add_theme_color_override("font_color", warn_col)
		if health_bar:
			health_bar.modulate = warn_col

		# Play low health warning sound (less urgent)
		if GameManager.get_core_system("audio") and not _low_warning_playing:
			GameManager.get_core_system("audio").play_sound_2d("ui_hover", -10.0)
			_low_warning_playing = true
			# Reset flag after cooldown
			await get_tree().create_timer(5.0).timeout
			_low_warning_playing = false
	else:
		# Normal - safe green
		if health_label:
			health_label.remove_theme_color_override("font_color")
		if health_bar:
			health_bar.modulate = safe_col
		_critical_warning_playing = false
		_low_warning_playing = false


func _pulse_health_display() -> void:
	## Create a pulsing animation for low health warning
	if not health_label:
		return

	var tween: Tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(health_label, "scale", Vector2(1.15, 1.15), 0.3)
	tween.tween_property(health_label, "scale", Vector2(1.0, 1.0), 0.3)


func _update_armor_display() -> void:
	if armor_bar:
		armor_bar.max_value = _max_armor
		armor_bar.value = _current_armor

	# Color based on armor percentage
	var armor_percent: float = _current_armor / _max_armor if _max_armor > 0 else 0.0

	if armor_percent > 0 and armor_percent <= 0.25:
		# Low armor - warning color
		var ui_svc: Node = GameManager.get_core_system("ui")
		var warn_col: Color = Color(1.0, 0.7, 0.3)
		if ui_svc:
			warn_col = ui_svc.get_theme_color("primary_color", warn_col)

		if armor_bar:
			armor_bar.modulate = warn_col

		# Play low armor warning sound
		if GameManager.get_core_system("audio") and not _armor_low_warning_playing:
			GameManager.get_core_system("audio").play_sound_2d("ui_hover", -12.0)
			_armor_low_warning_playing = true
			# Reset flag after cooldown
			await get_tree().create_timer(5.0).timeout
			_armor_low_warning_playing = false
	else:
		# Normal armor color (accent blue)
		var ui_svc: Node = GameManager.get_core_system("ui")
		var accent: Color = Color(0.3, 0.5, 1.0)
		if ui_svc:
			accent = ui_svc.get_theme_color("accent_color", accent)
		if armor_bar:
			armor_bar.modulate = accent
		_armor_low_warning_playing = false


func _update_armor_visibility() -> void:
	## Show/hide armor UI based on whether player has armor
	var show_armor: bool = _current_armor > 0
	if armor_label:
		armor_label.visible = show_armor
	if armor_bar:
		armor_bar.visible = show_armor
