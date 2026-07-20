extends Node3D

@export_group("Visuals")
@export var default_anim: String = "idle"
@export var hide_on_holster: bool = true

var _animation_player: AnimationPlayer


func _ready() -> void:
	_animation_player = get_node_or_null("AnimationPlayer")


func play_attack_anim(anim_name: String = "slash") -> void:
	if _animation_player and _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)
	elif _animation_player:
		# Fallback
		if _animation_player.has_animation("attack"):
			_animation_player.play("attack")


func play_idle() -> void:
	if _animation_player and _animation_player.has_animation(default_anim):
		_animation_player.play(default_anim)
