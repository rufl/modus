shader_type spatial;

// Dark military camo pattern shader
// Procedural multi-scale noise for realistic camouflage

uniform vec3 base_color : source_color = vec3(0.15, 0.18, 0.12);  // Dark olive
uniform vec3 camo_color_1 : source_color = vec3(0.08, 0.10, 0.06);  // Very dark green
uniform vec3 camo_color_2 : source_color = vec3(0.12, 0.14, 0.10);  // Medium dark
uniform vec3 camo_color_3 : source_color = vec3(0.18, 0.16, 0.12);  // Lighter brown-green

uniform float pattern_scale : hint_range(0.1, 10.0) = 2.0;
uniform float pattern_complexity : hint_range(1.0, 5.0) = 3.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.8;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;

// Noise function for procedural camo
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for multi-scale detail
float fbm(vec2 p, float octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	for (float i = 0.0; i < octaves; i += 1.0) {
		value += amplitude * noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	
	return value;
}

// Voronoi-like cell pattern for organic camo shapes
vec2 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	
	float min_dist = 1.0;
	vec2 min_point = vec2(0.0);
	
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash(i + neighbor) * vec2(1.0) + neighbor;
			float dist = length(point - f);
			
			if (dist < min_dist) {
				min_dist = dist;
				min_point = point;
			}
		}
	}
	
	return vec2(min_dist, hash(i + floor(min_point)));
}

void fragment() {
	// Get UV coordinates (use VERTEX for 3D procedural)
	vec2 uv = UV * pattern_scale;
	
	// Multi-scale noise for camo pattern
	float n1 = fbm(uv * 2.0, pattern_complexity);
	float n2 = fbm(uv * 4.0 + vec2(5.2, 1.3), pattern_complexity);
	float n3 = fbm(uv * 8.0 + vec2(2.8, 7.1), pattern_complexity);
	
	// Voronoi cells for organic shapes
	vec2 vor = voronoi(uv * 1.5);
	float cell_pattern = vor.y;
	
	// Combine patterns
	float pattern = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
	pattern = mix(pattern, cell_pattern, 0.4);
	
	// Sharp edges for camo blobs
	pattern = smoothstep(0.3, 0.7, pattern);
	
	// Select color based on pattern value
	vec3 color;
	if (pattern < 0.25) {
		color = camo_color_1;  // Darkest
	} else if (pattern < 0.5) {
		color = mix(camo_color_1, camo_color_2, (pattern - 0.25) * 4.0);
	} else if (pattern < 0.75) {
		color = mix(camo_color_2, camo_color_3, (pattern - 0.5) * 4.0);
	} else {
		color = mix(camo_color_3, base_color, (pattern - 0.75) * 4.0);
	}
	
	// Add subtle variation to avoid banding
	float variation = noise(uv * 20.0) * 0.02;
	color += vec3(variation);
	
	// Output
	ALBEDO = color;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}
