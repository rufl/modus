extends ModusGutTestBase

const CommandParserScript := preload("res://shared/editor_core/ui/command_parser.gd")
const EditorConsoleScript := preload("res://shared/editor_core/ui/editor_console.gd")
const AssetRegistryScript := preload("res://shared/editor_core/core/asset_registry.gd")
const HotbarScript := preload("res://shared/editor_core/ui/hotbar.gd")

const LEVEL_PATH := "user://levels/editor_console_proof.tscn"

var console: PanelContainer
var level_root: Node3D


func before_each() -> void:
	console = EditorConsoleScript.new()
	console.parser = CommandParserScript.new()
	level_root = Node3D.new()
	add_child_autofree(level_root)
	console.level_root = level_root


func after_each() -> void:
	if is_instance_valid(console):
		console.free()
	if FileAccess.file_exists(LEVEL_PATH):
		DirAccess.remove_absolute(LEVEL_PATH)


func test_clear_rejects_partial_args_without_mutating_level() -> void:
	var existing := Node3D.new()
	level_root.add_child(existing)
	var parsed: CommandParser.ParseResult = console.parser.parse("/clear 0 0 0")

	assert_false(parsed.success)
	assert_eq(console._exec_clear([0, 0, 0]).success, false)
	assert_eq(level_root.get_child_count(), 1)
	assert_true(is_instance_valid(existing))

	assert_true(console.parser.parse("/clear").success)
	assert_true(console.parser.parse("/clear 0 0 0 1 1 1").success)


func test_fill_modes_place_expected_cells_and_honor_block_material() -> void:
	var registry := AssetRegistryScript.new()
	registry._init_asset_categories()
	registry._register_builtin_blocks()
	console.asset_registry = registry

	var result: Dictionary = console._exec_fill(
		["block_stone", 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, "hollow"]
	)
	assert_true(result.success)
	assert_eq(level_root.get_child_count(), 26)
	for child: Node in level_root.get_children():
		assert_eq(child.get_meta("block_id"), "block_stone")
		assert_eq((child as CSGBox3D).size, Vector3.ONE)
		assert_not_null((child as CSGBox3D).material)

	for child: Node in level_root.get_children():
		child.free()
	result = console._exec_fill(
		["block_stone", 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, "outline"]
	)
	assert_true(result.success)
	assert_eq(level_root.get_child_count(), 20)
	registry.free()


func test_load_then_save_preserves_reparented_nodes() -> void:
	DirAccess.make_dir_recursive_absolute("user://levels")
	var source := Node3D.new()
	var loaded_child := Node3D.new()
	loaded_child.name = "PersistedNode"
	source.add_child(loaded_child)
	loaded_child.owner = source
	var packed := PackedScene.new()
	assert_eq(packed.pack(source), OK)
	assert_eq(ResourceSaver.save(packed, LEVEL_PATH), OK)
	source.free()

	var old_child := Node3D.new()
	level_root.add_child(old_child)
	var old_child_name := old_child.name
	var load_result: Dictionary = console._exec_load(["editor_console_proof.tscn"])
	assert_true(load_result.success)
	assert_null(level_root.get_node_or_null(NodePath(old_child_name)))
	var persisted := level_root.get_node_or_null("PersistedNode")
	assert_not_null(persisted)
	assert_eq(persisted.owner, level_root)

	var save_result: Dictionary = console._exec_save(["editor_console_proof.tscn"])
	assert_true(save_result.success)
	var reloaded := (ResourceLoader.load(LEVEL_PATH) as PackedScene).instantiate()
	assert_not_null(reloaded.get_node_or_null("PersistedNode"))
	reloaded.free()


func test_give_mutates_hotbar_or_reports_unsupported() -> void:
	var unsupported: Dictionary = console._exec_give(["block_stone"])
	assert_false(unsupported.success)
	assert_string_contains(unsupported.message, "not supported")

	var registry := AssetRegistryScript.new()
	registry._init_asset_categories()
	registry._register_builtin_blocks()
	var hotbar := HotbarScript.new()
	hotbar._init_slots()
	console.asset_registry = registry
	console.hotbar = hotbar

	var given: Dictionary = console._exec_give(["block_stone", 3])
	assert_true(given.success)
	assert_eq(hotbar.primary_slots[0].get("id"), "block_stone")
	assert_eq(hotbar.primary_slots[0].get("count"), 3)
	hotbar.free()
	registry.free()
