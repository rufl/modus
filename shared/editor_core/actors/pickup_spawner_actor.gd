@tool
class_name PickupSpawnerActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum PickupCategory { HEALTH, ARMOR, AMMO, WEAPON, POWERUP }

@export var pickup_category: PickupCategory = PickupCategory.HEALTH
@export var weapon_id: String = ""  # For weapon pickups
@export var item_id: String = "health_potion"  # For other pickups
@export var respawn_time: float = 30.0
@export var auto_spawn: bool = true

var preview_mesh: Node3D = null
var spawn_area: Area3D = null
var hologram_material: StandardMaterial3D = null

var _current_pickup: Node3D = null
var _respawn_timer: float = 0.0
var _is_spawned: bool = false


func _init() -> void:
	actor_category = "activator"
	actor_name = "Pickup Spawner"
	actor_description = "Spawns items and weapons"


func _on_actor_ready() -> void:
	_create_visual()

	if auto_spawn:
		call_deferred("_spawn_pickup")


func _create_visual() -> void:
	# Holographic preview
	preview_mesh = CSGBox3D.new()
	preview_mesh.name = "PreviewMesh"
	preview_mesh.size = Vector3(0.5, 0.5, 0.5)
	preview_mesh.position.y = 1.0

	hologram_material = StandardMaterial3D.new()
	hologram_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hologram_material.albedo_color = _get_category_color()
	hologram_material.emission_enabled = true
	hologram_material.emission = _get_category_color()
	hologram_material.emission_energy_multiplier = 1.5
	preview_mesh.material = hologram_material
	add_child(preview_mesh)

	# Spawn platform
	var platform := CSGCylinder3D.new()
	platform.name = "SpawnPlatform"
	platform.radius = 0.6
	platform.height = 0.1
	platform.position.y = 0.05

	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.3, 0.3, 0.3)
	platform_mat.metallic = 0.8
	platform.material = platform_mat
	add_child(platform)


func _get_category_color() -> Color:
	match pickup_category:
		PickupCategory.HEALTH:
			return Color(0.2, 1.0, 0.3, 0.7)  # Green
		PickupCategory.ARMOR:
			return Color(0.3, 0.5, 1.0, 0.7)  # Blue
		PickupCategory.AMMO:
			return Color(1.0, 0.8, 0.2, 0.7)  # Yellow
		PickupCategory.WEAPON:
			return Color(1.0, 0.4, 0.2, 0.7)  # Orange
		PickupCategory.POWERUP:
			return Color(0.8, 0.2, 1.0, 0.7)  # Purple
		_:
			return Color(0.5, 0.5, 0.5, 0.7)


func _process(delta: float) -> void:
	super._process(delta)

	# Rotate preview
	if preview_mesh:
		preview_mesh.rotation.y += delta * 2.0

	# Handle respawn
	if not _is_spawned and _respawn_timer > 0:
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			_spawn_pickup()


func _spawn_pickup() -> void:
	if _is_spawned:
		return

	var pickup_scene: PackedScene = _get_pickup_scene()
	if not pickup_scene:
		push_warning("[PickupSpawnerActor] No scene for category %d" % pickup_category)
		return

	_current_pickup = pickup_scene.instantiate()
	_current_pickup.position = global_position + Vector3(0, 1, 0)

	# Configure weapon pickup
	if pickup_category == PickupCategory.WEAPON and "weapon_id" in _current_pickup:
		_current_pickup.weapon_id = weapon_id

	# Add to scene with unique name for multiplayer compatibility
	get_parent().add_child(_current_pickup, true)

	# Connect pickup signal if available
	if _current_pickup.has_signal("picked_up"):
		_current_pickup.picked_up.connect(_on_pickup_collected)

	_is_spawned = true

	# Hide preview
	if preview_mesh:
		preview_mesh.visible = false


func _on_pickup_collected(_collector: Node = null) -> void:
	_is_spawned = false
	_current_pickup = null
	_respawn_timer = respawn_time

	# Show preview again
	if preview_mesh:
		preview_mesh.visible = true


func _get_pickup_scene() -> PackedScene:
	var scene_path: String = ""

	match pickup_category:
		PickupCategory.HEALTH:
			scene_path = "res://game/scenes/items/pickups/health_pickup.tscn"
		PickupCategory.ARMOR:
			scene_path = "res://game/scenes/items/pickups/armor_pickup.tscn"
		PickupCategory.AMMO:
			scene_path = "res://game/scenes/items/pickups/ammo_pickup.tscn"
		PickupCategory.WEAPON:
			# Map weapon_id to scene
			match weapon_id:
				"shotgun":
					scene_path = "res://game/scenes/items/pickups/shotgun_pickup.tscn"
				"rocket_launcher":
					scene_path = "res://game/scenes/items/pickups/rocket_launcher_pickup.tscn"
				_:
					push_warning("[PickupSpawnerActor] Unknown weapon_id: %s" % weapon_id)
		PickupCategory.POWERUP:
			scene_path = "res://game/scenes/items/pickups/powerup_pickup.tscn"

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null

	return load(scene_path)


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "pickup_category",
				"type": TYPE_INT,
				"label": "Pickup Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Health,Armor,Ammo,Weapon,Powerup"
			},
			{
				"name": "weapon_id",
				"type": TYPE_STRING,
				"label": "Weapon ID",
				"description": "For weapon pickups (shotgun, rocket_launcher, etc.)"
			},
			{
				"name": "respawn_time",
				"type": TYPE_FLOAT,
				"label": "Respawn Time",
				"description": "Seconds before item respawns"
			},
			{
				"name": "auto_spawn",
				"type": TYPE_BOOL,
				"label": "Auto Spawn",
				"description": "Spawn item on level start"
			}
		]
	)
	return props
