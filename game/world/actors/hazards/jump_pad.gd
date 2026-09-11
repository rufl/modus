@tool
class_name JumpPad
extends Area3D

@export var launch_velocity: Vector3 = Vector3(0, 15, 0)
@export var launch_sound: AudioStream


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		# Launch!
		if body.has_method("apply_knockback"):
			# Use knockback system if available (usually adds to velocity)
			body.apply_knockback(launch_velocity)
		elif "velocity" in body:
			# Direct velocity set (Quake style override)
			# Preserves horizontal if launch is pure vertical?
			# Usually jump pads override vertical but add to horizontal or override all.
			# Let's add to current velocity for more fun, or override Y.
			body.velocity.y = launch_velocity.y
			body.velocity.x += launch_velocity.x
			body.velocity.z += launch_velocity.z

		if launch_sound:
			var audio: Node = GameManager.get_core_system("audio")
			if audio and audio.has_method("play_stream_3d"):
				audio.play_stream_3d(launch_sound, global_position)
