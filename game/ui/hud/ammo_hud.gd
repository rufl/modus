extends Control

@onready var weapon_label: Label = $VBoxContainer/WeaponName
@onready var ammo_label: Label = $VBoxContainer/AmmoCount
@onready var reload_bar: ProgressBar = $VBoxContainer/ReloadBar

var _player: Node = null
var _reload_timer: float = 0.0
var _reload_duration: float = 0.0
var _is_reloading: bool = false

var _player_id: int = -1
var _ammo_changed_callback: Callable
var _reload_started_callback: Callable
var _reload_finished_callback: Callable


func _ready() -> void:
	reload_bar.hide()

	_setup_ui_from_config()
	_update_visibility()

	# Listen for config changes
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc:
		ui_svc.hud_settings_changed.connect(_on_hud_settings_changed)
		ui_svc.theme_changed.connect(_on_theme_changed)

	# Auto-find local player after scene is ready
	call_deferred("_find_and_setup_player")


func _exit_tree() -> void:
	# SECURITY FIX: Comprehensive signal cleanup to prevent memory leaks

	# 1. UI service signals
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc:
		if ui_svc.hud_settings_changed.is_connected(_on_hud_settings_changed):
			ui_svc.hud_settings_changed.disconnect(_on_hud_settings_changed)
		if ui_svc.theme_changed.is_connected(_on_theme_changed):
			ui_svc.theme_changed.disconnect(_on_theme_changed)

	# 2. EventBus subscriptions - unsubscribe from GameManager events
	if _ammo_changed_callback.is_valid():
		GameManager.unsubscribe("ammo_changed", _ammo_changed_callback)
	if _reload_started_callback.is_valid():
		GameManager.unsubscribe("reload_started", _reload_started_callback)
	if _reload_finished_callback.is_valid():
		GameManager.unsubscribe("reload_finished", _reload_finished_callback)

	# Clear player reference
	_player = null


func _setup_ui_from_config() -> void:
	var ui_svc: Node = GameManager.get_core_system("ui")
	if not ui_svc:
		return

	var config: Dictionary = ui_svc.get_element_config("ammo_counter")

	# Apply scale
	var global_scale: float = ui_svc.get_hud_scale()
	var local_scale: float = config.get("scale", 1.0)
	scale = Vector2.ONE * global_scale * local_scale

	# Apply position offset if needed
	var offset: Array = config.get("position_offset", [0, 0])
	if offset.size() >= 2:
		position += Vector2(offset[0], offset[1])

	_update_visibility()


func _on_hud_settings_changed() -> void:
	_setup_ui_from_config()


func _on_theme_changed() -> void:
	if weapon_label:
		# Could update label styling here if desired
		pass


func _update_visibility() -> void:
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc:
		visible = ui_svc.is_hud_element_visible("ammo_counter")


func _find_and_setup_player() -> void:
	# Give player time to spawn and initialize
	await get_tree().create_timer(0.1).timeout

	var player: Node = _find_local_player()
	if player:
		setup(player)
	else:
		# Retry after a short delay (player might not be spawned yet)
		await get_tree().create_timer(0.5).timeout
		player = _find_local_player()
		if player:
			setup(player)


func _find_local_player() -> Node:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p.is_multiplayer_authority():
			return p
	return null


func setup(player: Node) -> void:
	if not player:
		return

	_player = player
	_player_id = player.get_instance_id()

	# Get initial ammo state
	if "current_ammo" in player and "reserve_ammo" in player and "weapon_name" in player:
		_on_ammo_changed(player.current_ammo, player.reserve_ammo, player.weapon_name)

	# Create callable references for proper cleanup
	_ammo_changed_callback = func(params: Dictionary) -> void:
		if params.entity_id == _player_id:
			_on_ammo_changed(params.current, params.reserve, params.weapon_name)

	_reload_started_callback = func(params: Dictionary) -> void:
		if params.entity_id == _player_id:
			_on_reload_started(params.duration)

	_reload_finished_callback = func(params: Dictionary) -> void:
		if params.entity_id == _player_id:
			_on_reload_finished()

	# Subscribe to EventBus
	GameManager.subscribe("ammo_changed", _ammo_changed_callback)
	GameManager.subscribe("reload_started", _reload_started_callback)
	GameManager.subscribe("reload_finished", _reload_finished_callback)


func _process(delta: float) -> void:
	# Update reload progress bar
	if _is_reloading:
		_reload_timer -= delta
		reload_bar.value = 1.0 - (_reload_timer / _reload_duration)
		if _reload_timer <= 0:
			_is_reloading = false
			reload_bar.hide()


func _on_ammo_changed(current: int, reserve: int, weapon: String) -> void:
	var loc_svc: Node = GameManager.get_core_system("localization")
	weapon_label.text = loc_svc.translate(weapon) if loc_svc else weapon
	ammo_label.text = "%d / %d" % [current, reserve]

	# Flash red if low ammo (danger theme color)
	if current <= 3:
		var ui_svc: Node = GameManager.get_core_system("ui")
		var danger_col: Color = Color(1.0, 0.3, 0.3)
		if ui_svc:
			danger_col = ui_svc.get_theme_color("danger_color", danger_col)
		ammo_label.add_theme_color_override("font_color", danger_col)

		# Play low ammo warning sound when reaching critical threshold
		if current == 3 and GameManager.get_core_system("audio"):
			GameManager.get_core_system("audio").play_sound_2d("ui_hover", -5.0)  # Subtle warning beep

		# Pulse animation for critical ammo
		_pulse_ammo_label()
	else:
		ammo_label.remove_theme_color_override("font_color")


func _pulse_ammo_label() -> void:
	## Create a pulsing animation for low ammo warning
	if not ammo_label:
		return

	var tween: Tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(ammo_label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(ammo_label, "scale", Vector2(1.0, 1.0), 0.2)


func _on_reload_started(duration: float) -> void:
	_is_reloading = true
	_reload_duration = duration
	_reload_timer = duration
	reload_bar.value = 0.0
	reload_bar.show()


func _on_reload_finished() -> void:
	_is_reloading = false
	reload_bar.hide()
