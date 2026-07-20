class_name ButtonStand
extends Node3D

signal pressed(interactor: Node)

@onready var interactable: Interactable = $Interactable
@onready var button_mesh: Node3D = $ButtonMesh


func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)


func _on_interacted(_interactor: Node) -> void:
	# In a real scenario, we might want to validate who pressed it, but for effects:
	_trigger_press.rpc()


@rpc("any_peer", "call_local", "reliable")
func _trigger_press() -> void:
	pressed.emit(null)  # Interactor is lost over RPC unless sent as ID
	_animate_press()


func _animate_press() -> void:
	if not button_mesh:
		return

	var start_y: float = button_mesh.position.y
	var tween: Tween = create_tween()
	tween.tween_property(button_mesh, "position:y", start_y - 0.05, 0.1)
	tween.tween_property(button_mesh, "position:y", start_y, 0.1)
