extends Node3D
class_name LootBeacon

const RARITY_CONFIG: Dictionary = {
	0: {"name": "Common", "color": Color(0.7, 0.7, 0.7), "height": 1.5, "intensity": 0.3},
	1: {"name": "Uncommon", "color": Color(0.2, 0.8, 0.2), "height": 2.0, "intensity": 0.5},
	2: {"name": "Rare", "color": Color(0.2, 0.4, 1.0), "height": 2.5, "intensity": 0.7},
	3: {"name": "Epic", "color": Color(0.6, 0.2, 0.8), "height": 3.0, "intensity": 0.9},
	4: {"name": "Legendary", "color": Color(1.0, 0.6, 0.0), "height": 4.0, "intensity": 1.2},
}

@export var rarity_tier: int = 0  # 0=Common, 1=Uncommon, 2=Rare, 3=Epic, 4=Legendary
@export var auto_configure: bool = true

var beam_height: float = 2.0
var beam_color: Color = Color.WHITE
var glow_intensity: float = 0.5
var beam_particles: GPUParticles3D = null
var base_light: OmniLight3D = null
var pulse_tween: Tween = null


func _ready() -> void:
	if auto_configure:
		set_rarity_tier(rarity_tier)

	_create_beam_particles()
	_create_base_light()
	_start_pulse_animation()


func set_rarity_tier(tier: int) -> void:
	## Configure beacon appearance based on rarity tier
	rarity_tier = clamp(tier, 0, 4)

	var config: Dictionary = RARITY_CONFIG.get(rarity_tier, RARITY_CONFIG[0])
	beam_height = config.height
	beam_color = config.color
	glow_intensity = config.intensity

	# Update existing components if already created
	if is_inside_tree():
		if beam_particles:
			_update_beam_particles()
		if base_light:
			_update_base_light()


func set_rarity(rarity: Variant) -> void:
	## Set beacon from ItemRarity resource or tier int
	if rarity is int:
		set_rarity_tier(rarity)
	elif rarity and "tier" in rarity:
		set_rarity_tier(rarity.tier)


func _create_beam_particles() -> void:
	## Create upward beam effect using GPUParticles3D
	beam_particles = GPUParticles3D.new()
	beam_particles.name = "BeamParticles"
	add_child(beam_particles)

	# Particle settings
	beam_particles.emitting = true
	beam_particles.amount = 50
	beam_particles.lifetime = 2.0
	beam_particles.explosiveness = 0.0
	beam_particles.randomness = 0.2
	beam_particles.visibility_aabb = AABB(
		Vector3(-0.5, 0, -0.5), Vector3(1.0, beam_height + 2.0, 1.0)
	)

	# Create process material
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()

	# Emission shape - point at base
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.1

	# Direction - straight up
	material.direction = Vector3(0, 1, 0)
	material.spread = 5.0
	material.initial_velocity_min = beam_height * 0.5
	material.initial_velocity_max = beam_height * 0.7

	# Gravity - none (beam goes up)
	material.gravity = Vector3.ZERO

	# Scale over lifetime
	material.scale_min = 0.05
	material.scale_max = 0.1

	# Color
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, beam_color)
	gradient.add_point(0.5, beam_color * 1.2)
	gradient.add_point(1.0, Color(beam_color.r, beam_color.g, beam_color.b, 0.0))

	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	# Alpha over lifetime - fade out at top
	var alpha_curve: Curve = Curve.new()
	alpha_curve.add_point(Vector2(0.0, 1.0))
	alpha_curve.add_point(Vector2(0.7, 0.8))
	alpha_curve.add_point(Vector2(1.0, 0.0))

	var curve_texture: CurveTexture = CurveTexture.new()
	curve_texture.curve = alpha_curve
	material.alpha_curve = curve_texture

	beam_particles.process_material = material

	# Create draw pass mesh
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.1, 0.1)

	# Create material for particles
	var draw_material: StandardMaterial3D = StandardMaterial3D.new()
	draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_material.albedo_color = beam_color
	draw_material.emission_enabled = true
	draw_material.emission = beam_color
	draw_material.emission_energy_multiplier = glow_intensity * 2.0

	quad_mesh.material = draw_material
	beam_particles.draw_pass_1 = quad_mesh


func _update_beam_particles() -> void:
	## Update beam particles with current settings
	if not beam_particles:
		return

	# Update visibility AABB
	beam_particles.visibility_aabb = AABB(
		Vector3(-0.5, 0, -0.5), Vector3(1.0, beam_height + 2.0, 1.0)
	)

	# Update process material
	var proc_material: ParticleProcessMaterial = (
		beam_particles.process_material as ParticleProcessMaterial
	)
	if proc_material:
		proc_material.initial_velocity_min = beam_height * 0.5
		proc_material.initial_velocity_max = beam_height * 0.7

		# Update color gradient
		var gradient: Gradient = Gradient.new()
		gradient.add_point(0.0, beam_color)
		gradient.add_point(0.5, beam_color * 1.2)
		gradient.add_point(1.0, Color(beam_color.r, beam_color.g, beam_color.b, 0.0))

		var gradient_texture: GradientTexture1D = GradientTexture1D.new()
		gradient_texture.gradient = gradient
		proc_material.color_ramp = gradient_texture

	# Update draw pass material
	if beam_particles.draw_pass_1:
		var mesh: QuadMesh = beam_particles.draw_pass_1 as QuadMesh
		if mesh and mesh.material:
			var draw_material: StandardMaterial3D = mesh.material as StandardMaterial3D
			if draw_material:
				draw_material.albedo_color = beam_color
				draw_material.emission = beam_color
				draw_material.emission_energy_multiplier = glow_intensity * 2.0


func _create_base_light() -> void:
	## Create pulsing glow at base using OmniLight3D
	base_light = OmniLight3D.new()
	base_light.name = "BaseLight"
	add_child(base_light)

	# Position slightly above ground
	base_light.position = Vector3(0, 0.1, 0)

	# Light settings
	base_light.light_color = beam_color
	base_light.light_energy = glow_intensity
	base_light.omni_range = 2.0 + (beam_height * 0.2)
	base_light.omni_attenuation = 2.0


func _update_base_light() -> void:
	## Update base light with current settings
	if not base_light:
		return

	base_light.light_color = beam_color
	base_light.light_energy = glow_intensity
	base_light.omni_range = 2.0 + (beam_height * 0.2)


func _start_pulse_animation() -> void:
	## Start pulsing animation for base light
	if not base_light:
		return

	pulse_tween = create_tween()
	pulse_tween.set_loops()

	var min_energy: float = glow_intensity * 0.7
	var max_energy: float = glow_intensity * 1.3

	pulse_tween.tween_property(base_light, "light_energy", max_energy, 0.8)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)

	pulse_tween.tween_property(base_light, "light_energy", min_energy, 0.8)
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)


func cleanup() -> void:
	## Stop effects and prepare for removal
	if pulse_tween:
		pulse_tween.kill()

	if beam_particles:
		beam_particles.emitting = false

	# Fade out light
	if base_light:
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(base_light, "light_energy", 0.0, 0.3)
		await fade_tween.finished

	queue_free()


func get_rarity_name() -> String:
	## Get display name for current rarity
	var config: Dictionary = RARITY_CONFIG.get(rarity_tier, RARITY_CONFIG[0])
	return config.get("name", "Unknown")
