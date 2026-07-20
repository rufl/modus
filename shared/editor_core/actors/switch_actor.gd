@tool
class_name SwitchActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum SwitchType { TOGGLE, MOMENTARY, HOLD }  ## Stays in new state until triggered again  ## Automatically resets after duration  ## Only active while held/stood on

@export var switch_type: SwitchType = SwitchType.TOGGLE
@export var momentary_duration: float = 0.5
@export var require_key: String = ""  ## If set, requires this key item to use

var switch_mesh: Node3D = null

var _momentary_timer: float = 0.0


func _init() -> void:
	actor_category = "activator"
	actor_name = "Switch"
	actor_description = "Interactive switch that activates connected actors"


func _on_actor_ready() -> void:
	_create_visual()


func _create_visual() -> void:
	# Create a simple switch visual
	if Engine.is_editor_hint():
		# Editor preview
		var mesh := CSGBox3D.new()
		mesh.size = Vector3(0.3, 0.3, 0.1)
		mesh.position = Vector3(0, 0, 0.05)

		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.6, 0.2) if is_active else Color(0.6, 0.2, 0.2)
		mesh.material = material

		add_child(mesh)
		switch_mesh = mesh


func _process(delta: float) -> void:
	super._process(delta)

	# Handle momentary auto-reset
	if switch_type == SwitchType.MOMENTARY and is_active:
		_momentary_timer -= delta
		if _momentary_timer <= 0:
			deactivate()


func _on_activated(_data: Dictionary) -> void:
	if switch_type == SwitchType.MOMENTARY:
		_momentary_timer = momentary_duration

	_update_visual()


func _on_deactivated() -> void:
	_update_visual()


func _update_visual() -> void:
	if switch_mesh and switch_mesh is CSGShape3D:
		var csg: CSGShape3D = switch_mesh
		if csg.material is StandardMaterial3D:
			var mat: StandardMaterial3D = csg.material
			mat.albedo_color = Color(0.2, 0.6, 0.2) if is_active else Color(0.6, 0.2, 0.2)


## Called when player interacts


func interact(player: Node = null) -> bool:
	# Check key requirement
	if not require_key.is_empty():
		if player and player.has_method("has_key"):
			if not player.has_key(require_key):
				return false
		else:
			return false

	if switch_type == SwitchType.TOGGLE:
		toggle()
	else:
		trigger(player, {"interacted": true})

	return true


## For hold-type: called when released


func release() -> void:
	if switch_type == SwitchType.HOLD:
		deactivate()


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "switch_type",
				"type": TYPE_INT,
				"label": "Switch Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Toggle,Momentary,Hold"
			},
			{
				"name": "momentary_duration",
				"type": TYPE_FLOAT,
				"label": "Momentary Duration",
				"description": "How long momentary switch stays active"
			},
			{
				"name": "require_key",
				"type": TYPE_STRING,
				"label": "Required Key",
				"description": "Key item needed to use this switch"
			}
		]
	)
	return props
