shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_lambert_wrap, specular_disabled;

uniform float pixel_size : hint_range(4.0, 32.0) = 12.0;
uniform float anim_speed : hint_range(0.0, 2.0) = 0.1;
uniform vec3 col_dark_meat : source_color = vec3(0.4, 0.15, 0.15);  // #663333 approx Quake brown-red
uniform vec3 col_meat : source_color = vec3(0.7, 0.35, 0.3);      // #B2594D brown
uniform vec3 col_pink : source_color = vec3(0.9, 0.5, 0.5);       // #E08080 pink flesh
uniform vec3 col_blood : source_color = vec3(1.0, 0.4, 0.4);      // #FF6666 bright red
uniform vec3 col_bone : source_color = vec3(0.95, 0.85, 0.75);    // #F1D9C0 light tan
uniform float roughness : hint_range(0.5, 1.0) = 0.85;
uniform float emission_strength : hint_range(0.0, 0.5) = 0.15;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

// Simple hash noise for procedural
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    // Pixelate UV for chunky Q1/Q2 developer art look
    vec2 px_uv = floor(UV * pixel_size) / pixel_size;
    
    // Low-freq chunk noise + subtle animation
    vec2 npos = px_uv * 2.5 + TIME * anim_speed;
    float n_chunk = noise(npos);
    
    // High-freq detail/veins
    vec2 dpos = px_uv * 12.0 + TIME * anim_speed * 1.5;
    float n_detail = noise(dpos);
    
    // Combined value, biased for fleshy tones
    float val = n_chunk * 0.6 + n_detail * 0.4;
    
    // Palette quantize: 5 Quake-inspired meat colors (browns/pinks/reds from palette rows 1,4,7,9)
    vec3 albedo;
    if (val < 0.2) {
        albedo = col_dark_meat;
    } else if (val < 0.4) {
        albedo = mix(col_dark_meat, col_meat, smoothstep(0.2, 0.4, val));
    } else if (val < 0.6) {
        albedo = mix(col_meat, col_pink, smoothstep(0.4, 0.6, val));
    } else if (val < 0.8) {
        albedo = mix(col_pink, col_blood, smoothstep(0.6, 0.8, val));
    } else {
        albedo = mix(col_blood, col_bone, smoothstep(0.8, 1.0, val));
    }
    
    // Dither for extra retro pixelated vibe (optional, low strength)
    float dither = hash(UV * pixel_size + floor(TIME * 60.0)) * 0.1 - 0.05;
    ALBEDO = albedo + dither;
    
    // Simple procedural normal (bump from detail noise)
    float bump = (n_detail - 0.5) * 0.5;
    NORMAL_MAP = vec3(0.0, 0.0, 1.0 + bump);
    
    ROUGHNESS = roughness;
    METALLIC = 0.0;
    ALPHA = alpha;

    // Subtle pulsing blood emission (Q1 fullbright glow vibe)
    float pulse = 0.5 + 0.5 * sin(TIME * 2.0);
    EMISSION = vec3(0.3, 0.1, 0.1) * emission_strength * pulse;
}
