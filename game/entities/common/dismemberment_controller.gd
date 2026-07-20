class_name DismembermentController
extends Node

## Handles limb dismemberment logic
## Extracted from SkeletalCharacterVisuals for better separation

var skeleton: Skeleton3D
var mannequin_instance: Node3D

var _dismembered_limbs: Array[String] = []
var _limb_groups: Dictionary = {
	"head": ["Head", "Neck"],
	"arm_l": ["LeftArm"],
	"arm_r": ["RightArm"],
	"leg_l": ["LeftUpLeg"],
	"leg_r": ["RightUpLeg"],
}


func setup(skel: Skeleton3D, mannequin: Node3D) -> void:
	skeleton = skel
	mannequin_instance = mannequin


func dismember(limb_id: String) -> void:
	if not skeleton:
		return

	if limb_id in _dismembered_limbs:
		return

	var bones: Array = _limb_groups.get(limb_id, [])
	if bones.is_empty():
		return

	for bone_name: String in bones:
		var idx: int = skeleton.find_bone(_find_matching_bone(bone_name))
		if idx != -1:
			skeleton.set_bone_pose_scale(idx, Vector3.ZERO)
		_toggle_node_visibility(bone_name, false)

	_toggle_node_visibility(limb_id, false)
	_dismembered_limbs.append(limb_id)
	_spawn_stump_blood(limb_id)


func is_limb_dismembered(limb_id: String) -> bool:
	return limb_id in _dismembered_limbs


func find_hit_limb(hit_pos: Vector3, parent_global_transform: Transform3D) -> String:
	if not skeleton:
		return ""

	var closest_limb: String = "torso"
	var min_dist: float = 9999.0

	for limb_id: String in _limb_groups:
		var bones: Array = _limb_groups[limb_id]
		for bone_name: String in bones:
			var idx: int = skeleton.find_bone(_find_matching_bone(bone_name))
			if idx != -1:
				var bone_pos: Vector3 = (
					parent_global_transform * skeleton.get_bone_global_pose(idx).origin
				)
				var dist: float = hit_pos.distance_to(bone_pos)
				if dist < min_dist:
					min_dist = dist
					closest_limb = limb_id

	return closest_limb


func _spawn_stump_blood(limb_id: String) -> void:
	if not skeleton:
		return

	var root_bone: String = _limb_groups[limb_id][0]
	var idx: int = skeleton.find_bone(_find_matching_bone(root_bone))
	if idx != -1:
		var pos: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(idx).origin)
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			var gs: Node = gm.get_core_system("gameplay")
			if gs and gs.effects and gs.effects.has_method("spawn_blood_synced"):
				gs.effects.spawn_blood_synced.rpc(pos, Vector3.UP, 0.5)


func _toggle_node_visibility(node_name: String, should_be_visible: bool) -> void:
	if not mannequin_instance:
		return

	var patterns: Array[String] = [
		node_name, "Mannequin_" + node_name, "SM_Mannequin_" + node_name, node_name + "_Mesh"
	]

	for pattern in patterns:
		var node: Node = mannequin_instance.find_child(pattern, true, false)
		if node and node is Node3D:
			node.visible = should_be_visible


func _find_matching_bone(bone_name: String) -> String:
	return MannequinBoneMap.resolve(skeleton, bone_name)
