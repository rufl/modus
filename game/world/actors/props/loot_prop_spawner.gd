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


func _ready() -> void:
	add_to_group("loot_prop_spawners")

	if spawn_on_ready:
		# Only server spawns props
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			call_deferred("spawn_prop")


func spawn_prop() -> Node3D:
	## Spawn a prop at this location (server-only)
	# Roll spawn chance
	if randf() > spawn_chance:
		return null

	# Get scene path
	var scene_path: String = _get_scene_path()
	if scene_path.is_empty():
		push_warning(
			"[LootPropSpawner] No scene is registered for prop type: %s"
			% PropType.keys()[prop_type]
		)
		return null
	if not ResourceLoader.exists(scene_path):
		push_warning("[LootPropSpawner] Scene not found: %s" % scene_path)
		return null

	# Load and instantiate
	var scene: PackedScene = load(scene_path)
	spawned_prop = scene.instantiate()

	# Calculate position
	var spawn_pos: Vector3 = global_position
	if random_offset > 0:
		spawn_pos += Vector3(
			randf_range(-random_offset, random_offset),
			0,
			randf_range(-random_offset, random_offset)
		)

	# Configure prop
	_configure_prop(spawned_prop)

	# Add to scene
	get_parent().add_child(spawned_prop)
	spawned_prop.global_position = spawn_pos

	# Apply rotation
	if random_rotation:
		spawned_prop.rotate_y(randf() * TAU)
	else:
		spawned_prop.global_rotation = global_rotation

	# Hide spawner visual
	visible = false

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
	## Remove spawned prop
	if spawned_prop and is_instance_valid(spawned_prop):
		spawned_prop.queue_free()
		spawned_prop = null
	visible = true


func respawn_prop() -> void:
	## Respawn the prop
	despawn_prop()
	spawn_prop()


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
		warnings.append(
			"No prop scene is registered for type: %s" % PropType.keys()[prop_type]
		)
	elif not ResourceLoader.exists(scene_path):
		warnings.append("Prop scene not found: %s" % scene_path)

	return warnings
