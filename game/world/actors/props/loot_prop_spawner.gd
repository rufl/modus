@tool
extends Node3D
class_name LootPropSpawner

enum PropType { CRATE, BARREL, VASE, CHEST, CORPSE_PILE, HIDDEN_STASH, WEAPON_RACK, RANDOM }

const PROP_SCENES: Dictionary = {
	PropType.CRATE: "res://game/world/actors/props/scenes/breakable_crate.tscn",
	PropType.BARREL: "res://game/world/actors/props/scenes/breakable_barrel.tscn",
	PropType.CHEST: "res://game/world/actors/props/scenes/treasure_chest.tscn",
}

@export_group("Spawn Settings")
@export var prop_type: PropType = PropType.CRATE
@export var spawn_on_ready: bool = true
@export var spawn_chance: float = 1.0  # 0-1
@export var random_rotation: bool = true
@export var random_offset: float = 0.0  # Random position offset
@export_group("Prop Configuration")
@export var loot_table_override: String = ""  # Override prop's default loot table
@export var health_multiplier: float = 1.0
@export var weapon_type: String = "pistol"  # For weapon racks
@export_group("Debug")
@export var show_spawn_point: bool = true
@export var spawn_point_color: Color = Color(0.0, 1.0, 0.0, 0.5)

var spawned_prop: Node3D = null
var _startup_pending: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("loot_prop_spawners")

	if spawn_on_ready and _can_manage_props():
		_startup_pending = true
		_spawn_on_ready.call_deferred()


func _exit_tree() -> void:
	_startup_pending = false
	# Props are siblings, so removing their spawner must also release its owned prop.
	# Queue deletion rather than modifying a parent that may itself be exiting.
	if _can_manage_props() and is_instance_valid(spawned_prop):
		spawned_prop.queue_free()
	spawned_prop = null


func _can_manage_props() -> bool:
	if Engine.is_editor_hint() or not is_inside_tree():
		return false
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _spawn_on_ready() -> void:
	if _startup_pending:
		_startup_pending = false
		spawn_prop()


func spawn_prop() -> Node3D:
	## Spawn a prop at this location (server-only)
	if not _can_manage_props() or is_queued_for_deletion() or get_parent().is_queued_for_deletion():
		return null
	_startup_pending = false
	if is_instance_valid(spawned_prop):
		if not spawned_prop.is_queued_for_deletion():
			return spawned_prop
		despawn_prop()

	# Roll spawn chance
	if randf() > spawn_chance:
		return null

	# Get scene path
	var scene_path: String = _get_scene_path()
	if scene_path.is_empty():
		push_warning(
			(
				"[LootPropSpawner] No scene is registered for prop type: %s"
				% PropType.keys()[prop_type]
			)
		)
		return null
	if not ResourceLoader.exists(scene_path):
		push_warning("[LootPropSpawner] Scene not found: %s" % scene_path)
		return null

	# Load and instantiate
	var scene: PackedScene = load(scene_path)
	var prop: Node3D = scene.instantiate()

	# Set the complete local transform before entering the tree, so readiness and
	# multiplayer observers see the configured world transform immediately.
	var spawn_transform: Transform3D = global_transform
	if random_offset > 0:
		spawn_transform.origin += Vector3(
			randf_range(-random_offset, random_offset),
			0,
			randf_range(-random_offset, random_offset)
		)

	if random_rotation:
		spawn_transform.basis = Basis(Vector3.UP, randf() * TAU) * spawn_transform.basis
	var parent_3d: Node3D = get_parent_node_3d()
	prop.transform = (
		parent_3d.global_transform.affine_inverse() * spawn_transform
		if parent_3d
		else spawn_transform
	)
	_configure_prop(prop)

	spawned_prop = prop
	prop.tree_exiting.connect(_on_spawned_prop_tree_exiting.bind(prop), CONNECT_ONE_SHOT)
	visible = false
	get_parent().add_child(prop)

	return spawned_prop


func _get_scene_path() -> String:
	if prop_type == PropType.RANDOM:
		# Pick only from breakable types with canonical scenes.
		var breakable_types: Array = [PropType.CRATE, PropType.BARREL]
		var random_type: PropType = breakable_types.pick_random()
		return PROP_SCENES.get(random_type, "")

	return PROP_SCENES.get(prop_type, "")


func _configure_prop(prop: Node3D) -> void:
	## Apply spawner configuration to prop
	# Override loot table
	if loot_table_override != "":
		if "loot_table_id" in prop:
			prop.loot_table_id = loot_table_override

	# Apply health multiplier
	if health_multiplier != 1.0:
		if "max_health" in prop:
			prop.max_health *= health_multiplier
		if "sync_health" in prop:
			prop.sync_health = prop.max_health

	# Weapon rack specific
	if prop_type == PropType.WEAPON_RACK:
		if "weapon_type" in prop:
			prop.weapon_type = weapon_type


func despawn_prop() -> void:
	## Remove spawned prop (server-only).
	if not _can_manage_props():
		return
	_startup_pending = false
	if is_instance_valid(spawned_prop):
		var prop: Node3D = spawned_prop
		spawned_prop = null
		# Detach now so a synchronous respawn never leaves two active props.
		if prop.get_parent():
			prop.get_parent().remove_child(prop)
		prop.queue_free()
	visible = true


func respawn_prop() -> void:
	## Respawn the prop (server-only).
	if not _can_manage_props():
		return
	despawn_prop()
	spawn_prop()


func _on_spawned_prop_tree_exiting(prop: Node3D) -> void:
	if spawned_prop == prop:
		spawned_prop = null
		visible = true


# =============================================================================
# EDITOR VISUALIZATION
# =============================================================================


func _draw() -> void:
	# Editor visualization handled in _process for 3D
	pass


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	if not show_spawn_point:
		return

	# Editor would use a debug draw or gizmo here
	# This is just a placeholder for editor visibility


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	var scene_path: String = _get_scene_path()
	if scene_path.is_empty():
		warnings.append("No prop scene is registered for type: %s" % PropType.keys()[prop_type])
	elif not ResourceLoader.exists(scene_path):
		warnings.append("Prop scene not found: %s" % scene_path)

	return warnings
