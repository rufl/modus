shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// GTA V-style first-person body shader
// Fades out body parts that are too close to the camera to prevent clipping

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// First-person transparency settings
uniform bool enable_fp_transparency = true;
uniform float fade_start_distance = 0.4; // Start fading at 40cm from camera
uniform float fade_end_distance = 0.1;   // Fully transparent at 10cm from camera
uniform vec3 camera_position;             // Set by script each frame

void vertex() {
	// Pass world position to fragment shader
	// We'll calculate distance to camera there
}

void fragment() {
	// Sample albedo texture
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	
	// Calculate distance from fragment to camera
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist_to_camera = distance(world_pos, camera_position);
	
	// Apply first-person transparency fade
	if (enable_fp_transparency) {
		// Smoothstep fade between fade_end and fade_start
		float fade = smoothstep(fade_end_distance, fade_start_distance, dist_to_camera);
		ALPHA = albedo_tex.a * fade;
		
		// If too close, discard fragment entirely for better performance
		if (dist_to_camera < fade_end_distance * 0.8) {
			discard;
		}
	} else {
		ALPHA = albedo_tex.a;
	}
	
	// PBR properties
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
