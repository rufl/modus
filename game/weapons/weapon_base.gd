extends Node3D

## Base script for weapon view models
## Provides common functionality for all weapon instances

@export_group("Visuals")
@export var default_anim: String = "idle"
@export var hide_on_holster: bool = true

var _animation_player: AnimationPlayer


func _ready() -> void:
	_animation_player = get_node_or_null("AnimationPlayer")
	if _animation_player and _animation_player.has_animation(default_anim):
		_animation_player.play(default_anim)


func play_animation(anim_name: String) -> void:
	if _animation_player and _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)


func play_idle() -> void:
	if _animation_player and _animation_player.has_animation(default_anim):
		_animation_player.play(default_anim)


func get_muzzle_point() -> Node3D:
	var muzzle: Node3D = get_node_or_null("Muzzle")
	if not muzzle:
		muzzle = get_node_or_null("MuzzlePoint")
	if not muzzle:
		muzzle = get_node_or_null("BarrelEnd")
	return muzzle
