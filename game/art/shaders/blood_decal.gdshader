shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform vec4 color : source_color = vec4(0.6, 0.0, 0.0, 1.0);
uniform sampler2D noise_tex;

void fragment() {
	// Simple procedural circle/splat
	float dist = distance(UV, vec2(0.5));
	
	// Noise lookup
	// Since we don't have a texture passed in by default, we can use procedural noise or assume a texture
	// If noise_tex is not set, we can stick to simple logic or require it.
	// For fully procedural without texture:
	
	vec2 uv = UV * 4.0;
	vec2 f = fract(uv);
	// Simple hash for noise
	float n = fract(sin(dot(floor(uv), vec2(12.9898, 78.233))) * 43758.5453);
	
	float splat = smoothstep(0.5, 0.3, dist + (n-0.5)*0.4);
	
	ALBEDO = color.rgb * (0.5 + n * 0.5);
	ALPHA = splat * color.a * 0.9;
	ROUGHNESS = 0.2;
}
