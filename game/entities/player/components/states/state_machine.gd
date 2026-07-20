class_name StateMachine
extends Node

signal state_changed(new_state_name: String)

@export var initial_state: State = null

var current_state: State = null
var states: Dictionary = {}
var current_state_name: String = ""


func _ready() -> void:
	# Collect all child states
	for child in get_children():
		if child is State:
			var state_name: String = child.name.to_lower()
			states[state_name] = child
			child.transitioned.connect(_on_state_transition)

	# Set initial state
	if initial_state:
		enter_state(initial_state)


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _on_state_transition(state: State, new_state_name: String) -> void:
	## Handle state transition requests
	if state != current_state:
		push_warning("State transition requested from inactive state: " + state.name)
		return

	var new_state: State = states.get(new_state_name.to_lower())
	if not new_state:
		push_error("Requested state not found: " + new_state_name)
		return

	# Exit current state
	if current_state:
		current_state.exit()

	# Enter new state
	enter_state(new_state)


func enter_state(new_state: State) -> void:
	## Enter a new state
	current_state = new_state
	current_state_name = current_state.get_state_name()

	# Get reference to player (our parent should be the player)
	var player: Node = get_parent()
	if player is CharacterBody3D:
		current_state.enter(player as CharacterBody3D)
	else:
		push_error("StateMachine parent is not a CharacterBody3D")

	state_changed.emit(current_state_name)


func get_current_state_name() -> String:
	## Get the name of the current state
	return current_state_name if current_state else ""


func is_in_state(state_name: String) -> bool:
	## Check if currently in a specific state
	return current_state_name.to_lower() == state_name.to_lower()


func force_state(state_name: String) -> void:
	## Force transition to a specific state (bypasses normal transition logic)
	var new_state: State = states.get(state_name.to_lower())
	if new_state and new_state != current_state:
		if current_state:
			current_state.exit()
		enter_state(new_state)
