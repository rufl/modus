shader_type spatial;

const int TOTAL_BLOOD_DROPS = 64;
const float BLOOD_ROUGHNESS = 0.2;
const float HEIGHTMAP_STRENGTH = 0.2;
const float BLOOD_DENSITY_STRENGTH = 1.5;
const float BLOOD_BLENDING = 0.1;

group_uniforms SetupTheseVariables;
uniform sampler2D floor_texture : hint_default_white;
uniform sampler2D floor_heightmap : hint_default_black;
uniform sampler2D floor_roughnessmap : hint_default_white;
uniform sampler2D blood_texture : repeat_disable;
uniform vec3 blood_color : source_color = vec3(0.5, 0.0, 0.0);
uniform float blood_merge_factor : hint_range(0.0, 1.0) = 0.25;
uniform bool blood_density_on_heightmap = true;
group_uniforms;

group_uniforms ExternallySetted;
uniform vec2 positions[TOTAL_BLOOD_DROPS];
uniform float scales[TOTAL_BLOOD_DROPS];
group_uniforms;

vec2 scale_from_center(vec2 uv, float s) {
	return ((uv - 0.5) * 1.0 / max(s, 0.001)) + 0.5;
}

void fragment() {
	vec3 base_albedo = texture(floor_texture, UV).rgb;
	float base_roughness = texture(floor_roughnessmap, UV).x;

	ALBEDO = base_albedo;
	ROUGHNESS = base_roughness;
	METALLIC = 0.0;

	float blended_pixel = 1.0;
	bool is_blood = false;

	for (int i = 0; i < TOTAL_BLOOD_DROPS; i++) {
		if (scales[i] <= 0.01) continue;
		
		vec2 uv_translated = UV - positions[i] + 0.5;
		vec2 uv_scaled = scale_from_center(uv_translated, scales[i]);
		
		float drop_sample = 1.0;
		if (uv_scaled.x >= 0.0 && uv_scaled.x <= 1.0 && uv_scaled.y >= 0.0 && uv_scaled.y <= 1.0) {
			drop_sample = texture(blood_texture, uv_scaled).r;
		}
		
		blended_pixel *= drop_sample;
		if (drop_sample < 0.5) is_blood = true;
	}

	if (is_blood && blended_pixel < blood_merge_factor) {
		ROUGHNESS = BLOOD_ROUGHNESS;
		SPECULAR = 0.0;
		ALBEDO = mix(blood_color, base_albedo, BLOOD_BLENDING);

		if (blood_density_on_heightmap) {
			float h = texture(floor_heightmap, UV).r;
			ALBEDO *= mix(0.4, 1.0, h) * BLOOD_DENSITY_STRENGTH;
		}
	}
}

void vertex() {
	VERTEX.y = texture(floor_heightmap, UV).x * HEIGHTMAP_STRENGTH;
}
