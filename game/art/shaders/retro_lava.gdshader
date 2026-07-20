shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Retro Lava Shader - Classic Quake style lava
// Features: Scrolling texture, glow, bubble effect

group_uniforms LavaColors;
uniform vec4 hot_color : source_color = vec4(1.0, 0.6, 0.0, 1.0);
uniform vec4 cool_color : source_color = vec4(0.8, 0.2, 0.0, 1.0);
uniform vec4 crust_color : source_color = vec4(0.2, 0.05, 0.0, 1.0);

group_uniforms Animation;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.3;
uniform vec2 scroll_direction = vec2(1.0, 0.3);
uniform float bubble_speed : hint_range(0.0, 5.0) = 1.5;
uniform float bubble_scale : hint_range(0.1, 5.0) = 2.0;

group_uniforms Appearance;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float crust_amount : hint_range(0.0, 1.0) = 0.3;
uniform float distortion : hint_range(0.0, 0.5) = 0.1;

group_uniforms Textures;
uniform sampler2D noise_texture : hint_default_black;


float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}


float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}


void fragment() {
    // Scrolling UVs
    vec2 scroll_uv = UV + scroll_direction * TIME * scroll_speed;
    
    // Get noise for distortion
    float dist_noise = fbm(scroll_uv * 3.0 + TIME * 0.5);
    vec2 distorted_uv = scroll_uv + vec2(dist_noise * distortion);
    
    // Base lava pattern using FBM noise
    float lava_pattern = fbm(distorted_uv * 4.0);
    
    // Bubble effect - rising spots
    vec2 bubble_uv = UV * bubble_scale;
    bubble_uv.y -= TIME * bubble_speed;
    float bubbles = fbm(bubble_uv * 5.0);
    bubbles = smoothstep(0.5, 0.7, bubbles);
    
    // Mix colors based on pattern
    vec3 base_color = mix(cool_color.rgb, hot_color.rgb, lava_pattern);
    
    // Add crust (darker cooling areas)
    float crust_pattern = fbm(distorted_uv * 8.0 - TIME * 0.1);
    crust_pattern = smoothstep(1.0 - crust_amount, 1.0, crust_pattern);
    base_color = mix(base_color, crust_color.rgb, crust_pattern);
    
    // Add bubble highlights
    base_color += hot_color.rgb * bubbles * 0.5;
    
    ALBEDO = base_color;
    EMISSION = base_color * glow_intensity;
    ALPHA = 1.0;
}
