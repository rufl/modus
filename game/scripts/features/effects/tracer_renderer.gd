class_name TracerRenderer
extends Node

## Handles bullet tracer rendering
## Extracted from EffectsService for better separation

const RETRO_TRACER_SHADER = preload("res://game/art/shaders/retro_tracer.gdshader")


func spawn_tracer(
	from: Vector3, to: Vector3, color: Color = Color(1, 0.9, 0.4), lifetime: float = 0.15
) -> void:
	var dist: float = from.distance_to(to)
	if dist < 0.1:
		return

	var tracer := MeshInstance3D.new()
	var mesh := QuadMesh.new()

	var tracer_width: float = 0.08
	var tracer_length: float = minf(dist, 6.0)
	mesh.size = Vector2(tracer_length, tracer_width)
	mesh.orientation = PlaneMesh.FACE_Z
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Shader material
	var mat := ShaderMaterial.new()
	mat.shader = RETRO_TRACER_SHADER
	mat.set_shader_parameter("core_color", color)
	mat.set_shader_parameter("edge_color", color.darkened(0.3))
	mat.set_shader_parameter("core_width", 0.5)
	mat.set_shader_parameter("pixel_steps", 6.0)
	mat.set_shader_parameter("fade_power", 1.5)
	tracer.material_override = mat

	get_tree().root.add_child(tracer)
	tracer.global_position = from

	# Orient towards target
	var direction: Vector3 = (to - from).normalized()
	if direction.length() > 0.01:
		if abs(direction.dot(Vector3.UP)) > 0.99:
			tracer.look_at(to, Vector3.RIGHT)
		else:
			tracer.look_at(to, Vector3.UP)
		tracer.rotate_object_local(Vector3.UP, PI / 2.0)

	# Animate
	var travel_time: float = clampf(dist / 200.0, 0.03, lifetime * 0.6)
	var fade_time: float = lifetime * 0.4

	var tween: Tween = tracer.create_tween()
	tween.tween_property(tracer, "global_position", to, travel_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(mat, "shader_parameter/fade_power", 4.0, fade_time)
	tween.parallel().tween_property(tracer, "scale", Vector3(0.5, 0.2, 0.2), fade_time)
	tween.tween_callback(tracer.queue_free)


func spawn_simple_tracer(from: Vector3, to: Vector3, color: Color = Color(1, 0.9, 0.4)) -> void:
	var dist: float = from.distance_to(to)
	if dist < 0.1:
		return

	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var thickness: float = 0.05
	mesh.size = Vector3(thickness, thickness, dist)
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	get_tree().root.add_child(tracer)
	tracer.global_position = (from + to) * 0.5

	# Orient
	if abs(from.x - to.x) < 0.01 and abs(from.z - to.z) < 0.01:
		tracer.look_at(to, Vector3.RIGHT)
	else:
		tracer.look_at(to, Vector3.UP)

	# Material
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	tracer.material_override = mat

	# Fade out
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25).set_trans(Tween.TRANS_CIRC).set_ease(
		Tween.EASE_IN
	)
	tween.tween_property(tracer, "scale:x", 0.1, 0.25)
	tween.tween_property(tracer, "scale:y", 0.1, 0.25)
	tween.chain().tween_callback(tracer.queue_free)
