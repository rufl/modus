extends ModusGutTestBase

# Test MODUS Framework Level Editor
# Converted from legacy Dictionary format to GUT assertions

const ActorRegistryScript := preload("res://shared/editor_core/actors/actor_registry.gd")
const AssetRegistryScript := preload("res://shared/editor_core/core/asset_registry.gd")


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_editor_core_directory_exists() -> void:
	var path: String = "res://shared/editor_core/"
	assert_true(
		DirAccess.dir_exists_absolute(path), "Editor core directory should exist at: %s" % path
	)


func test_editor_actors_directory_exists() -> void:
	var path: String = "res://shared/editor_core/actors/"
	assert_true(
		DirAccess.dir_exists_absolute(path), "Editor actors directory should exist at: %s" % path
	)

	var registry: Node = ActorRegistryScript.new()
	registry._register_builtin_actors()
	for actor_id: String in registry.get_all_actor_ids():
		var actor_info: Dictionary = registry.get_actor_info(actor_id)
		var script_path: String = actor_info.get("script", "")
		assert_true(
			ResourceLoader.exists(script_path),
			"Built-in actor '%s' script should resolve at: %s" % [actor_id, script_path]
		)
		var actor_instance: Node = registry.create_actor(actor_id)
		assert_not_null(actor_instance, "Built-in actor '%s' should instantiate" % actor_id)
		if actor_instance:
			actor_instance.free()
	registry.free()


func test_editor_tools_directory_exists() -> void:
	var path: String = "res://shared/editor_core/tools/"
	assert_true(
		DirAccess.dir_exists_absolute(path), "Editor tools directory should exist at: %s" % path
	)


func test_editor_ui_directory_exists() -> void:
	var path: String = "res://shared/editor_core/ui/"
	assert_true(
		DirAccess.dir_exists_absolute(path), "Editor UI directory should exist at: %s" % path
	)


func test_editor_gizmos_directory_exists() -> void:
	var path: String = "res://shared/editor_core/gizmos/"
	assert_true(
		DirAccess.dir_exists_absolute(path), "Editor gizmos directory should exist at: %s" % path
	)


# =============================================================================
# EDITOR DATA FORMATS
# =============================================================================


func test_editor_data_directory_exists() -> void:
	var path: String = "res://shared/editor_core/data/"
	assert_true(
		DirAccess.dir_exists_absolute(path), "Editor data directory should exist at: %s" % path
	)

	var registry: Node = AssetRegistryScript.new()
	registry._init_asset_categories()
	registry._scan_assets()
	for asset_id: String in ["door", "trigger_zone", "moving_platform"]:
		var asset: Dictionary = registry.get_asset_by_id(asset_id)
		assert_false(asset.is_empty(), "Built-in interactable '%s' should be registered" % asset_id)
		assert_true(
			ResourceLoader.exists(asset.get("script_path", "")),
			"Built-in interactable '%s' script should resolve" % asset_id
		)

	for scene_asset_id: String in [
		"glass_window",
		"breakable_crate",
		"breakable_barrel",
		"elevator",
		"crusher",
		"rope",
		"lever"
	]:
		var scene_asset: Dictionary = registry.get_asset_by_id(scene_asset_id)
		assert_false(
			scene_asset.is_empty(),
			"Canonical scene asset '%s' should be discovered" % scene_asset_id
		)
		assert_true(
			ResourceLoader.exists(scene_asset.get("scene_path", "")),
			"Canonical scene asset '%s' should resolve" % scene_asset_id
		)
	registry.free()


# =============================================================================
# EMBEDDED EDITOR
# =============================================================================


func test_embedded_level_editor_exists() -> void:
	var path: String = "res://game/editor/embedded_level_editor.gd"
	assert_true(
		FileAccess.file_exists(path), "Embedded level editor script should exist at: %s" % path
	)


# =============================================================================
# SHOWCASE LEVELS
# =============================================================================


func test_showcase_level_exists() -> void:
	var path: String = "res://game/world/maps/comprehensive_showcase.tscn"
	assert_true(
		ResourceLoader.exists(path), "Comprehensive showcase level should exist at: %s" % path
	)


func test_dm_arena_exists() -> void:
	var path: String = "res://game/world/maps/dm_arena_01.tscn"
	assert_true(ResourceLoader.exists(path), "DM Arena 01 level should exist at: %s" % path)


func test_movement_lab_exists() -> void:
	var path: String = "res://game/levels/movement_lab.tscn"
	assert_true(ResourceLoader.exists(path), "Movement lab level should exist at: %s" % path)


func test_hazards_arena_exists() -> void:
	var path: String = "res://game/levels/hazards_arena.tscn"
	assert_true(ResourceLoader.exists(path), "Hazards arena level should exist at: %s" % path)


func test_projectile_range_exists() -> void:
	var path: String = "res://game/levels/projectile_range.tscn"
	assert_true(ResourceLoader.exists(path), "Projectile range level should exist at: %s" % path)


func test_traversal_course_exists() -> void:
	var path: String = "res://game/levels/traversal_course.tscn"
	assert_true(ResourceLoader.exists(path), "Traversal course level should exist at: %s" % path)
