class_name MaterialManager
extends Node

## Manages materials and visual effects for skeletal characters
## Extracted from SkeletalCharacterVisuals for better separation

var main_material: StandardMaterial3D
var eye_material: StandardMaterial3D
var xray_material: StandardMaterial3D

var color: Color = Color(0.5, 0.5, 0.9)
var _root_node: Node3D


func setup(root: Node3D, initial_color: Color) -> void:
	_root_node = root
	color = initial_color
	_create_materials()


func _create_materials() -> void:
	main_material = StandardMaterial3D.new()
	main_material.albedo_color = color

	eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.0, 0.0)
	eye_material.emission_enabled = false
	eye_material.emission = Color(1.0, 0.0, 0.0)
	eye_material.emission_energy_multiplier = 8.0


func set_color(new_color: Color) -> void:
	color = new_color
	if main_material:
		main_material.albedo_color = color


func set_eye_glow(enabled: bool) -> void:
	if eye_material:
		eye_material.emission_enabled = enabled


func flash(emission_color: Color = Color.WHITE, duration: float = 0.1) -> void:
	if not main_material:
		return

	main_material.emission_enabled = true
	main_material.emission = emission_color
	main_material.emission_energy_multiplier = 2.0

	if duration > 0:
		var tween := _root_node.create_tween()
		tween.tween_interval(duration)
		tween.tween_callback(stop_flash)


func stop_flash() -> void:
	if main_material:
		main_material.emission_enabled = false


func apply_tier_effects(tier: int) -> void:
	if not main_material:
		return

	main_material.rim_enabled = false

	if tier >= 2:
		main_material.rim_enabled = true
		main_material.rim = 0.5
		main_material.rim_tint = 0.5


func set_xray_enabled(enabled: bool) -> void:
	if enabled and not xray_material:
		xray_material = StandardMaterial3D.new()
		xray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		xray_material.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
		xray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		xray_material.no_depth_test = true
		xray_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		xray_material.render_priority = 127

	_apply_xray_recursive(_root_node, enabled)


func _apply_xray_recursive(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		node.material_overlay = xray_material if enabled else null

	for child in node.get_children():
		_apply_xray_recursive(child, enabled)


func get_main_material() -> StandardMaterial3D:
	return main_material


func get_eye_material() -> StandardMaterial3D:
	return eye_material
