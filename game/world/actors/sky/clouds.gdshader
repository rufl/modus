shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;

varying vec2 tex_position;

void vertex() {
	// Map sphere coordinates to UV
	tex_position = VERTEX.xz * 0.001; // Scale down
}

void fragment() {
	vec2 offset = vec2(TIME * speed * 0.01, TIME * speed * 0.005);
	vec2 uv = tex_position + offset;
	
	// Sample noise
	float noise = texture(noise_texture, uv).r;
	float noise2 = texture(noise_texture, uv * 2.0 + offset).r;
	
	float final_noise = (noise + noise2 * 0.5) / 1.5;
	
	// Cutoff based on density
	float alpha = smoothstep(1.0 - density, (1.0 - density) + 0.2, final_noise);
	
	ALBEDO = cloud_color.rgb;
	ALPHA = alpha * cloud_color.a;
}
