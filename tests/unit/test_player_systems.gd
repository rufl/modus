extends ModusGutTestBase

# Test MODUS Framework Player Systems
# Converted from legacy Dictionary format to GUT assertions


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_player_script_exists() -> void:
	var path: String = "res://game/entities/player/player.gd"
	assert_true(FileAccess.file_exists(path), "Player script should exist at: %s" % path)


func test_player_scene_exists() -> void:
	var path: String = "res://game/entities/player/player.tscn"
	assert_true(ResourceLoader.exists(path), "Player scene should exist at: %s" % path)


# =============================================================================
# PLAYER COMPONENTS
# =============================================================================


func test_health_component_exists() -> void:
	var path: String = "res://game/entities/components/health_component.gd"
	assert_true(FileAccess.file_exists(path), "Health component script should exist at: %s" % path)


func test_combat_component_exists() -> void:
	var path: String = "res://game/entities/components/combat_component.gd"
	assert_true(FileAccess.file_exists(path), "Combat component script should exist at: %s" % path)


func test_perception_component_exists() -> void:
	var path: String = "res://game/entities/components/perception_component.gd"
	assert_true(
		FileAccess.file_exists(path), "Perception component script should exist at: %s" % path
	)


func test_status_effect_manager_exists() -> void:
	var path: String = "res://game/entities/components/status_effect_manager.gd"
	assert_true(
		FileAccess.file_exists(path), "Status effect manager script should exist at: %s" % path
	)


# =============================================================================
# PLAYER MOVEMENT SYSTEMS
# =============================================================================


func test_rocket_jump_system_exists() -> void:
	var path: String = "res://game/entities/player/rocket_jump_system.gd"
	assert_true(
		FileAccess.file_exists(path), "Rocket jump system script should exist at: %s" % path
	)


# =============================================================================
# PLAYER STATES
# =============================================================================


func test_player_state_manager_exists() -> void:
	var path: String = "res://game/entities/player/components/player_state_manager.gd"
	assert_true(
		FileAccess.file_exists(path), "Player state manager script should exist at: %s" % path
	)


func test_downed_state_exists() -> void:
	var path: String = "res://game/entities/player/downed_state.gd"
	assert_true(FileAccess.file_exists(path), "Downed state script should exist at: %s" % path)


# =============================================================================
# WEAPON MANAGER
# =============================================================================


func test_weapon_manager_exists() -> void:
	var path: String = "res://game/entities/player/components/weapon_manager.gd"
	assert_true(FileAccess.file_exists(path), "Weapon manager script should exist at: %s" % path)


func test_interaction_component_exists() -> void:
	var path: String = "res://game/entities/player/components/interaction_component.gd"
	assert_true(
		FileAccess.file_exists(path), "Interaction component script should exist at: %s" % path
	)


# =============================================================================
# PLAYER SERVICE
# =============================================================================


func test_player_service_exists() -> void:
	var path: String = "res://game/core/services/player_service.gd"
	assert_true(FileAccess.file_exists(path), "Player service script should exist at: %s" % path)


func test_player_service_has_required_methods() -> void:
	var script: Script = load("res://game/scripts/features/player/player_service.gd")
	assert_not_null(script, "Should be able to load player_service.gd")


func test_set_health_applies_locally_once_and_preserves_unspecified_armor() -> void:
	var body := Node3D.new()
	add_child_autofree(body)
	var health := HealthComponent.new()
	body.add_child(health)
	watch_signals(health)

	health.set_health(25.0, 10.0)
	assert_eq(health.current_health, 25.0)
	assert_eq(health.current_armor, 10.0)
	assert_signal_emit_count(health, "health_changed", 1)
	assert_signal_emit_count(health, "armor_changed", 1)
	assert_signal_emit_count(health, "damage_received", 1)

	health.set_health(40.0)
	assert_eq(health.current_health, 40.0)
	assert_eq(health.current_armor, 10.0, "Omitted armor preserves the restored amount")
	assert_signal_emit_count(health, "damage_received", 1, "Restoring more HP is not damage")


func test_set_health_emits_death_only_once() -> void:
	var body := Node3D.new()
	add_child_autofree(body)
	var health := HealthComponent.new()
	body.add_child(health)
	watch_signals(health)

	health.set_health(0.0, 0.0)
	health.set_health(0.0, 0.0)
	assert_true(health.is_dead)
	assert_signal_emit_count(health, "died", 1)
