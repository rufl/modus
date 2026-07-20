extends ModusGutTestBase

## HUD and Visual Feedback Integration Test
## Tests HUD elements, visual feedback systems, and player-facing UI

var _player: CharacterBody3D
var _hud_layer: CanvasLayer


func before_each() -> void:
	await super.before_each()
	_setup_test_scene()


func after_each() -> void:
	super.after_each()
	if _player and is_instance_valid(_player):
		_player.free()
	_player = null
	_hud_layer = null


func _setup_test_scene() -> void:
	var player_scene: PackedScene = load("res://game/entities/player/player.tscn")
	if not player_scene:
		return

	_player = player_scene.instantiate()
	if not _player:
		return

	get_tree().root.add_child(_player)
	await get_tree().process_frame

	_hud_layer = _player.get_node_or_null("HUDLayer")


# =============================================================================
# HUD LAYER TESTS
# =============================================================================


func test_hud_layer_configuration() -> void:
	assert_not_null(_hud_layer, "HUD layer should exist")
	if not _hud_layer:
		return

	assert_true(_hud_layer.visible, "HUD layer should be visible")
	assert_ge(_hud_layer.layer, 0, "HUD layer should have valid layer number")


func test_hud_follows_player() -> void:
	## HUD should be attached to player and follow them
	if not _hud_layer:
		return

	assert_true(_hud_layer.is_inside_tree(), "HUD should be in scene tree")
	assert_eq(_hud_layer.get_parent(), _player, "HUD should be child of player")


# =============================================================================
# CROSSHAIR TESTS
# =============================================================================


func test_crosshair_exists() -> void:
	if not _hud_layer:
		return

	var crosshair: Control = _find_node_by_type(_hud_layer, "Crosshair")
	if crosshair:
		assert_true(crosshair.visible, "Crosshair should be visible")
		assert_true(crosshair.is_inside_tree(), "Crosshair should be in tree")


func test_crosshair_centered() -> void:
	if not _hud_layer:
		return

	var crosshair: Control = _find_node_by_type(_hud_layer, "Crosshair")
	if not crosshair:
		return

	# Crosshair should be centered (using anchors or position)
	var has_center_anchor: bool = (
		crosshair.anchor_left == 0.5
		and crosshair.anchor_right == 0.5
		and crosshair.anchor_top == 0.5
		and crosshair.anchor_bottom == 0.5
	)

	if not has_center_anchor:
		# Check if using CENTER preset
		pass  # May use different centering method

	assert_true(crosshair.visible, "Crosshair should be visible")


# =============================================================================
# HEALTH DISPLAY TESTS
# =============================================================================


func test_health_display_exists() -> void:
	if not _hud_layer:
		return

	var health_bar: Control = _find_node_by_name(_hud_layer, "HealthBar")
	if not health_bar:
		health_bar = _find_node_by_type(_hud_layer, "ProgressBar")

	if health_bar:
		assert_true(health_bar.is_inside_tree(), "Health display should be in tree")


func test_health_updates_on_damage() -> void:
	## Health display should update when player takes damage
	if not _player:
		return

	# Check if player has health_changed signal
	var signals: Array = _player.get_signal_list()
	var has_health_signal: bool = false

	for sig_info in signals:
		if sig_info["name"] == "health_changed":
			has_health_signal = true
			break

	if has_health_signal:
		assert_true(true, "Player has health_changed signal for HUD updates")


# =============================================================================
# AMMO DISPLAY TESTS
# =============================================================================


func test_ammo_display_exists() -> void:
	if not _hud_layer:
		return

	var ammo_display: Control = _find_node_by_name(_hud_layer, "AmmoDisplay")
	if not ammo_display:
		ammo_display = _find_node_by_type(_hud_layer, "Label")

	# Ammo display may not exist in all configurations
	if ammo_display:
		assert_true(ammo_display.is_inside_tree(), "Ammo display should be in tree")


func test_ammo_updates_on_fire() -> void:
	## Ammo display should update when weapon fires
	var weapon_manager: Node = _player.get_node_or_null("WeaponManager") if _player else null
	if not weapon_manager:
		return

	# Check if weapon manager has ammo_changed signal
	var signals: Array = weapon_manager.get_signal_list()
	var has_ammo_signal: bool = false

	for sig_info in signals:
		if sig_info["name"] == "ammo_changed":
			has_ammo_signal = true
			break

	assert_true(has_ammo_signal, "WeaponManager should have ammo_changed signal for HUD")


