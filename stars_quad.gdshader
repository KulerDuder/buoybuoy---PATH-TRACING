shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float star_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float star_grid_scale : hint_range(50.0, 800.0) = 200.0;
uniform float star_density : hint_range(0.80, 1.0) = 0.985;
uniform float star_size : hint_range(0.05, 0.5) = 0.25;
uniform float star_brightness : hint_range(0.0, 5.0) = 2.5;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 p = UV * star_grid_scale;
    vec2 cell = floor(p);
    vec2 local = fract(p);

    float h = hash21(cell);
    float star = 0.0;
    if (h > star_density) {
        vec2 offset = vec2(hash21(cell + 7.13), hash21(cell + 3.71));
        float d = length(local - offset);
        float intensity = (h - star_density) / (1.0 - star_density);
        star = smoothstep(star_size, 0.0, d) * intensity;
    }

    ALBEDO = vec3(0.0);
    EMISSION = vec3(star * star_alpha * star_brightness);
    ALPHA = star * star_alpha;
}