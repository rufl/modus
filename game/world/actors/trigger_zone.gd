@tool
class_name TriggerZone
extends Area3D

signal triggered(body: Node)
signal trigger_exited(body: Node)

@export var active: bool = true
@export var one_shot: bool = false
@export var trigger_once_per_body: bool = false
# Default to Player (Layer 2)
@export_flags("Player", "Enemy", "PhysicsProp") var filter_flags: int = 1

var _triggered_bodies: Array[Node] = []
var _has_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not active:
		return

	if one_shot and _has_triggered:
		return

	if not _passes_filter(body):
		return

	if trigger_once_per_body and body in _triggered_bodies:
		return

	_triggered_bodies.append(body)
	_has_triggered = true

	triggered.emit(body)


func _on_body_exited(body: Node) -> void:
	if not active:
		return

	if not _passes_filter(body):
		return

	trigger_exited.emit(body)


func _passes_filter(body: Node) -> bool:
	# Simple group-based filtering
	# Assuming standard groups "player", "enemies", "props"

	if (filter_flags & 1) and body.is_in_group("player"):  # Bit 1
		return true
	if (filter_flags & 2) and body.is_in_group("enemies"):  # Bit 2
		return true
	if (filter_flags & 4) and body is RigidBody3D:  # Bit 3 - Prop approximation
		return true

	return false


func reset() -> void:
	_has_triggered = false
	_triggered_bodies.clear()
