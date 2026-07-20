shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec4 albedo : source_color = vec4(0.4, 0.6, 1.0, 0.3);
uniform float wire_width : hint_range(0.0, 40.0) = 1.0;
uniform float wire_smoothness : hint_range(0.0, 0.1) = 0.01;

varying vec3 barycentric;

void vertex() {
	// Barycentric coordinates are not automatically available in Godot spatial shaders
	// without using a geometry shader or passing them as custom data.
	// For a simple ghost effect, we will rely on Fresnel and Rim.
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	
	// Ghostly Fresnel pulse
	float f = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), 3.0);
	float pulse = (sin(TIME * 2.0) * 0.5 + 0.5) * 0.5 + 0.5;
	
	ALPHA = clamp(f * pulse * albedo.a * 2.0, 0.0, 1.0);
	
	// Add grid/wireframe-like texture appearance if texture provided
	// For now, just the ghostly rim is sufficient for "Spectator/Editor" look.
}
