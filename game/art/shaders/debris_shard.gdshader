shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float metallic : hint_range(0,1) = 0.8;
uniform float roughness : hint_range(0,1) = 0.4;

void fragment() {
	ALBEDO = color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
