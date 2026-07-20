shader_type spatial;

const int TOTAL_BLOOD_DROPS = 64;
const float BLOOD_ROUGHNESS = 0.9;  // More rough for retro look
const float HEIGHTMAP_STRENGHT = 0.2;
const float BLOOD_DENSITY_STRENGHT = 5.0;
const float BLOOD_BLENDING = 0.3;  // More blending for pixelated look

// Retro/pixelation settings
const float PIXEL_SIZE = 8.0;  // Larger = more pixelated
const float COLOR_DEPTH = 8.0;  // Lower = more color banding (Quake-style)

group_uniforms SetupTheseVariables;
uniform sampler2D floor_texture : hint_default_white, filter_nearest;  // Nearest for pixelated
uniform sampler2D floor_heightmap : hint_default_black, filter_nearest;
uniform sampler2D floor_roughnessmap : hint_default_black, filter_nearest;
uniform sampler2D blood_texture : repeat_disable, filter_nearest;  // Nearest for pixelated
uniform vec3 blood_color : source_color = vec3(0.4, 0.0, 0.0);  // Darker for retro
uniform float blood_merge_factor : hint_range(0.0, 1.0) = 0.2;
uniform bool blood_density_on_heightmap = true;
uniform bool enable_pixelation = true;
uniform float pixelation_amount : hint_range(1.0, 32.0) = 8.0;
uniform bool enable_color_banding = true;
uniform float color_bands : hint_range(2.0, 32.0) = 8.0;
group_uniforms;

group_uniforms ExternallySetted;
uniform vec2 positions[TOTAL_BLOOD_DROPS];
uniform float scales[TOTAL_BLOOD_DROPS];
group_uniforms;

vec2 scale_from_center(vec2 uv, float s) {
	return ((uv - 0.5) * 1.0 / s) + 0.5;
}

// Pixelation function
vec2 pixelate_uv(vec2 uv, float pixel_size) {
	if (!enable_pixelation) {
		return uv;
	}
	vec2 pixels = vec2(pixel_size, pixel_size);
	return floor(uv * pixels) / pixels;
}

// Color banding function (Quake-style color reduction)
vec3 apply_color_banding(vec3 color, float bands) {
	if (!enable_color_banding) {
		return color;
	}
	return floor(color * bands) / bands;
}

void fragment() {
	// Pixelate UVs for retro look
	vec2 pixelated_uv = pixelate_uv(UV, pixelation_amount);

	// Draw base PBR properties with pixelation
	ALBEDO = texture(floor_texture, pixelated_uv).rgb;
	ROUGHNESS = texture(floor_roughnessmap, pixelated_uv).x;

	// Increase roughness for retro look
	ROUGHNESS = max(ROUGHNESS, BLOOD_ROUGHNESS);

	float blended_pixel = 1.0;
	bool has_blood = false;

	// Blend every drop of blood first for realistic coalescence
	// Blood texture: 0.0 = blood center, 1.0 = no blood (edges)
	for (int i = 0; i < TOTAL_BLOOD_DROPS; i++) {
		if (scales[i] <= 0.01) {
			continue;
		}
		vec2 uv_translated = pixelated_uv - positions[i] + 0.5;
		vec2 uv_scaled = scale_from_center(uv_translated, scales[i]);
		float blood_sample = texture(blood_texture, uv_scaled).r;
		blended_pixel *= blood_sample;
		
		// Check if this pixel is within any blood drop (low values = blood)
		if (blood_sample < 0.5) {
			has_blood = true;
		}
	}

	// Apply blood properties only where blood exists
	// Lower blended_pixel values = more blood
	if (has_blood && blended_pixel < blood_merge_factor) {
		ROUGHNESS = BLOOD_ROUGHNESS;
		ALBEDO = mix(blood_color, ALBEDO, BLOOD_BLENDING);

		if (blood_density_on_heightmap) {
			// Darken blood in crevices
			float height_factor = max(texture(floor_heightmap, pixelated_uv).r, 0.3);
			ALBEDO *= height_factor * BLOOD_DENSITY_STRENGHT;
			ALBEDO = clamp(ALBEDO, vec3(0.0), vec3(1.0));
		}
	}

	// Apply color banding for Quake-style look
	ALBEDO = apply_color_banding(ALBEDO, color_bands);

	// Disable specular for retro look
	SPECULAR = 0.0;
	METALLIC = 0.0;
}

void vertex() {
	VERTEX.y = texture(floor_heightmap, UV).x * HEIGHTMAP_STRENGHT;
}
