shader_type spatial;
render_mode blend_mix, cull_back;

uniform float transmission : hint_range(0.0, 1.0) = 0.95;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.05;
uniform vec3 edge_color : source_color = vec3(0.5, 0.8, 1.0);

void fragment() {
    ALBEDO = edge_color;
    ALPHA = 1.0 - transmission;
    
    float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), 2.0);
    ALPHA += fresnel * 0.5; // More visible at edges
    ALPHA = clamp(ALPHA, 0.0, 1.0);
    
    METALLIC = 0.5;
    ROUGHNESS = 0.1;
    
    // Refraction
    vec2 screen_uv = SCREEN_UV;
    vec3 normal_view = (VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
    vec2 distortion = normal_view.xy * distortion_strength;
    
    // Sample background with distortion could be done if we had access to SCREEN_TEXTURE
    // In Godot 4 spatial, we use simple transparency or active distortion via Screen Texture,
    // but for simplicity in "Invisibility" we usually just rely on low Alpha + Specular/Fresnel.
    
    EMISSION = edge_color * fresnel * 2.0;
}
