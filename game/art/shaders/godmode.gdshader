shader_type spatial;

uniform vec3 albedo_color : source_color = vec3(1.0, 0.84, 0.0); // Gold
uniform float emission_energy : hint_range(0.0, 10.0) = 2.0;
uniform float rim_power : hint_range(0.0, 10.0) = 3.0;
uniform float pulse_speed = 2.0;

void fragment() {
    float time_pulse = sin(TIME * pulse_speed) * 0.5 + 0.5; // 0..1
    
    // Base gold color
    ALBEDO = albedo_color;
    METALLIC = 1.0;
    ROUGHNESS = 0.2;
    
    // Fresnel Rim
    float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), rim_power);
    
    // Emission pulse
    vec3 emission = albedo_color * emission_energy * (0.5 + 0.5 * time_pulse);
    
    // Add rim to emission
    EMISSION = emission + (albedo_color * fresnel * 5.0);
}
