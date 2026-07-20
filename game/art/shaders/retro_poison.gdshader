shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Retro Poison/Acid Shader
// Features: Scrolling, bubbling, toxic glow

group_uniforms PoisonColors;
uniform vec4 deep_color : source_color = vec4(0.1, 0.4, 0.0, 1.0);
uniform vec4 surface_color : source_color = vec4(0.2, 0.8, 0.1, 1.0);
uniform vec4 bubble_color : source_color = vec4(0.6, 1.0, 0.4, 1.0);

group_uniforms Animation;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.2;
uniform vec2 flow_direction = vec2(0.5, 0.2);
uniform float bubble_speed : hint_range(0.0, 5.0) = 1.0;
uniform float bubble_density : hint_range(0.0, 20.0) = 8.0;

group_uniforms Appearance;
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.05;

// Simple noise function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    // Flowing UVs
    vec2 flow_uv = UV + flow_direction * TIME * flow_speed;
    
    // Distortion
    float dist = fbm(flow_uv * 3.0);
    vec2 distorted_uv = flow_uv + vec2(dist * distortion_strength);
    
    // Base liquid pattern
    float pattern = fbm(distorted_uv * 4.0);
    
    // Bubbles
    vec2 bubble_uv = UV * bubble_density;
    // Quantize bubble centers for retro feel
    vec2 grid_id = floor(bubble_uv);
    vec2 grid_uv = fract(bubble_uv) - 0.5;
    
    // Randomize bubble timing per cell
    float cell_rand = hash(grid_id);
    float bubble_anim = fract(TIME * bubble_speed * 0.5 + cell_rand * 10.0);
    
    // Bubble shape (growing rings)
    float d = length(grid_uv);
    float bubble_mask = smoothstep(0.4 * bubble_anim, 0.3 * bubble_anim, d);
    // Only show some bubbles
    bubble_mask *= step(0.7, cell_rand);
    
    // Color mixing
    vec3 color = mix(deep_color.rgb, surface_color.rgb, pattern);
    color = mix(color, bubble_color.rgb, bubble_mask);
    
    ALBEDO = color;
    EMISSION = color * glow_intensity;
    ALPHA = 1.0;
}
