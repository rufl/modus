extends ModusGutTestBase

const LevelPackagerScript = preload("res://shared/editor_core/data/level_packager.gd")
const WorkshopManagerScript = preload("res://shared/editor_core/data/workshop_manager.gd")

const FIXTURE_DIR := "user://workshop_simulation_fixture/"
const WORKSHOP_DIR := "user://workshop/"

var workshop_browse_results: Array[Dictionary] = []
var workshop_browse_failures: Array[Dictionary] = []

func test_local_workshop_upload_download_browse_and_subscription() -> void:
	_remove_directory(FIXTURE_DIR)
	_remove_directory(WORKSHOP_DIR)

	var level := Node3D.new()
	level.name = "WorkshopSimulationLevel"
	add_child_autofree(level)

	var manifest := LevelPackagerScript.LevelManifest.new()
	manifest.id = "workshop_simulation_fixture"
	manifest.name = "Workshop Simulation Fixture"
	manifest.author = "MODUS Test Author"
	manifest.description = "Local Workshop simulation proof"
	var package_result := LevelPackagerScript.package_level(level, FIXTURE_DIR, manifest)
	assert_true(package_result.success, "Fixture package should be created")
	if not package_result.success:
		_remove_directory(FIXTURE_DIR)
		return

	var manager := WorkshopManagerScript.new()
	add_child_autofree(manager)
	await get_tree().process_frame
	assert_false(manager.is_steam_available(), "Focused proof must run in local mode")

	var item_id := manager.upload_level(
		package_result.output_path,
		"Local Fixture",
		"Local-only upload",
		PackedStringArray(["test", "local"])
	)
	assert_eq(item_id, manifest.id)
	assert_true(
		FileAccess.file_exists(manager.WORKSHOP_UPLOADS.path_join(manifest.id + ".mdsl")),
		"Local upload should copy the package into workshop uploads"
	)
	assert_eq(manager.get_item_metadata(manifest.id).get("title"), "Local Fixture")

	manager.download_item(manifest.id)
	assert_eq(
		manager.get_item_local_path(manifest.id),
		manager.WORKSHOP_DOWNLOADS.path_join(manifest.id + ".mdsl")
	)
	assert_true(manager.is_subscribed(manifest.id), "Local download should subscribe the item")

	workshop_browse_results.clear()
	manager.items_loaded.connect(_capture_browse_results)
	manager.browse_items()
	assert_eq(workshop_browse_results.size(), 1)
	if workshop_browse_results.size() == 1:
		assert_eq(workshop_browse_results[0].get("item_id"), manifest.id)

	manager.subscribe(manifest.id)
	await get_tree().process_frame
	assert_true(manager.is_subscribed(manifest.id))
	assert_true(FileAccess.file_exists(manager.get_item_local_path(manifest.id)))
	manager.unsubscribe(manifest.id)
	assert_false(manager.is_subscribed(manifest.id))
	assert_eq(manager.get_item_local_path(manifest.id), "")

	_remove_directory(FIXTURE_DIR)
	_remove_directory(WORKSHOP_DIR)


func test_steam_browse_reports_unsupported_capability() -> void:
	workshop_browse_failures.clear()
	var manager := WorkshopManagerScript.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	manager.steam_available = true
	manager.steam_ugc_available = false
	manager.browse_failed.connect(_capture_browse_failure)
	manager.browse_items("missing-api")

	assert_eq(workshop_browse_failures.size(), 1)
	if workshop_browse_failures.size() == 1:
		assert_eq(workshop_browse_failures[0].get("query"), "missing-api")
		assert_true(
			"GodotSteam" in workshop_browse_failures[0].get("reason", ""),
			"Steam browse failure should identify the unavailable GodotSteam capability"
		)


func test_steam_metadata_conversion_normalizes_ugc_result() -> void:
	var manager := WorkshopManagerScript.new()
	add_child_autofree(manager)
	var item := manager._convert_steam_ugc_metadata(
		{
			"file_id": 42,
			"title": "Remote Fixture",
			"description": "Steam metadata",
			"tags": "Action, Puzzle, ",
			"steam_id_owner": 76561198000000000,
			"time_created": 100,
			"time_updated": 200,
			"score": 0.75,
			"total_unique_subscriptions": 12,
		}
	)

	assert_eq(item.get("item_id"), "42")
	assert_eq(item.get("tags"), ["Action", "Puzzle"])
	assert_eq(item.get("author"), "76561198000000000")
	assert_eq(item.get("created"), 100)
	assert_eq(item.get("updated"), 200)
	assert_eq(item.get("downloads"), 12)
	assert_eq(item.get("rating"), 0.75)


func _remove_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var entry_path := path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory(entry_path)
		else:
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _capture_browse_results(items: Array[Dictionary]) -> void:
	workshop_browse_results = items


func _capture_browse_failure(query: String, reason: String) -> void:
	workshop_browse_failures.append({"query": query, "reason": reason})
