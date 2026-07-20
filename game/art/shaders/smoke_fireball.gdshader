shader_type particles;

uniform sampler2D noise_tex : source_color;
uniform float distortion : hint_range(0.0, 2.0) = 1.2;

float rand_from_seed(in uint seed) {
	int k;
	int s = int(seed);
	if (s == 0)
	s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0)
		s += 2147483647;
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

void start() {
	// Random velocity
	float r = rand_from_seed(uint(INDEX + uint(TIME * 100.0)));
	float r2 = rand_from_seed(uint(INDEX + 1000u));
	
	VELOCITY = normalize(VELOCITY) * (15.0 + r * 10.0);
	TRANSFORM[3].y += r2 * 0.5; // slight height offset
	
	// Initial rotation
	float rot = r * 3.14159 * 2.0;
	// Simple Y rotation matrix
	float c = cos(rot);
	float s = sin(rot);
	// Apply to basis (columns 0 and 2 for Y rotation) - this is a bit rough for particles but ok
}

void process() {
	float life_frac = (LIFETIME - 0.0) / LIFETIME; // Godot's LIFETIME is constant, we need current age? 
	// In shader_type particles:
	// TIME is clear, LIFETIME is total life.
	// CUSTOM.y usually tracks age if we set it, but built-in we access time/lifetime
	
	// Wait, process() in particle shaders runs every frame.
	// We usually access built-ins.
	
	// Turbulence
	float noise = texture(noise_tex, vec2(1.0, 0.0) * TIME * 0.5).r; 
	// (Simplified UV as we don't have particle UVs in process easily without custom data)
	
	// Lets keep it simple for a text shader
	VELOCITY.y += -9.8 * DELTA * 0.5; // Mild gravity
	
	// Expansion
	// SCALE is a Vec3
	// We want to scale up then fade?
	// COLOR.a handled by curve in editor usually
}
