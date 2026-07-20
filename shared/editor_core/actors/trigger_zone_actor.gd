@tool
class_name TriggerZoneActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum TriggerMode { ON_ENTER, ON_EXIT, WHILE_INSIDE, ON_ENTER_EXIT }  ## Activate when entity enters  ## Activate when entity exits  ## Stay active while entity is inside  ## Activate on enter, deactivate on exit
enum FilterType { PLAYER_ONLY, ENEMIES_ONLY, ANY_ENTITY, SPECIFIC_GROUP }  ## Only player can trigger  ## Only enemies can trigger  ## Any physics body can trigger  ## Only specific group can trigger

@export var trigger_mode: TriggerMode = TriggerMode.ON_ENTER
@export var filter_type: FilterType = FilterType.PLAYER_ONLY
@export var filter_group: String = ""  ## For SPECIFIC_GROUP filter
@export var zone_size: Vector3 = Vector3(2, 2, 2)
@export var show_in_editor: bool = true

var _area: Area3D
var _collision_shape: CollisionShape3D
var _entities_inside: Array[Node] = []


func _init() -> void:
	actor_category = "trigger"
	actor_name = "Trigger Zone"
	actor_description = "Invisible zone that triggers when entities enter"


func _on_actor_ready() -> void:
	_create_zone()


func _create_zone() -> void:
	# Create Area3D for detection
	_area = Area3D.new()
	_area.name = "TriggerArea"
	_area.monitoring = true
	_area.monitorable = false
	add_child(_area)

	# Collision shape
	_collision_shape = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = zone_size
	_collision_shape.shape = box_shape
	_area.add_child(_collision_shape)

	# Connect signals
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	# Editor visualization
	if Engine.is_editor_hint() or show_in_editor:
		_create_visual()


func _create_visual() -> void:
	var visual := CSGBox3D.new()
	visual.name = "EditorVisual"
	visual.size = zone_size
	visual.use_collision = false

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.6, 0.9, 0.2)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material = material

	add_child(visual)

	# Hide in game unless debug
	if not Engine.is_editor_hint():
		visual.visible = show_in_editor


func _on_body_entered(body: Node3D) -> void:
	if not _passes_filter(body):
		return

	_entities_inside.append(body)

	match trigger_mode:
		TriggerMode.ON_ENTER, TriggerMode.ON_ENTER_EXIT:
			trigger(body, {"event": "enter", "entity": body})
		TriggerMode.WHILE_INSIDE:
			if _entities_inside.size() == 1:  # First entity
				trigger(body, {"event": "enter", "entity": body})


func _on_body_exited(body: Node3D) -> void:
	if body not in _entities_inside:
		return

	_entities_inside.erase(body)

	match trigger_mode:
		TriggerMode.ON_EXIT:
			trigger(body, {"event": "exit", "entity": body})
		TriggerMode.ON_ENTER_EXIT:
			deactivate()
		TriggerMode.WHILE_INSIDE:
			if _entities_inside.is_empty():  # Last entity left
				deactivate()


func _passes_filter(body: Node) -> bool:
	match filter_type:
		FilterType.PLAYER_ONLY:
			return body.is_in_group("player") or body.name.to_lower().contains("player")
		FilterType.ENEMIES_ONLY:
			return body.is_in_group("enemy") or body.is_in_group("enemies")
		FilterType.ANY_ENTITY:
			return true
		FilterType.SPECIFIC_GROUP:
			return body.is_in_group(filter_group)
	return false


## Update zone size dynamically


func set_zone_size(new_size: Vector3) -> void:
	zone_size = new_size
	if _collision_shape and _collision_shape.shape is BoxShape3D:
		_collision_shape.shape.size = new_size

	# Update visual
	var visual: Node = get_node_or_null("EditorVisual")
	if visual and visual is CSGBox3D:
		visual.size = new_size


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "trigger_mode",
				"type": TYPE_INT,
				"label": "Trigger Mode",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "On Enter,On Exit,While Inside,Enter/Exit"
			},
			{
				"name": "filter_type",
				"type": TYPE_INT,
				"label": "Filter Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Player Only,Enemies Only,Any Entity,Specific Group"
			},
			{
				"name": "filter_group",
				"type": TYPE_STRING,
				"label": "Filter Group",
				"description": "Group name for Specific Group filter"
			},
			{
				"name": "zone_size",
				"type": TYPE_VECTOR3,
				"label": "Zone Size",
				"description": "Size of the trigger zone"
			},
			{
				"name": "show_in_editor",
				"type": TYPE_BOOL,
				"label": "Show Zone Visual",
				"description": "Show zone boundary in editor"
			}
		]
	)
	return props


func get_gizmo_data() -> Dictionary:
	var data: Dictionary = super.get_gizmo_data()
	data["shape"] = "box"
	data["size"] = zone_size
	data["color"] = Color(0.2, 0.6, 0.9, 0.3)
	return data
