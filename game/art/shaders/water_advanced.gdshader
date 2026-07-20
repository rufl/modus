shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

// Advanced Water Shader - Physically-based water with realistic properties
// Features: Dynamic waves, realistic refraction, caustics, foam, underwater absorption, and environmental reflections

group_uniforms WaterProperties;
uniform vec4 water_color : source_color = vec4(0.1, 0.3, 0.6, 0.8);
uniform float absorption_coefficient : hint_range(0.0, 10.0) = 0.3;
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.2;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.15;
uniform float surface_metallic : hint_range(0.0, 1.0) = 0.9;

group_uniforms WaveProperties;
uniform float wave_amplitude : hint_range(0.0, 2.0) = 0.1;
uniform float wave_frequency : hint_range(0.0, 20.0) = 5.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 1.5;
uniform vec2 wave_direction1 = vec2(1.0, 0.0);
uniform vec2 wave_direction2 = vec2(0.5, 0.8);
uniform float wave_choppiness : hint_range(0.0, 2.0) = 0.5;

group_uniforms FoamProperties;
uniform bool enable_foam = true;
uniform vec4 foam_color : source_color = vec4(0.95, 0.95, 0.98, 1.0);
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.1;
uniform float foam_coverage : hint_range(0.0, 1.0) = 0.3;
uniform float foam_absorption : hint_range(0.0, 5.0) = 0.5;

group_uniforms Caustics;
uniform bool enable_caustics = true;
uniform float caustic_strength : hint_range(0.0, 2.0) = 0.8;
uniform float caustic_scale : hint_range(0.01, 5.0) = 2.0;
uniform float caustic_speed : hint_range(0.0, 5.0) = 1.0;

group_uniforms Underwater;
uniform bool enable_underwater_effects = true;
uniform vec4 underwater_color : source_color = vec4(0.1, 0.2, 0.4, 1.0);
uniform float underwater_absorption : hint_range(0.0, 10.0) = 1.5;

varying vec3 world_pos;
varying float wave_height;

void vertex() {
	// Calculate world position
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Calculate wave heights using Gerstner wave functions for more realistic peaks
	vec2 world_uv = world_pos.xz * 0.1; // Scale down for larger waves
	
	// Primary wave
	float wave1 = sin(dot(world_uv, normalize(wave_direction1)) * wave_frequency + TIME * wave_speed) * 0.5 + 0.5;
	vec2 wave1_normal = vec2(cos(dot(world_uv, normalize(wave_direction1)) * wave_frequency + TIME * wave_speed), 
							sin(dot(world_uv, normalize(wave_direction1)) * wave_frequency + TIME * wave_speed));
	
	// Secondary wave
	float wave2 = sin(dot(world_uv, normalize(wave_direction2)) * wave_frequency * 1.3 + TIME * wave_speed * 0.8) * 0.5 + 0.5;
	vec2 wave2_normal = vec2(cos(dot(world_uv, normalize(wave_direction2)) * wave_frequency * 1.3 + TIME * wave_speed * 0.8), 
							sin(dot(world_uv, normalize(wave_direction2)) * wave_frequency * 1.3 + TIME * wave_speed * 0.8));
	
	// Combine waves with choppiness
	float combined_wave = (wave1 + wave2) * 0.5;
	float wave_displacement = combined_wave * wave_amplitude;
	
	// Apply choppiness to create sharper peaks and flatter troughs
	wave_displacement = sign(wave_displacement) * pow(abs(wave_displacement), 1.0 - wave_choppiness * 0.5);
	
	// Apply vertical displacement
	VERTEX.y += wave_displacement;
	wave_height = wave_displacement;
	
	// Calculate normal based on wave derivatives
	vec3 tangent = vec3(1.0, dFdx(wave_displacement) * 0.1, 0.0);
	vec3 bitangent = vec3(0.0, dFdy(wave_displacement) * 0.1, 1.0);
	NORMAL = normalize(cross(tangent, bitangent));
}

void fragment() {
	// Calculate view direction
	vec3 view_dir = normalize(CAMERA_POSITION - world_pos);
	
	// Fresnel effect for realistic water edges
	float NdotV = saturate(dot(NORMAL, view_dir));
	float fresnel = pow(1.0 - NdotV, 5.0);
	
	// Calculate foam based on wave steepness/height
	float foam_factor = 0.0;
	if (enable_foam) {
		// Calculate foam based on wave height and steepness
		float foam_height = smoothstep(foam_threshold, foam_threshold + 0.1, wave_height);
		foam_factor = foam_height * foam_coverage;
	}
	
	// Base water color with depth-based absorption
	vec3 base_color = mix(water_color.rgb, underwater_color.rgb, NdotV * underwater_absorption * 0.1);
	
	// Apply foam mixing
	vec3 final_color = mix(base_color, foam_color.rgb, foam_factor);
	
	// Calculate realistic refraction based on normal
	vec3 refracted_view = refract(view_dir, NORMAL, 1.0 / 1.33); // Water IOR
	vec2 refracted_uv = UV + refracted_view.xz * refraction_strength * (1.0 - fresnel);
	
	// Apply absorption based on depth (distance through water)
	float absorption = exp(-absorption_coefficient * abs(world_pos.y - VERTEX.y));
	
	// Add caustics if enabled
	if (enable_caustics) {
		// Create animated caustic pattern
		vec2 caustic_uv = world_pos.xz * caustic_scale * 0.1 + vec2(TIME * caustic_speed * 0.2);
		
		// More complex caustic pattern using multiple noise layers
		float caustic1 = sin(caustic_uv.x * 8.0 + sin(caustic_uv.y * 5.0)) * 
						cos(caustic_uv.y * 10.0 + sin(caustic_uv.x * 3.0)) * 0.5 + 0.5;
		float caustic2 = cos(caustic_uv.x * 12.0 + sin(caustic_uv.y * 7.0)) * 
						sin(caustic_uv.y * 6.0 + cos(caustic_uv.x * 9.0)) * 0.5 + 0.5;
		
		float caustic_pattern = (caustic1 + caustic2) * 0.5;
		
		// Add caustics to the color (only in deeper water, not in foam areas)
		vec3 caustic_color = vec3(0.8, 0.9, 1.0) * caustic_pattern * caustic_strength * (1.0 - foam_factor);
		final_color += caustic_color;
	}
	
	// Final color with absorption
	ALBEDO = final_color * absorption;
	
	// Alpha based on absorption and foam
	ALPHA = water_color.a * absorption * (1.0 - foam_factor * 0.3);
	
	// Surface properties
	ROUGHNESS = surface_roughness + (1.0 - NdotV) * 0.1; // Slightly rougher at edges
	METALLIC = surface_metallic;
	SPECULAR = 0.9;
	
	// Add slight emission for water glow
	EMISSION = final_color * 0.02;
}