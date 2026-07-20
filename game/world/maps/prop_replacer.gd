extends Node

const PROP_MAPPINGS: Dictionary = {
	"crate": "res://game/world/actors/props/scenes/breakable_crate.tscn",
	"barrel": "res://game/world/actors/props/scenes/breakable_barrel.tscn",
	# TODO(v1.1, @props-team): Create vase scene (4 hours)
	# "vase": "", # TODO: add a canonical vase scene before enabling replacement.
	"chest": "res://game/world/actors/props/scenes/treasure_chest.tscn",
	# TODO(v1.1, @props-team): Create weapon rack scene (6 hours)
	# "weapon_rack": "", # TODO: add a canonical weapon-rack scene before enabling replacement.
}

var _nodes_to_replace: Array[Dictionary] = []


func _ready() -> void:
	# Server authority for spawning
	if not multiplayer.is_server():
		return

	# Don't run during menu startup - only when actually in a game world
	# MENU state
	if GameManager and GameManager.has_method("get_state") and GameManager.get_state() == 0:
		GameManager.get_core_system("logger").info(
			"[PropReplacer] Skipping during menu startup", "World"
		)
		return

	# Check if prop replacement is enabled in config
	var config: Node = GameManager.get_core_system("config")
	if config:
		var prop_replacer_enabled: bool = config.get_value("prop_replacer.enabled", true)
		if not prop_replacer_enabled:
			GameManager.get_core_system("logger").info(
				"[PropReplacer] Prop replacement is disabled via config", "World"
			)
			return

	# Scan map for static meshes to replace
	_scan_for_replaceable_nodes()

	# Perform replacement
	call_deferred("_replace_props")


func _scan_for_replaceable_nodes() -> void:
	var map_root: Node = get_parent()
	if not map_root:
		push_error("[PropReplacer] No parent node found!")
		return

	GameManager.get_core_system("logger").info(
		"[PropReplacer] Scanning map for replaceable props...", "World"
	)
	_scan_node_recursive(map_root)
	GameManager.get_core_system("logger").info(
		"[PropReplacer] Found %d nodes to replace" % _nodes_to_replace.size(), "World"
	)


func _scan_node_recursive(node: Node) -> void:
	# Check if this node matches any replacement pattern
	for pattern: String in PROP_MAPPINGS:
		if node.name.to_lower().begins_with(pattern.to_lower()):
			# Store node info for replacement
			if node is Node3D:
				_nodes_to_replace.append(
					{"node": node, "pattern": pattern, "scene_path": PROP_MAPPINGS[pattern]}
				)
			break

	# Recursively scan children
	for child in node.get_children():
		_scan_node_recursive(child)


func _replace_props() -> void:
	GameManager.get_core_system("logger").info(
		"[PropReplacer] Replacing %d props..." % _nodes_to_replace.size(), "World"
	)

	for entry in _nodes_to_replace:
		var old_node: Node3D = entry["node"]
		var scene_path: String = entry["scene_path"]

		if not ResourceLoader.exists(scene_path):
			push_warning("[PropReplacer] Scene not found: %s" % scene_path)
			continue

		# Load and instantiate new scene
		var scene: PackedScene = load(scene_path)
		var new_node: Node3D = scene.instantiate()

		# Copy transform from old node
		new_node.global_transform = old_node.global_transform
		new_node.name = old_node.name + "_interactive"

		# Add to tree BEFORE removing old node to maintain hierarchy
		var parent: Node = old_node.get_parent()
		if parent:
			parent.add_child(new_node)

			# Remove old static mesh
			old_node.queue_free()

	GameManager.get_core_system("logger").info("[PropReplacer] Prop replacement complete!", "World")
