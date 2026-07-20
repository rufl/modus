shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley;

// Retro Water Shader - Quake/Half-Life style water effect
// Features: Animated waves, distortion, transparency, edge foam

group_uniforms WaterColors;
uniform vec4 shallow_color : source_color = vec4(0.15, 0.5, 0.65, 0.7);
uniform vec4 deep_color : source_color = vec4(0.05, 0.2, 0.35, 0.85);
uniform float color_depth_factor : hint_range(0.0, 5.0) = 1.0;

group_uniforms WaveAnimation;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wave_scale : hint_range(0.01, 2.0) = 0.3;
uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.1;
uniform vec2 wave_direction = vec2(1.0, 0.5);

group_uniforms Distortion;
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.05;
uniform sampler2D distortion_noise : hint_default_black;
uniform float noise_scale : hint_range(0.01, 10.0) = 2.0;

group_uniforms Fresnel;
uniform float fresnel_power : hint_range(0.0, 10.0) = 3.0;
uniform float fresnel_opacity : hint_range(0.0, 1.0) = 0.5;

group_uniforms Foam;
uniform bool foam_enabled = true;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float foam_softness : hint_range(0.0, 1.0) = 0.1;

varying float wave_height;


void vertex() {
    // Calculate wave offset using defined uniforms
    vec2 wave_uv = UV * wave_scale + wave_direction * TIME * wave_speed;
    float wave1 = sin(wave_uv.x * 6.283 + TIME * wave_speed) * 0.5 + 0.5;
    float wave2 = sin(wave_uv.y * 6.283 + TIME * wave_speed * 1.3) * 0.5 + 0.5;
    
    wave_height = (wave1 + wave2) * 0.5 * wave_amplitude;
    VERTEX.y += wave_height;
    
    // Update normal for wave direction
    vec3 wave_tangent = vec3(1.0, cos(wave_uv.x * 6.283 + TIME * wave_speed) * wave_amplitude, 0.0);
    vec3 wave_bitangent = vec3(0.0, cos(wave_uv.y * 6.283 + TIME * wave_speed * 1.3) * wave_amplitude, 1.0);
    NORMAL = normalize(cross(wave_tangent, wave_bitangent));
}


void fragment() {
    // Sample noise for distortion
    vec2 noise_uv = UV * noise_scale + vec2(TIME * wave_speed * 0.1);
    vec2 noise_sample = texture(distortion_noise, noise_uv).rg * 2.0 - 1.0;
    vec2 distorted_uv = UV + noise_sample * distortion_strength;
    
    // Fresnel effect for edge transparency
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
    fresnel = mix(1.0 - fresnel_opacity, 1.0, fresnel);
    
    // Color based on depth simulation (using wave height as proxy)
    vec4 water_color = mix(shallow_color, deep_color, wave_height * color_depth_factor);
    
    // Apply fresnel to alpha
    float alpha = water_color.a * fresnel;
    
    // Foam at wave peaks (retro style - simple threshold)
    if (foam_enabled) {
        float foam_factor = smoothstep(foam_threshold - foam_softness, foam_threshold + foam_softness, wave_height);
        water_color.rgb = mix(water_color.rgb, foam_color.rgb, foam_factor * foam_color.a);
    }
    
    ALBEDO = water_color.rgb;
    ALPHA = alpha;
    
    // Slight emission for glow effect
    EMISSION = water_color.rgb * 0.1;
    
    // Surface properties
    ROUGHNESS = 0.2;
    SPECULAR = 0.8;
    METALLIC = 0.0;
}