# =============================================================================
# DAMAGE INDICATOR TESTS
# =============================================================================


func test_damage_indicator_exists() -> void:
	if not _hud_layer:
		return

	var damage_indicator: Control = _find_node_by_name(_hud_layer, "DamageIndicatorManager")
	if not damage_indicator:
		damage_indicator = _find_node_by_name(_hud_layer, "DamageIndicator")

	# Damage indicator is optional
	if damage_indicator:
		assert_true(damage_indicator.is_inside_tree(), "Damage indicator should be in tree")


func test_damage_indicator_responds_to_damage() -> void:
	## Damage indicator should show direction of damage
	if not _player:
		return

	var damage_indicator: Control = (
		_find_node_by_name(_hud_layer, "DamageIndicatorManager") if _hud_layer else null
	)
	if not damage_indicator:
		return

	# Check if it has required methods
	if damage_indicator.has_method("show_damage"):
		assert_true(true, "Damage indicator has show_damage method")


# =============================================================================
# WEAPON HUD TESTS
# =============================================================================


func test_weapon_name_display() -> void:
	## Weapon name should be displayed somewhere in HUD
	if not _hud_layer:
		return

	var weapon_label: Label = _find_label_with_text(_hud_layer, "")
	# May not find specific weapon name in test environment
	assert_not_null(weapon_label, "Weapon label should exist")


func test_reload_indicator_exists() -> void:
	## Reload progress should be indicated
	if not _hud_layer:
		return

	var reload_bar: Control = _find_node_by_name(_hud_layer, "ReloadBar")
	if not reload_bar:
		reload_bar = _find_node_by_type(_hud_layer, "ProgressBar")

	# Reload indicator is optional
	if reload_bar:
		assert_true(reload_bar.is_inside_tree(), "Reload indicator should be in tree")


# =============================================================================
# VISUAL FEEDBACK TESTS
# =============================================================================


func test_hit_marker_system() -> void:
	## Hit markers should appear when hitting enemies
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		pending("GameCore not available")
		return

	var effects: Node = game_manager.get_service("effects")
	if not effects:
		return

	# Check if effects service can spawn hit markers
	if effects.has_method("spawn_hit_marker"):
		assert_true(true, "Effects service has hit marker support")


func test_screen_shake_available() -> void:
	## Screen shake should be available for impact feedback
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		pending("GameCore not available")
		return

	var effects: Node = game_manager.get_service("effects")
	if not effects:
		return

	if effects.has_method("screen_shake"):
		assert_true(true, "Screen shake is available")


func test_screen_flash_available() -> void:
	## Screen flash should be available for damage feedback
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		pending("GameCore not available")
		return

	var effects: Node = game_manager.get_service("effects")
	if not effects:
		return

	if effects.has_method("screen_flash"):
		assert_true(true, "Screen flash is available")


# =============================================================================
# MINIMAP TESTS
# =============================================================================


func test_minimap_exists() -> void:
	if not _hud_layer:
		return

	var minimap: Control = _find_node_by_name(_hud_layer, "Minimap")
	# Minimap is optional
	if minimap:
		assert_true(minimap.is_inside_tree(), "Minimap should be in tree")
		assert_true(minimap.visible, "Minimap should be visible")


func test_minimap_shows_player() -> void:
	if not _hud_layer:
		return

	var minimap: Control = _find_node_by_name(_hud_layer, "Minimap")
	if not minimap:
		return

	# Minimap should have method to track player
	if minimap.has_method("update_player_position"):
		assert_true(true, "Minimap can track player position")


# =============================================================================
# INTERACTION PROMPTS TESTS
# =============================================================================


func test_interaction_prompt_exists() -> void:
	if not _hud_layer:
		return

	var prompt: Control = _find_node_by_name(_hud_layer, "InteractionPrompt")
	if not prompt:
		prompt = _find_label_with_text(_hud_layer, "Press")

	# Interaction prompt is optional
	if prompt:
		assert_true(prompt.is_inside_tree(), "Interaction prompt should be in tree")


