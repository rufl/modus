@tool
class_name DamageZone
extends Area3D

enum DamageType { GENERIC = 0, FIRE = 1, ACID = 2, VOID = 3 }

@export var damage_per_second: float = 10.0
@export var damage_type: DamageType = DamageType.GENERIC
@export var tick_rate: float = 0.5  # Seconds between ticks
@export var instakill: bool = false
@export var enter_sound: AudioStream

var _bodies_in_zone: Array[Node3D] = []
var _timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _bodies_in_zone.is_empty():
		return

	_timer += delta
	if _timer >= tick_rate:
		_timer = 0.0
		_apply_damage()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D or body is RigidBody3D:
		_bodies_in_zone.append(body)

		# Initial hit
		_damage_entity(body)

		if enter_sound:
			var audio: Node = GameManager.get_core_system("audio")
			if audio and audio.has_method("play_stream_3d"):
				audio.play_stream_3d(enter_sound, body.global_position)


func _on_body_exited(body: Node3D) -> void:
	_bodies_in_zone.erase(body)


func _apply_damage() -> void:
	# Safely iterate backwards in case bodies were freed
	for i in range(_bodies_in_zone.size() - 1, -1, -1):
		var body: Node3D = _bodies_in_zone[i]
		if is_instance_valid(body):
			_damage_entity(body)
		else:
			_bodies_in_zone.remove_at(i)


func _damage_entity(body: Node3D) -> void:
	if instakill:
		if body.has_method("die"):
			body.die()
		elif body.has_node("HealthComponent"):
			body.get_node("HealthComponent").die()
		else:
			body.queue_free()
		return

	# Use standard take_damage interface via DamageInfo
	if body.has_method("take_damage"):
		# Construct damage info
		var type_enum: DamageInfo.DamageType = DamageInfo.DamageType.GENERIC
		match damage_type:
			DamageType.FIRE:
				type_enum = DamageInfo.DamageType.FIRE
			DamageType.ACID:
				type_enum = DamageInfo.DamageType.POISON
			DamageType.VOID:
				type_enum = DamageInfo.DamageType.VOID

		var info: DamageInfo = DamageInfo.create(damage_per_second * tick_rate, type_enum, self)
		body.take_damage(info)
