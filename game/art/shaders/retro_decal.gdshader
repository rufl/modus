shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// Retro Pixelated Decal Shader
// For blood drips, bullet holes, scorch marks etc.

uniform vec4 base_color : source_color = vec4(0.5, 0.0, 0.0, 1.0);
uniform float pixel_size : hint_range(2.0, 16.0) = 8.0;
uniform float edge_hardness : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	// Pixelate UV
	vec2 pix_uv = floor(UV * pixel_size) / pixel_size;
	
	// Create chunky circular splat
	vec2 center = pix_uv - 0.5;
	float dist = length(center) * 2.0;
	
	// Hard pixelated edge
	float alpha = 1.0 - smoothstep(edge_hardness, 1.0, dist);
	alpha = floor(alpha * 4.0) / 4.0; // Quantize alpha
	
	if (alpha < 0.1) {
		discard;
	}
	
	// Slight color variation based on position
	vec3 color = base_color.rgb;
	float variation = floor(pix_uv.x * 4.0 + pix_uv.y * 4.0);
	color *= 0.9 + mod(variation, 3.0) * 0.05;
	
	ALBEDO = color;
	ALPHA = alpha * base_color.a;
}
