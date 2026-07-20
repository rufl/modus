shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D noise_texture : filter_nearest, repeat_enable;
uniform vec4 smoke_color : source_color = vec4(0.6, 0.6, 0.65, 1.0);
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 0.25;
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform float noise_scale : hint_range(0.1, 5.0) = 2.0;
uniform float time_scale : hint_range(0.0, 2.0) = 0.5;

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
	// Pixelate UV coordinates for retro look
	vec2 pixelated_uv = floor(UV * (64.0 / pixel_size)) / (64.0 / pixel_size);
	
	// Center distance for circular fade
	vec2 centered = pixelated_uv - vec2(0.5);
	float dist = length(centered);
	
	// Circular mask with soft edge
	float circle_mask = 1.0 - smoothstep(0.3, 0.5, dist);
	
	// Animated noise for smoke turbulence
	vec2 noise_uv = pixelated_uv * noise_scale + vec2(TIME * time_scale, 0.0);
	float noise = texture(noise_texture, noise_uv).r;
	
	// Combine noise with circle mask
	float alpha = circle_mask * noise * alpha_multiplier;
	
	// Fade out over particle lifetime (using COLOR.a from particle system)
	alpha *= COLOR.a;
	
	// Output with very low alpha for transparency
	ALBEDO = smoke_color.rgb * COLOR.rgb;
	ALPHA = alpha;
}