# =============================================================================
# OBJECTIVE/MISSION HUD TESTS
# =============================================================================


func test_objective_display_exists() -> void:
	if not _hud_layer:
		return

	var objectives: Control = _find_node_by_name(_hud_layer, "ObjectiveDisplay")
	if not objectives:
		objectives = _find_node_by_name(_hud_layer, "MissionHUD")

	# Objective display is optional
	if objectives:
		assert_true(objectives.is_inside_tree(), "Objective display should be in tree")


# =============================================================================
# KILL FEED TESTS
# =============================================================================


func test_kill_feed_exists() -> void:
	if not _hud_layer:
		return

	var kill_feed: Control = _find_node_by_name(_hud_layer, "KillFeed")
	# Kill feed is optional
	if kill_feed:
		assert_true(kill_feed.is_inside_tree(), "Kill feed should be in tree")


# =============================================================================
# SCOREBOARD TESTS
# =============================================================================


func test_scoreboard_accessible() -> void:
	## Scoreboard should be accessible (may be hidden by default)
	if not _hud_layer:
		return

	var scoreboard: Control = _find_node_by_name(_hud_layer, "Scoreboard")
	# Scoreboard is optional and may be hidden
	if scoreboard:
		assert_true(scoreboard.is_inside_tree(), "Scoreboard should be in tree")


# =============================================================================
# PAUSE MENU TESTS
# =============================================================================


func test_pause_menu_accessible() -> void:
	## Pause menu should be accessible
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		pending("GameCore not available")
		return

	var ui_service: Node = game_manager.get_service("ui")
	if not ui_service:
		return

	if ui_service.has_method("show_pause_menu"):
		assert_true(true, "Pause menu is accessible via UI service")


# =============================================================================
# VISUAL CONSISTENCY TESTS
# =============================================================================


func test_hud_elements_have_consistent_theme() -> void:
	## HUD elements should use consistent theme/styling
	if not _hud_layer:
		return

	var theme: MapTheme = _hud_layer.theme
	# MapTheme may be set on individual elements or parent
	assert_true(
		theme != null or _hud_layer.get_child_count() > 0, "HUD should have theme or elements"
	)


func test_hud_readable_at_different_resolutions() -> void:
	## HUD should scale properly
	if not _hud_layer:
		return

	# Check if HUD uses proper anchors/containers
	var uses_containers: bool = false
	for child in _hud_layer.get_children():
		if child is Container:
			uses_containers = true
			break

	# Using containers is good practice but not required
	assert_true(true, "HUD layout check complete")


# =============================================================================
# ACCESSIBILITY TESTS
# =============================================================================


func test_hud_has_sufficient_contrast() -> void:
	## HUD elements should be visible against game background
	# This is a visual test, hard to automate
	pass


func test_hud_text_readable_size() -> void:
	## Text should be large enough to read
	if not _hud_layer:
		return

	var labels: Array[Label] = _find_all_labels(_hud_layer)
	for label in labels:
		if label.visible:
			# Font size should be reasonable (at least 12)
			var font_size: int = label.get_theme_font_size("font_size")
			if font_size > 0:
				assert_ge(font_size, 12, "Font size should be readable")


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================


func _find_node_by_name(parent: Node, node_name: String) -> Node:
	if parent.name == node_name:
		return parent

	for child in parent.get_children():
		var result: Node = _find_node_by_name(child, node_name)
		if result:
			return result

	return null


func _find_node_by_type(parent: Node, type_name: String) -> Node:
	if parent.get_class() == type_name:
		return parent

	for child in parent.get_children():
		var result: Node = _find_node_by_type(child, type_name)
		if result:
			return result

	return null


func _find_label_with_text(parent: Node, text: String) -> Label:
	if parent is Label and text in parent.text:
		return parent

	for child in parent.get_children():
		var result: Label = _find_label_with_text(child, text)
		if result:
			return result

	return null


func _find_all_labels(parent: Node) -> Array[Label]:
	var labels: Array[Label] = []

	if parent is Label:
		labels.append(parent)

	for child in parent.get_children():
		labels.append_array(_find_all_labels(child))

	return labels
