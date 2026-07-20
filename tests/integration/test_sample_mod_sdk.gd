extends ModusGutTestBase

const SAMPLE_MOD_DIR := "res://mods/modus_sdk_sample"
const SAMPLE_MANIFEST := SAMPLE_MOD_DIR + "/mod.json"
const SAMPLE_SCRIPT := SAMPLE_MOD_DIR + "/scripts/sample_mod.gd"
const GameManager = preload("res://game/scripts/core/game_manager.gd")


func test_sample_mod_manifest_is_complete() -> void:
	assert_true(FileAccess.file_exists(SAMPLE_MANIFEST), "Sample mod manifest should exist")
	var manifest_file := FileAccess.open(SAMPLE_MANIFEST, FileAccess.READ)
	assert_not_null(manifest_file, "Sample mod manifest should be readable")
	if not manifest_file:
		return
	var manifest: Variant = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	assert_true(manifest is Dictionary, "Sample mod manifest should parse as an object")
	if not manifest is Dictionary:
		return
	assert_eq(manifest.get("id"), "modus_sdk_sample")
	assert_true(manifest.get("config_overrides", {}).has("weapons"))
	assert_true(manifest.get("config_overrides", {}).has("enemies"))
	assert_true(manifest.get("config_overrides", {}).has("loot"))
	assert_true("scripts/sample_mod.gd" in manifest.get("scripts", []))


func test_sample_mod_script_exchanges_event_and_hook() -> void:
	var script: Script = load(SAMPLE_SCRIPT)
	assert_not_null(script, "Sample mod script should load")
	if not script:
		return
	var game_manager: Node = GameManager.new()
	add_child_autofree(game_manager)
	game_manager.initialize()
	var sample_mod: Node = script.new()
	assert_not_null(sample_mod, "Sample mod script should instantiate")
	add_child_autofree(sample_mod)
	await get_tree().process_frame

	sample_mod.install(game_manager)
	game_manager.emit_event("modus_sample_ping", {"source": "integration"})
	sample_mod.on_enemy_spawn(null, "grunt")

	var status: Dictionary = sample_mod.get_sample_status()
	assert_true(status.get("event_received", false), "Sample mod should receive its event")
	assert_eq(status.get("hook_calls", []), ["enemy_spawn:grunt"])
