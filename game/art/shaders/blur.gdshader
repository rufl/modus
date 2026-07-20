shader_type canvas_item;

// MODUS Framework - Original blur implementation
// Uses gaussian approximation via mipmap LOD sampling

uniform float blur_strength: hint_range(0.0, 8.0) = 2.5;
uniform float overlay_blend: hint_range(0.0, 1.0) = 0.0;
uniform vec4 overlay_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D screen_tex: hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Sample at mipmap level based on blur strength for fast gaussian approximation
	vec4 blurred = textureLod(screen_tex, SCREEN_UV, blur_strength);
	
	// Blend with overlay color for fade-to-black/color effects
	vec4 result = mix(blurred, overlay_color, overlay_blend);
	result.a = 1.0;
	
	COLOR = result;
}
