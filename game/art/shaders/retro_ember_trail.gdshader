shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 ember_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 0.4;
uniform float pixel_size : hint_range(1.0, 16.0) = 6.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;

void vertex() {
	// Billboard effect
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// Pixelate UV coordinates for chunky retro look
	vec2 pixelated_uv = floor(UV * (32.0 / pixel_size)) / (32.0 / pixel_size);
	
	// Center distance for circular particles
	vec2 centered = pixelated_uv - vec2(0.5);
	float dist = length(centered);
	
	// Sharp circular mask for pixelated embers
	float circle_mask = step(dist, 0.4);
	
	// Fade out over particle lifetime
	float alpha = circle_mask * alpha_multiplier * COLOR.a;
	
	// Bright glow for embers
	ALBEDO = ember_color.rgb * COLOR.rgb;
	EMISSION = ember_color.rgb * glow_intensity;
	ALPHA = alpha;
}
