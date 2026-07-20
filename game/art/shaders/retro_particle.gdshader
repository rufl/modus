shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Retro Pixelated Particle Shader
// Makes particles look chunky and low-res like classic games

uniform vec4 base_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform bool use_dither = true;

void fragment() {
	// Pixelate UV coordinates
	vec2 pixelated_uv = floor(UV * pixel_size) / pixel_size;
	
	// Simple circular shape with hard edges
	vec2 center = pixelated_uv - 0.5;
	float dist = length(center) * 2.0;
	
	// Hard pixel edge (no antialiasing)
	float alpha = step(dist, 0.9);
	
	// Optional dithering for semi-transparency
	if (use_dither && base_color.a < 1.0) {
		int x = int(mod(FRAGCOORD.x, 2.0));
		int y = int(mod(FRAGCOORD.y, 2.0));
		float dither = float((x + y) % 2);
		alpha *= step(dither, base_color.a * 2.0);
	}
	
	if (alpha < 0.5) {
		discard;
	}
	
	ALBEDO = base_color.rgb;
	ALPHA = alpha;
}
