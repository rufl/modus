extends ModusGutTestBase

signal ping


class ReloadLoader:
	extends "res://game/scripts/features/modding/mod_loader.gd"

	var discovery_path: String

	func _ready() -> void:
		pass

	func _discover_all_mods() -> void:
		_all_discovered_mods.clear()
		_scan_for_discovery(discovery_path)

	func _load_mod_settings() -> void:
		pass

	func _save_mod_settings() -> void:
		pass


var hits: int = 0
var cleanups: int = 0
var _loader: ReloadLoader
var _root: String
var _files: Array[String] = []
var _directories: Array[String] = []
var _data: Node
var _config: Node
var _assets: Node
const RECORD: String = "__mod_reload_regression"


func before_each() -> void:
	await modus_setup()
	hits = 0
	cleanups = 0
	_root = "user://mod_reload_%d" % get_instance_id()
	DirAccess.make_dir_recursive_absolute(_root)
	_directories.append(_root)
	_data = GameManager.get_core_system("data")
	_config = GameManager.get_core_system("config")
	_assets = GameManager.get_core_system("assets")
	_loader = ReloadLoader.new()
	_loader.discovery_path = _root
	_loader.set_meta("probe", self)
	add_child(_loader)


func after_each() -> void:
	if is_instance_valid(_loader):
		_loader.free()
	_data.weapons.erase(RECORD)
	_data.weapons.erase(RECORD + "_new")
	_data.enemies.erase(RECORD)
	_data.loot_tables.erase(RECORD)
	for config_data: Dictionary in _config._config_cache.values():
		config_data.erase(RECORD)
	for path: String in _files:
		DirAccess.remove_absolute(path)
	for index: int in range(_directories.size() - 1, -1, -1):
		DirAccess.remove_absolute(_directories[index])
	_files.clear()
	_directories.clear()
	modus_teardown()


func _write_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	_files.append(path)


func _mod(id: String, priority: int, overrides: Dictionary = {}) -> String:
	var path := _root.path_join(id)
	DirAccess.make_dir_recursive_absolute(path)
	_directories.append(path)
	_write_file(
		path.path_join("mod.json"),
		JSON.stringify(
			{
				"id": id,
				"name": id,
				"version": "1",
				"priority": priority,
				"config_overrides": overrides
			}
		)
	)
	return path


func _enable_all() -> void:
	_loader._discover_all_mods()
	for mod: Dictionary in _loader.get_installed_mods():
		_loader.set_mod_enabled(mod.id, true)
	_loader.load_all_mods()


func test_reload_frees_previous_script_and_handler_before_loading_replacement() -> void:
	var path := _mod("script", 10)
	_write_file(
		path.path_join("handler.gd"),
		(
			"extends ModScript\nvar probe: Node\n"
			+ 'func _mod_init() -> void:\n\tprobe = get_parent().get_meta("probe")\n'
			+ "\tprobe.ping.connect(_on_ping)\n"
			+ "func _on_ping() -> void:\n\tprobe.hits += 1\n"
			+ "func _mod_cleanup() -> void:\n\tprobe.cleanups += 1\n"
		)
	)
	var manifest := FileAccess.open(path.path_join("mod.json"), FileAccess.WRITE)
	manifest.store_string(
		JSON.stringify(
			{"id": "script", "name": "script", "version": "1", "scripts": ["handler.gd"]}
		)
	)
	manifest.close()
	_enable_all()
	var unrelated := Node.new()
	_loader.add_child(unrelated)
	ping.emit()
	assert_eq(hits, 1)
	for iteration: int in range(3):
		_loader.reload_mods()
		ping.emit()
		assert_eq(hits, iteration + 2, "Exactly one live callback after each reload")
		assert_eq(cleanups, iteration + 1, "Cleanup hook runs once per removed script")
	_loader.set_mod_enabled("script", false)
	_loader.reload_mods()
	ping.emit()
	assert_eq(hits, 4, "Disabled script no longer handles events")
	assert_eq(cleanups, 4)
	assert_true(is_instance_valid(unrelated), "Unowned children survive reload")
	assert_eq(_loader.get_child_count(), 1)


