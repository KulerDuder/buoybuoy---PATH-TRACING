shader_type spatial;
render_mode cull_disabled, blend_mix;

uniform vec4 wave_dirs_0 = vec4(1.0, 0.0, 0.15, 0.5);
uniform vec4 wave_dirs_1 = vec4(0.7, 0.7, 0.10, 0.9);
uniform vec4 wave_dirs_2 = vec4(-0.4, 0.9, 0.06, 1.6);
uniform float wave_speed_0 = 1.0;
uniform float wave_speed_1 = 1.4;
uniform float wave_speed_2 = 2.0;
uniform float wave_phase_0 = 0.0;
uniform float wave_phase_1 = 1.3;
uniform float wave_phase_2 = 2.1;
uniform float world_time = 0.0;
uniform vec4 water_color : source_color = vec4(0.0, 0.45, 0.85, 0.6);

float wave_height(vec2 world_xz) {
    float h = 0.0;
    h += wave_dirs_0.z * sin(dot(wave_dirs_0.xy, world_xz) * wave_dirs_0.w - world_time * wave_speed_0 + wave_phase_0);
    h += wave_dirs_1.z * sin(dot(wave_dirs_1.xy, world_xz) * wave_dirs_1.w - world_time * wave_speed_1 + wave_phase_1);
    h += wave_dirs_2.z * sin(dot(wave_dirs_2.xy, world_xz) * wave_dirs_2.w - world_time * wave_speed_2 + wave_phase_2);
    return h;
}

void vertex() {
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += wave_height(world_pos.xz);
}

void fragment() {
    ALBEDO = water_color.rgb;
    ALPHA = water_color.a;
    ROUGHNESS = 0.15;
    METALLIC = 0.05;
}