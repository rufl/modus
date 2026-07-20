class_name PhysicalRagdollPart
extends PhysicalBone3D
## Damage adapter for mannequin PhysicalBone3D nodes in Godot 4.7.

var root: Node3D
var part_id: String


func take_damage(
	info_or_damage: Variant, _dir: Vector3 = Vector3.ZERO, _force: float = 0.0
) -> void:
	if root and is_instance_valid(root) and root.has_method("on_part_hit"):
		root.on_part_hit(self, info_or_damage)
