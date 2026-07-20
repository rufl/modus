extends Area3D

@export var controller_path: NodePath
@export var state_name: String


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var controller: Node = get_node_or_null(controller_path)
		if controller:
			controller.request_state_change(state_name)
		else:
			push_error("Controller not found at path: " + str(controller_path))
