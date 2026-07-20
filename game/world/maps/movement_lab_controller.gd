class_name MovementLabController
extends Node3D

@export var speed_label: Label3D
@export var bhop_counter_label: Label3D
@export var technique_label: Label3D

var _peak_speed: float = 0.0
var _bhop_count: int = 0
var _current_technique: String = ""


func _ready() -> void:
	# Find labels if not exported
	if not speed_label:
		speed_label = get_node_or_null("SpeedLabel")
	if not bhop_counter_label:
		bhop_counter_label = get_node_or_null("BhopCounterLabel")
	if not technique_label:
		technique_label = get_node_or_null("TechniqueLabel")

	# Listen for player movement events
	GameManager.subscribe("movement_technique_used", _on_technique_used)


func _exit_tree() -> void:
	# Unsubscribe from events to prevent null callable errors
	GameManager.unsubscribe("movement_technique_used", _on_technique_used)


func _process(_delta: float) -> void:
	_update_speed_display()


func _update_speed_display() -> void:
	# Find local player
	var player: CharacterBody3D = _get_local_player()
	if not player:
		return

	# Calculate horizontal speed
	var horizontal_vel := Vector2(player.velocity.x, player.velocity.z)
	var speed: float = horizontal_vel.length()

	# Track peak
	if speed > _peak_speed:
		_peak_speed = speed

	# Update label
	if speed_label:
		speed_label.text = "Speed: %.1f u/s\nPeak: %.1f u/s" % [speed, _peak_speed]

		# Color based on speed
		if speed > 12.0:
			speed_label.modulate = Color.GREEN
		elif speed > 8.0:
			speed_label.modulate = Color.YELLOW
		else:
			speed_label.modulate = Color.WHITE


func _on_technique_used(data: Dictionary) -> void:
	var technique: String = data.get("technique", "")
	var _speed: float = data.get("speed", 0.0)

	match technique:
		"bunny_hop":
			_bhop_count += 1
			_current_technique = "BHOP x%d" % _bhop_count
		"slide":
			_current_technique = "SLIDE"
		"strafe":
			_current_technique = "STRAFE"
		_:
			_current_technique = technique.to_upper()

	_update_technique_display()

	# Clear after delay
	await get_tree().create_timer(1.0).timeout
	if _current_technique == technique.to_upper() or _current_technique.begins_with("BHOP"):
		_current_technique = ""
		_update_technique_display()


func _update_technique_display() -> void:
	if bhop_counter_label:
		bhop_counter_label.text = "Bhops: %d" % _bhop_count

	if technique_label:
		technique_label.text = _current_technique
		technique_label.modulate = Color.CYAN if not _current_technique.is_empty() else Color.WHITE


func reset_stats() -> void:
	_peak_speed = 0.0
	_bhop_count = 0
	_current_technique = ""
	_update_technique_display()


func _get_local_player() -> CharacterBody3D:
	var players: Array = get_tree().get_nodes_in_group("player")
	for player: Node in players:
		if player is CharacterBody3D and player.is_multiplayer_authority():
			return player
	return null
