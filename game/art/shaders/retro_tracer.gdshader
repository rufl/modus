shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

// Retro Bullet Tracer Shader
// Creates a chunky, pixelated tracer with bright core and fading tail

uniform vec4 core_color : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.1, 0.5);
uniform float core_width : hint_range(0.1, 1.0) = 0.4;
uniform float pixel_steps : hint_range(2.0, 16.0) = 4.0;
uniform float fade_power : hint_range(0.5, 4.0) = 2.0;
uniform float time_offset : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Pixelate UVs for retro look
	vec2 pix_uv = floor(UV * pixel_steps) / pixel_steps;
	
	// Distance from center line (Y axis in UV space)
	float dist_from_center = abs(pix_uv.y - 0.5) * 2.0;
	
	// Core intensity - bright center, fading edges
	float core = 1.0 - smoothstep(0.0, core_width, dist_from_center);
	core = floor(core * 4.0) / 4.0; // Quantize for retro look
	
	// Edge glow
	float edge = 1.0 - smoothstep(core_width, 1.0, dist_from_center);
	edge = floor(edge * 3.0) / 3.0;
	
	// Fade along length (tail effect) - stronger fade at back
	float length_fade = pow(pix_uv.x, fade_power);
	length_fade = floor(length_fade * 4.0) / 4.0;
	
	// Combine colors
	vec3 color = mix(edge_color.rgb, core_color.rgb, core);
	float alpha = max(core, edge * 0.5) * length_fade;
	
	// Hard pixel cutoff
	if (alpha < 0.1) {
		discard;
	}
	
	ALBEDO = color;
	ALPHA = alpha;
	EMISSION = color * alpha * 2.0;
}
