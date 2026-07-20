shader_type spatial;
render_mode unshaded, cull_disabled;

// Settings
uniform vec4 albedo : source_color = vec4(0.0, 0.5, 1.0, 0.8);
uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 anim_speed = vec2(0.1, 0.1);

// Wobble
uniform float wobble_amplitude = 0.05;
uniform float wobble_frequency = 2.0;
uniform float wobble_speed = 1.0;

void vertex() {
	// Simple vertex wobble for liquid surface
	float wobble = sin(VERTEX.x * wobble_frequency + TIME * wobble_speed) * 
				   cos(VERTEX.z * wobble_frequency + TIME * wobble_speed);
	VERTEX.y += wobble * wobble_amplitude;
}

void fragment() {
	// Scrolling UVs
	vec2 base_uv = UV * uv_scale;
	base_uv += TIME * anim_speed;
	
	// Sample texture
	vec4 tex_color = texture(texture_albedo, base_uv);
	
	// Combine with color
	ALBEDO = albedo.rgb * tex_color.rgb;
	ALPHA = albedo.a * tex_color.a;
	
	// Optional: Retro "Unlit" look (handled by unshaded render_mode)
}
