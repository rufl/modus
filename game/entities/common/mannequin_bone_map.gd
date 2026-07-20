class_name MannequinBoneMap
extends RefCounted
## Stable gameplay part IDs mapped to the Blender DEF rig in mannequin_mesh.glb.

const LOGICAL_TO_RIG: Dictionary = {
	"Torso": "DEF-spine.003",
	"Hips": "DEF-hips",
	"Spine": "DEF-spine.001",
	"Spine1": "DEF-spine.003",
	"Head": "DEF-head",
	"LeftArm": "DEF-upper_arm.L",
	"LeftForeArm": "DEF-forearm.L",
	"RightArm": "DEF-upper_arm.R",
	"RightForeArm": "DEF-forearm.R",
	"LeftUpLeg": "DEF-thigh.L",
	"LeftLeg": "DEF-shin.L",
	"RightUpLeg": "DEF-thigh.R",
	"RightLeg": "DEF-shin.R",
}


static func resolve(skeleton: Skeleton3D, logical_name: String) -> String:
	if not skeleton:
		return logical_name
	if skeleton.find_bone(logical_name) != -1:
		return logical_name

	var mapped_name: String = String(LOGICAL_TO_RIG.get(logical_name, ""))
	if not mapped_name.is_empty() and skeleton.find_bone(mapped_name) != -1:
		return mapped_name

	var variations: Array[String] = [
		"mixamorig:" + logical_name,
		"mixamorig_" + logical_name,
		logical_name.to_lower(),
		logical_name.to_upper(),
	]
	for variant: String in variations:
		if skeleton.find_bone(variant) != -1:
			return variant

	return logical_name
