shader_type canvas_item;

// Active effects flags (controlled via uniforms in material)
uniform bool is_poisoned = false;
uniform bool is_burning = false;
uniform bool is_drowning = false;
uniform bool is_bleeding = false;

// Effect Intensities
uniform float poison_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float burn_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float drowning_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float bleed_intensity : hint_range(0.0, 1.0) = 0.0;

// Noise for distortion (optional, or procedural)
// Noise for distortion (optional, or procedural)
uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform sampler2D screen_texture : hint_screen_texture, repeat_enable, filter_linear;

void fragment() {
    vec2 uv = SCREEN_UV; // Use SCREEN_UV for screen texture sampling
    vec2 distorted_uv = uv;
    float time = TIME;
    
    // --- DISTORTIONS ---
    
    // Poison Wobble
    if (is_poisoned) {
        float wobble_x = sin(uv.y * 10.0 + time * 3.0) * 0.01 * poison_intensity;
        float wobble_y = cos(uv.x * 10.0 + time * 2.5) * 0.01 * poison_intensity;
        distorted_uv += vec2(wobble_x, wobble_y);
    }
    
    // Heat Haze (Burning)
    if (is_burning) {
        float haze = sin(uv.y * 50.0 - time * 10.0) * 0.005 * burn_intensity;
        distorted_uv.x += haze;
    }
    
    // Underwater Warp (Drowning)
    if (is_drowning) {
        vec2 warp_offset = texture(noise_texture, uv + vec2(time * 0.1, time * 0.05)).rg - 0.5;
        distorted_uv += warp_offset * 0.05 * drowning_intensity;
    }
    
    // Sample screen texture with distortion
    vec4 screen_color = texture(screen_texture, distorted_uv);
    vec3 out_color = screen_color.rgb;
    
    // --- COLOR CORRECTION & VIGNETTES ---
    
    vec2 uv_center = distorted_uv - 0.5;
    float dist = length(uv_center);
    
    // Poison: Green Tint + Vignette
    if (is_poisoned) {
        float vig = smoothstep(0.3, 0.8, dist);
        out_color = mix(out_color, vec3(0.1, 0.8, 0.2), vig * 0.6 * poison_intensity);
        out_color.g += 0.1 * poison_intensity;
    }
    
    // Fire: Orange Tint + Bottom Glow
    if (is_burning) {
        float vig = smoothstep(0.3, 0.9, dist);
        // Add pulsating red/orange glow
        float pulse = (sin(time * 8.0) * 0.5 + 0.5) * 0.2;
        vec3 fire_color = vec3(1.0, 0.4, 0.0);
        out_color = mix(out_color, fire_color, vig * 0.5 * burn_intensity + pulse);
    }
    
    // Drowning: Blue Tint + Dark Vignette
    if (is_drowning) {
        out_color = mix(out_color, vec3(0.0, 0.2, 0.6), 0.4 * drowning_intensity);
        float vig = smoothstep(0.4, 1.0, dist);
        out_color *= (1.0 - vig * 0.6 * drowning_intensity); // Darken edges
    }
    
    // Bleeding: Red Vignette Pulse
    if (is_bleeding) {
        float pulse_speed = 4.0; // Heartbeat speed
        float pulse = (sin(time * pulse_speed) * 0.5 + 0.5); // 0..1
        float vig_radius = mix(0.3, 0.6, pulse);
        float vig = smoothstep(vig_radius, 0.9, dist);
        
        vec3 blood_color = vec3(0.8, 0.0, 0.0);
        out_color = mix(out_color, blood_color, vig * 0.8 * bleed_intensity);
    }
    
    COLOR = vec4(out_color, screen_color.a);
}
