class_name State
extends Node

signal transitioned(state: State, new_state_name: String)

var player: CharacterBody3D = null


func _ready() -> void:
	# Get reference to player (parent's parent should be the player)
	player = get_parent().get_parent()
	assert(
		player is CharacterBody3D,
		"State must be child of StateMachine which must be child of CharacterBody3D"
	)


func enter(_player: CharacterBody3D) -> void:
	## Called when entering this state
	## Override in subclasses to perform state-specific initialization
	pass


func exit() -> void:
	## Called when exiting this state
	## Override in subclasses to perform cleanup
	pass


func update(_delta: float) -> void:
	## Called every frame for state updates
	## Override in subclasses for per-frame logic
	pass


func physics_update(_delta: float) -> void:
	## Called every physics frame for movement calculations
	## Override in subclasses for physics-based logic
	pass


func get_state_name() -> String:
	## Get the display name of this state
	## Override in subclasses to return proper state names
	return "State"


## Helper functions for common state transitions


func transition_to(new_state_name: String) -> void:
	## Transition to another state
	transitioned.emit(self, new_state_name)