func test_disabling_and_deleting_stacked_mods_restores_only_owned_data_and_config() -> void:
	_data.weapons[RECORD] = {"damage": 5, "runtime": 1}
	_data.enemies[RECORD] = {"health": 40}
	_data.loot_tables[RECORD] = {"drop_chance": 0.1}
	_config.set_value(RECORD + ".enabled", true)
	_config.set_value(RECORD + ".runtime", 1)
	var low := _mod(
		"low",
		10,
		{
			"systems": {RECORD: {"enabled": false, "added": true}},
			"weapons": {RECORD: {"damage": 10}, RECORD + "_new": {"damage": 1}},
			"enemies": {RECORD: {"health": 80}},
			"loot_tables": {RECORD: {"drop_chance": 0.5}}
		}
	)
	_mod(
		"high",
		20,
		{
			"weapons": {RECORD: {"damage": 20}},
			"systems": {RECORD: {"enabled": true}},
			"loot_tables": {RECORD: {"drop_chance": 0.9}}
		}
	)
	_enable_all()
	assert_eq(_data.get_weapon_data(RECORD).damage, 20)
	assert_eq(_config.get_value(RECORD + ".enabled"), true)
	_loader.reload_mods()
	assert_eq(_data.get_weapon_data(RECORD).damage, 20)
	_data.weapons[RECORD].runtime = 99
	_config.set_value(RECORD + ".runtime", 99)
	_loader.set_mod_enabled("high", false)
	_loader.reload_mods()
	assert_eq(_data.get_weapon_data(RECORD).damage, 10)
	assert_eq(_config.get_value(RECORD + ".enabled"), false)
	assert_eq(_data.get_loot_table(RECORD).drop_chance, 0.5)
	DirAccess.remove_absolute(low.path_join("mod.json"))
	_loader.reload_mods()
	assert_eq(_data.get_weapon_data(RECORD), {"damage": 5, "runtime": 99})
	assert_eq(_data.get_enemy_data(RECORD), {"health": 40})
	assert_eq(_data.get_weapon_data(RECORD + "_new"), {})
	assert_eq(_data.get_loot_table(RECORD), {"drop_chance": 0.1})
	assert_eq(_config.get_value(RECORD), {"enabled": true, "runtime": 99})
	assert_false(_loader.is_mod_loaded("low"), "Deleted manifests disappear on reload")


func _resource(path: String, label: String) -> Resource:
	var resource := Resource.new()
	resource.resource_name = label
	ResourceSaver.save(resource, path)
	_files.append(path)
	return load(path)


func test_resource_reload_restores_engine_cache_and_preexisting_asset_mapping() -> void:
	var original_path := _root.path_join("original.tres")
	var baseline := _resource(original_path, "baseline")
	var previous_path := _root.path_join("previous.tres")
	var previous := _resource(previous_path, "previous")
	_assets.register_overrides({original_path: previous_path})
	var low := _mod("low", 10)
	var high := _mod("high", 20)
	_resource(low.path_join("replacement.tres"), "low")
	_resource(high.path_join("replacement.tres"), "high")
	for path: String in [low, high]:
		var id := path.get_file()
		var manifest := FileAccess.open(path.path_join("mod.json"), FileAccess.WRITE)
		manifest.store_string(
			JSON.stringify(
				{
					"id": id,
					"name": id,
					"version": "1",
					"priority": 10 if id == "low" else 20,
					"assets": {"materials": {original_path: "replacement.tres"}}
				}
			)
		)
		manifest.close()
	_enable_all()
	assert_eq(load(original_path).resource_name, "high")
	assert_eq(_assets.load_resource(original_path).resource_name, "high")
	_loader.reload_mods()
	assert_eq(load(original_path).resource_name, "high")
	_loader.set_mod_enabled("high", false)
	_loader.reload_mods()
	assert_eq(load(original_path).resource_name, "low")
	_loader.set_mod_enabled("low", false)
	_loader.reload_mods()
	assert_same(load(original_path), baseline, "Original cached resource is restored")
	assert_eq(_assets.get_asset_path(original_path), previous_path)
	assert_same(_assets.load_resource(original_path), previous)
	_assets.clear_override(original_path)


func test_unload_preserves_external_resource_override_applied_after_mod() -> void:
	var path := _root.path_join("original.tres")
	var baseline := _resource(path, "baseline")
	var mod_path := _root.path_join("mod.tres")
	_resource(mod_path, "mod")
	_loader._override_resource(path, mod_path)
	_loader.unload_mods()
	assert_same(load(path), baseline)
	assert_eq(_assets.get_asset_path(path), path, "Mod-only AssetManager mapping is removed")
	_loader._override_resource(path, mod_path)
	var external_path := _root.path_join("external.tres")
	var external := _resource(external_path, "external")
	external.take_over_path(path)
	_assets.register_overrides({path: external_path})
	_loader.unload_mods()
	assert_same(load(path), external)
	assert_eq(_assets.get_asset_path(path), external_path)
	baseline.take_over_path(path)
	_assets.clear_override(path)
