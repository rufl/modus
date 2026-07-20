shader_type canvas_item;

// Settings
uniform bool enable_crt = true;
uniform float scanline_intensity = 0.5;
uniform float scanline_count = 320.0;

uniform bool enable_dither = true;
uniform float dither_scale = 4.0; // Higher = blockier dither

uniform float vignette_intensity = 0.4;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	
	// 1. Scanlines
	if (enable_crt) {
		float scanline = sin(UV.y * scanline_count * 3.14159 * 2.0);
		// Remap -1..1 to 1-intensity..1
		float lines = 1.0 - (scanline_intensity * (1.0 - (scanline * 0.5 + 0.5)));
		color.rgb *= lines;
	}
	
	// 2. Vignette
	vec2 center_dist = UV - 0.5;
	float dist_sq = dot(center_dist, center_dist);
	float vignette = 1.0 - dist_sq * vignette_intensity * 2.0;
	color.rgb *= vignette;
	
	// 3. Dithering (Ordered)
	if (enable_dither) {
		// Simple ordered dithering matrix (4x4)
		int x = int(FRAGCOORD.x / dither_scale) % 4;
		int y = int(FRAGCOORD.y / dither_scale) % 4;
		
		// Bayer Matrix 4x4
		// 0  8  2 10
		// 12 4 14 6
		// 3 11 1 9
		// 15 7 13 5
		float dither_threshold = 0.0;
		if (y == 0) {
			if (x == 0) dither_threshold = 0.0/16.0;
			if (x == 1) dither_threshold = 8.0/16.0;
			if (x == 2) dither_threshold = 2.0/16.0;
			if (x == 3) dither_threshold = 10.0/16.0;
		} else if (y == 1) {
			if (x == 0) dither_threshold = 12.0/16.0;
			if (x == 1) dither_threshold = 4.0/16.0;
			if (x == 2) dither_threshold = 14.0/16.0;
			if (x == 3) dither_threshold = 6.0/16.0;
		} else if (y == 2) {
			if (x == 0) dither_threshold = 3.0/16.0;
			if (x == 1) dither_threshold = 11.0/16.0;
			if (x == 2) dither_threshold = 1.0/16.0;
			if (x == 3) dither_threshold = 9.0/16.0;
		} else {
			if (x == 0) dither_threshold = 15.0/16.0;
			if (x == 1) dither_threshold = 7.0/16.0;
			if (x == 2) dither_threshold = 13.0/16.0;
			if (x == 3) dither_threshold = 5.0/16.0;
		}
		
		// Color quantization + dither
		float quant_levels = 8.0;
		color.rgb += dither_threshold * (1.0/quant_levels);
		color.rgb = floor(color.rgb * quant_levels) / quant_levels;
	}
	
	COLOR = color;
}
