shader_type sky;

// Simple retro-style sky shader
// Placeholder - can be enhanced later

uniform vec4 sky_top_color : source_color = vec4(0.1, 0.3, 0.6, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.4, 0.5, 0.7, 1.0);
uniform vec4 sky_bottom_color : source_color = vec4(0.1, 0.1, 0.2, 1.0);
uniform float horizon_sharpness : hint_range(0.0, 10.0) = 2.0;

void sky() {
	// Get the vertical position (-1 to 1, where 1 is up)
	float y = EYEDIR.y;
	
	// Create gradient from bottom to top
	vec3 color;
	
	if (y > 0.0) {
		// Above horizon: blend from horizon to top
		color = mix(sky_horizon_color.rgb, sky_top_color.rgb, pow(y, horizon_sharpness));
	} else {
		// Below horizon: blend from horizon to bottom
		color = mix(sky_horizon_color.rgb, sky_bottom_color.rgb, pow(-y, horizon_sharpness));
	}
	
	COLOR = color;
}
