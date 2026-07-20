shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

// Enhanced Liquid Shader - Advanced fluid simulation with realistic properties
// Features: Dynamic waves, refraction, caustics, foam, ripples, and advanced lighting

group_uniforms LiquidProperties;
uniform vec4 liquid_color : source_color = vec4(0.2, 0.6, 1.0, 0.7);
uniform float absorption_factor : hint_range(0.0, 5.0) = 1.0;
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.1;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.3;

group_uniforms WaveSimulation;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;
uniform float wave_height : hint_range(0.0, 2.0) = 0.1;
uniform float wave_frequency : hint_range(0.0, 20.0) = 8.0;
uniform vec2 wave_direction1 = vec2(1.0, 0.0);
uniform vec2 wave_direction2 = vec2(0.7, 0.7);

group_uniforms Caustics;
uniform bool enable_caustics = true;
uniform float caustic_strength : hint_range(0.0, 2.0) = 0.5;
uniform float caustic_speed : hint_range(0.0, 5.0) = 1.0;
uniform float caustic_scale : hint_range(0.01, 5.0) = 1.0;

group_uniforms Foam;
uniform bool enable_foam = true;
uniform vec4 foam_color : source_color = vec4(0.9, 0.9, 0.95, 0.8);
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float foam_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float foam_roughness : hint_range(0.0, 1.0) = 0.8;

group_uniforms Lighting;
uniform float specular_intensity : hint_range(0.0, 5.0) = 1.0;
uniform float rim_lighting : hint_range(0.0, 5.0) = 0.5;
uniform float fresnel_power : hint_range(0.1, 10.0) = 5.0;

varying vec3 world_pos;
varying float wave_displacement;

void vertex() {
	// Calculate world position
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Calculate wave displacement using multiple wave layers
	vec2 wave_uv = UV * wave_frequency;
	float wave1 = sin(dot(wave_uv, wave_direction1) + TIME * wave_speed) * 0.5 + 0.5;
	float wave2 = sin(dot(wave_uv, wave_direction2) + TIME * wave_speed * 1.3) * 0.5 + 0.5;
	
	// Combine waves with different frequencies and amplitudes
	float combined_wave = (wave1 + wave2) * 0.5;
	wave_displacement = combined_wave * wave_height;
	
	// Apply wave displacement to vertex
	VERTEX.y += wave_displacement;
	
	// Update normal based on wave displacement
	vec3 tangent = vec3(1.0, dFdx(wave_displacement), 0.0);
	vec3 bitangent = vec3(0.0, dFdy(wave_displacement), 1.0);
	NORMAL = normalize(cross(tangent, bitangent));
}

void fragment() {
	// Base liquid color with depth-based absorption
	vec4 base_color = liquid_color;
	
	// Calculate view-dependent effects
	vec3 view_dir = normalize(CAMERA_POSITION - world_pos);
	float fresnel = pow(1.0 - saturate(dot(NORMAL, view_dir)), fresnel_power);
	
	// Calculate refraction effect
	vec2 refracted_uv = UV + (NORMAL.xz * refraction_strength * fresnel);
	
	// Apply surface roughness
	ROUGHNESS = surface_roughness + wave_displacement * 0.2;
	
	// Calculate specular highlights
	vec3 reflected_light = reflect(-VIEW, NORMAL);
	float specular = pow(max(0.0, dot(reflected_light, view_dir)), 32.0) * specular_intensity;
	
	// Rim lighting effect
	float rim = pow(1.0 - saturate(dot(NORMAL, view_dir)), 2.0) * rim_lighting;
	
	// Calculate foam effect based on wave displacement
	float foam_factor = 0.0;
	if (enable_foam) {
		float foam_mask = smoothstep(foam_threshold, foam_threshold + 0.1, wave_displacement);
		foam_factor = foam_mask * foam_coverage;
	}
	
	// Blend between liquid and foam
	vec3 final_color = mix(base_color.rgb, foam_color.rgb, foam_factor);
	
	// Apply caustics if enabled
	if (enable_caustics) {
		// Simulate caustics with animated noise
		vec2 caustic_uv = UV * caustic_scale + vec2(TIME * caustic_speed * 0.1);
		float caustic_pattern = sin(caustic_uv.x * 10.0 + sin(caustic_uv.y * 7.0)) *
							   cos(caustic_uv.y * 12.0 + sin(caustic_uv.x * 5.0)) * 0.5 + 0.5;
		
		// Apply caustics to the color
		vec3 caustic_color = vec3(1.0, 0.9, 0.7); // Warm caustic color
		final_color += caustic_color * caustic_pattern * caustic_strength * (1.0 - foam_factor);
	}
	
	// Final color and alpha with absorption
	ALBEDO = final_color * (1.0 - absorption_factor * 0.1);
	ALPHA = liquid_color.a * (1.0 - wave_displacement * 0.2);
	
	// Add specular highlights
	ALBEDO += vec3(specular);
	
	// Add rim lighting
	ALBEDO += vec3(rim * 0.3);
	
	// Emission for subtle glow
	EMISSION = final_color * 0.05;
	
	// Metallic for water-like reflections
	METALLIC = 0.2 + foam_factor * 0.3;
	SPECULAR = 0.9;
}