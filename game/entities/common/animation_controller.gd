class_name AnimationController
extends Node

## Manages animation player and animation tree
## Extracted from SkeletalCharacterVisuals for better separation

const ANIMATION_LIBRARY_PATH: String = "res://game/art/anims/AnimationLibrary_Godot.glb"

var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var skeleton: Skeleton3D


func setup(skel: Skeleton3D) -> void:
	skeleton = skel


func setup_animation_player() -> bool:
	if not skeleton:
		return false

	# Find or create AnimationPlayer
	anim_player = skeleton.get_node_or_null("AnimationPlayer")
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		skeleton.add_child(anim_player)

	# Load animation library directly from GLB
	if ResourceLoader.exists(ANIMATION_LIBRARY_PATH):
		var loaded_resource: Resource = load(ANIMATION_LIBRARY_PATH)

		# Check if it's an AnimationLibrary directly
		if loaded_resource is AnimationLibrary:
			anim_player.add_animation_library("", loaded_resource)
		# Or if it's a PackedScene with an AnimationPlayer
		elif loaded_resource is PackedScene:
			var anim_lib_instance: Node = loaded_resource.instantiate()
			var imported_player: AnimationPlayer = _find_animation_player(anim_lib_instance)

			if imported_player:
				# Copy all animations as-is
				for lib_name in imported_player.get_animation_library_list():
					var lib: AnimationLibrary = imported_player.get_animation_library(lib_name)
					if lib:
						anim_player.add_animation_library(lib_name, lib)

			anim_lib_instance.queue_free()
		else:
			push_warning(
				"[AnimationController] Unexpected resource type: %s" % loaded_resource.get_class()
			)

	return true


func setup_animation_tree() -> bool:
	if not anim_player:
		return false

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	skeleton.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = true

	return true


func play_anim(anim_name: String, blend_time: float = 0.1) -> void:
	if not anim_player:
		return

	var mapping: Dictionary = get_animation_mapping()
	var actual_name: String = mapping.get(anim_name, anim_name)

	if anim_player.has_animation(actual_name):
		anim_player.play(actual_name, blend_time)
	else:
		push_warning(
			(
				"[AnimationController] Animation not found: %s (mapped to %s)"
				% [anim_name, actual_name]
			)
		)


func stop_anim() -> void:
	if anim_player:
		anim_player.stop()


func is_playing(anim_name: String = "") -> bool:
	if not anim_player:
		return false

	if anim_name.is_empty():
		return anim_player.is_playing()

	return anim_player.current_animation == anim_name


func get_animation_mapping() -> Dictionary:
	return {
		"idle": "Idle",
		"walk": "Walk",
		"jog": "Jog_Fwd",
		"run": "Jog_Fwd",
		"sprint": "Sprint",
		"crouch_idle": "Crouch_Idle",
		"crouch_walk": "Crouch_Fwd",
		"crouch_back": "Crouch_Bwd",
		"slide": "Crouch_Fwd",
		"jump": "Jump",
		"jump_start": "Jump_Start",
		"jump_land": "Jump_Land",
		"inair": "Jump",
		"fall": "Jump",
		"crawl": "Crawl_Fwd",
		"crawl_idle": "Crawl_Idle",
		"crawl_back": "Crawl_Bwd",
		"crawl_enter": "Crawl_Enter",
		"crawl_exit": "Crawl_Exit",
		"hurt": "Hit_Chest",
		"hurt_head": "Hit_Head",
		"hurt_stomach": "Hit_Stomach",
		"hurt_shoulder_l": "Hit_Shoulder_L",
		"hurt_shoulder_r": "Hit_Shoulder_R",
		"death": "Death01",
		"death_alt": "Death02",
		"melee_left": "Punch_Jab",
		"melee_right": "Punch_Cross",
		"kick": "Kick",
		"telegraph": "PunchKick_Enter",
		"combat_enter": "PunchKick_Enter",
		"combat_exit": "PunchKick_Exit",
		"pistol_idle": "Pistol_Idle",
		"pistol_shoot": "Pistol_Shoot",
		"pistol_reload": "Pistol_Reload",
		"pistol_aim_up": "Pistol_Aim_Up",
		"pistol_aim_down": "Pistol_Aim_Down",
		"pistol_aim_neutral": "Pistol_Aim_Neutral",
		"roll": "Roll",
		"dodge_left": "Dodge_Left",
		"dodge_right": "Dodge_Right",
		"lean_left": "Jog_Fwd_LeanL",
		"lean_right": "Jog_Fwd_LeanR",
		"interact": "Interact",
		"push": "Push",
		"drink": "Drink",
		"spell_idle": "Spell_Simple_Idle",
		"swim": "Swim_Fwd",
		"climb": "Climb_Up",
		"climb_idle": "Climb_Idle",
		"swap_in": "Pistol_Aim_Neutral",
		"swap_out": "Pistol_Aim_Down",
		"celebration": "Celebration",
		"dance": "Dance",
		"sitting": "Sitting_Idle",
	}


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root

	for child in root.get_children():
		if child is AnimationPlayer:
			return child
		var result: AnimationPlayer = _find_animation_player(child)
		if result:
			return result

	return null
