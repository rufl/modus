@tool
class_name LiquidVolume
extends Area3D

@export_enum("Water", "Acid", "Lava", "Slime") var liquid_type: String = "Water"
@export var viscosity: float = 0.5  # 0.0 = air, 1.0 = solid
@export var gravity_multiplier: float = 0.2  # Reduced gravity in liquid
@export var damage_per_second: float = 0.0

var _bodies_in_liquid: Array[Node] = []
var _damage_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return

	if damage_per_second > 0 and _bodies_in_liquid.size() > 0:
		_damage_timer += delta
		if _damage_timer >= 1.0:
			_damage_timer = 0.0
			_apply_damage()


func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_liquid"):
		body.enter_liquid(self)
		_bodies_in_liquid.append(body)


func _on_body_exited(body: Node) -> void:
	# Ensure checking against list to avoid duplicates if re-entered quickly
	if body in _bodies_in_liquid:
		_bodies_in_liquid.erase(body)

	if body.has_method("exit_liquid"):
		body.exit_liquid(self)


func _apply_damage() -> void:
	for body in _bodies_in_liquid:
		if body.has_method("take_damage"):
			# 0 as source ID for Environment
			body.take_damage(damage_per_second, 0)
