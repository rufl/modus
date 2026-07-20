extends Node3D

const GibfestUtils = preload("res://game/scripts/features/effects/effects/gibfest.gd")

@onready var dummy: RigidBody3D = $Dummy


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):  # Space
		spawn_gibs_at_dummy()

	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()

	if Input.is_key_pressed(KEY_E):
		# Explode near dummy
		pass


func spawn_gibs_at_dummy() -> void:
	if is_instance_valid(dummy):
		GibfestUtils.spawn_gibs(self, dummy.global_position + Vector3(0, 1, 0), Vector3.UP, 1.5)
		dummy.queue_free()
