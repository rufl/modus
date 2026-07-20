shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

// Atmospheric Volume Shader - Creates realistic atmospheric effects like fog, haze, etc.
// Features: Volumetric fog, atmospheric scattering, density control, color blending

group_uniforms AtmosphereSettings;
uniform float density : hint_range(0.0, 1.0) = 0.1;
uniform float height_falloff : hint_range(0.0, 10.0) = 2.0;
uniform float scattering_coefficient : hint_range(0.0, 5.0) = 1.0;
uniform float absorption_coefficient : hint_range(0.0, 5.0) = 0.5;

group_uniforms ColorSettings;
uniform vec4 atmosphere_color : source_color = vec4(0.7, 0.8, 1.0, 1.0);
uniform float absorption_coefficient : hint_range(0.0, 5.0) = 0.5;

group_uniforms Lighting;
uniform float ambient_light : hint_range(0.0, 5.0) = 1.0;
uniform vec3 light_direction = vec3(0.1, -1.0, -0.2);
uniform vec4 light_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float light_intensity : hint_range(0.0, 10.0) = 3.0;

varying vec3 world_pos;

void vertex() {
	// Pass world position to fragment shader
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Calculate distance from camera for depth-based fog
	float dist = length(world_pos - CAMERA_POSITION);
	
	// Calculate atmospheric density based on height and distance
	float height_factor = exp(-abs(world_pos.y) / height_falloff);
	float fog_factor = density * height_factor * dist;
	
	// Apply exponential fog
	float fog_amount = 1.0 - exp(-fog_factor);
	
	// Calculate lighting contribution
	float NdotL = max(dot(NORMAL, normalize(-light_direction)), 0.0);
	float light_scatter = pow(NdotL, scattering_coefficient);
	
	// Combine lighting with atmospheric color
	vec3 atmosphere_lit = atmosphere_color.rgb * (ambient_light + light_color.rgb * light_intensity * light_scatter);
	
	// Mix original albedo with atmosphere
	ALBEDO = mix(ALBEDO, atmosphere_lit, fog_amount);
	
	// Reduce alpha based on fog amount for transparency effects
	ALPHA = ALPHA * (1.0 - fog_amount * 0.5);
	
	// Apply absorption effect
	ALPHA *= exp(-absorption_coefficient * dist * 0.01);
	
	// Surface properties
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
	METALLIC = 0.0;
	
	// Add slight emission for glowing atmosphere
	EMISSION = atmosphere_color.rgb * fog_amount * 0.2;
}