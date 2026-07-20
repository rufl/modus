shader_type particles;

uniform float vortex_str : hint_range(0, 40) = 25.0;
uniform float initial_velocity_min = 15.0;
uniform float initial_velocity_max = 20.0;

float rand_from_seed(inout uint seed) {
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

float rand_from_seed_m1_p1(inout uint seed) {
	return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = (x >> 16u) ^ x;
	return x;
}

void start() {
	uint seed = hash(uint(INDEX) + uint(TIME * 100.0));
	VELOCITY = normalize(VELOCITY) * (initial_velocity_min + rand_from_seed(seed) * (initial_velocity_max - initial_velocity_min));
}

void process() {
	// Simple vortex effect
	float t = TIME * vortex_str;
	// We can't easily rotate velocity here without more state, but we can add spiral motion
	// Assuming Z is forward(-ish) for trail
	
	// Add some noise to velocity
	uint seed = hash(uint(INDEX) + uint(TIME * 100.0));
	float n = rand_from_seed_m1_p1(seed); 
	
	// Vortex logic approximation
	// Rotate X/Y around Z (if Z is trailing)
	// For simple chaos:
	vec3 tangential = cross(normalize(VELOCITY), vec3(0,1,0));
	if (length(tangential) < 0.1) tangential = cross(normalize(VELOCITY), vec3(1,0,0));
	
	VELOCITY += tangential * (n * 0.5) * DELTA * vortex_str;
}
