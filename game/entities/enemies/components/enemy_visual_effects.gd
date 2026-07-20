class_name EnemyVisualEffects
extends Node

const TIER_COLORS: Dictionary = {
	0: Color(0.8, 0.8, 0.8),  # Normal - Gray
	1: Color(0.2, 0.8, 0.2),  # Veteran - Green
	2: Color(0.2, 0.4, 1.0),  # Elite - Blue
	3: Color(1.0, 0.6, 0.0)  # Boss - Orange
}

var _enemy: Node
var _visuals: SkeletalCharacterVisuals
var _debug_particles: GPUParticles3D


func setup(enemy: Node, visuals: SkeletalCharacterVisuals) -> void:
	_enemy = enemy
	_visuals = visuals


func apply_visuals(data: Dictionary) -> void:
	if "visuals" in data:
		var visual_config: Dictionary = data.visuals

		# Check for custom visual scene override
		if "visual_scene" in visual_config:
			var scene_path: String = visual_config.visual_scene
			if ResourceLoader.exists(scene_path):
				var custom_visual: Node3D = load(scene_path).instantiate()
				if custom_visual:
					# Apply color if present
					var c_hex: String = visual_config.get("color", "#ffffff")
					if "color" in custom_visual:
						custom_visual.set("color", Color(c_hex))

					_enemy.add_child(custom_visual)
					custom_visual.name = "CustomVisuals"

					# Link Head to Perception (for accurate vision origin)
					if "head_mesh" in custom_visual and custom_visual.head_mesh:
						if _enemy.perception_component:
							_enemy.perception_component.head_node = custom_visual.head_mesh

					# Custom visual loaded - overlaps skeletal visuals?
					# Assuming Custom Visual replaces everything for now.
					if _visuals:
						_visuals.visible = false

		# Standard color/scaling logic
		var color_hex: String = visual_config.get("color", "#ffffff")

		_enemy.base_color = Color(color_hex)
		var scale_val: float = data.visuals.get("scale", 1.0)

		_enemy.scale = Vector3.ONE * scale_val

		# Apply to Skeletal Visuals
		if _visuals:
			_visuals.set_color(_enemy.base_color)
			update_tier_visuals()


func update_tier_visuals() -> void:
	if not _visuals:
		return

	var tier: int = _enemy.tier
	_visuals.apply_tier_effects(tier)

	# Adjust color brightness based on tier
	var tier_color: Color = _enemy.base_color
	match tier:
		2:
			tier_color = _enemy.base_color.lightened(0.2)
		3:
			tier_color = _enemy.base_color.lightened(0.3)
		4:
			tier_color = _enemy.base_color.lightened(0.4)

	_visuals.set_color(tier_color)


func create_debug_particles() -> void:
	if _debug_particles:
		return

	_debug_particles = GPUParticles3D.new()
	_debug_particles.name = "DebugVisionLights"

	# Orange Christmas light material with emission
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.0, 0.9)  # Bright orange
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)  # Orange glow
	mat.emission_energy_multiplier = 3.0  # Bright Christmas lights

	# Slightly larger "light bulb" mesh
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.25)  # Compact bulb shape
	mesh.material = mat

	_debug_particles.draw_pass_1 = mesh
	_debug_particles.amount = 10  # Distinct lights (not too many)
	_debug_particles.lifetime = 0.6  # Faster cycling for twinkling effect
	_debug_particles.local_coords = true  # Attached to enemy

	# CRITICAL: Single line emission with twinkling
	_debug_particles.process_material = _create_christmas_light_process()

	_enemy.add_child(_debug_particles)
	_debug_particles.position = Vector3(0, 1.5, 0)  # Above enemy
	_debug_particles.emitting = false


func _create_christmas_light_process() -> ParticleProcessMaterial:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0, -1)  # Forward direction
	process.spread = 0.0  # NO SPREAD - single line only!
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 8.0
	process.initial_velocity_max = 14.0

	# Random scale for "twinkling" brightness effect
	process.scale_min = 0.6  # Dim lights
	process.scale_max = 1.8  # Bright lights

	# Add slight random variation to create irregular twinkling
	process.angle_min = -5.0
	process.angle_max = 5.0

	return process


func toggle_debug_particles(enabled: bool) -> void:
	if _debug_particles:
		_debug_particles.emitting = enabled
