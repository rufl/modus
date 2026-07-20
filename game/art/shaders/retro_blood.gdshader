shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Retro Blood Shader
// Features: Thick viscous flow, dark clotting areas

group_uniforms BloodColors;
uniform vec4 deep_blood : source_color = vec4(0.3, 0.0, 0.0, 1.0);
uniform vec4 fresh_blood : source_color = vec4(0.8, 0.0, 0.0, 1.0);
uniform vec4 clot_color : source_color = vec4(0.1, 0.0, 0.0, 1.0);

group_uniforms Animation;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.1;
uniform vec2 flow_direction = vec2(0.0, 1.0); // Flows down by default

group_uniforms Appearance;
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.2;

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
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV + flow_direction * TIME * flow_speed;
    
    // Create organic, fleshy noise pattern
    float n1 = fbm(uv * 3.0);
    float n2 = fbm(uv * 6.0 + vec2(n1));
    
    // Mix colors
    vec3 color = mix(deep_blood.rgb, fresh_blood.rgb, n1);
    
    // darker clots/coagulation
    float coagulation = smoothstep(0.4, 0.7, n2);
    color = mix(color, clot_color.rgb, coagulation);
    
    ALBEDO = color;
    ROUGHNESS = roughness_value;
    SPECULAR = specular_intensity;
    // Blood is usually glossy, but this represents a "pool"
}
