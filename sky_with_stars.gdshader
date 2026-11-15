shader_type sky;

uniform vec3 sky_top_day : source_color = vec3(0.30, 0.55, 0.90);
uniform vec3 sky_horizon_day : source_color = vec3(0.70, 0.85, 0.95);
uniform vec3 sky_top_night : source_color = vec3(0.02, 0.02, 0.06);
uniform vec3 sky_horizon_night : source_color = vec3(0.05, 0.08, 0.15);
uniform vec3 sky_twilight : source_color = vec3(1.00, 0.45, 0.20);

uniform float day_amount : hint_range(0.0, 1.0) = 1.0;
uniform float twilight_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
uniform vec3 sun_disc_color : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 moon_disc_color : source_color = vec3(0.85, 0.90, 1.0);
uniform float sun_disc_strength = 0.0;
uniform float moon_disc_strength = 0.0;

void sky() {
    vec3 dir = normalize(EYEDIR);
    float up = clamp(dir.y, 0.0, 1.0);
    float horizon_blend = smoothstep(0.0, 0.4, up);

    vec3 top_color = mix(sky_top_night, sky_top_day, day_amount);
    vec3 horizon_color = mix(sky_horizon_night, sky_horizon_day, day_amount);
    horizon_color = mix(horizon_color, sky_twilight, twilight_amount * 0.7);

    vec3 col = mix(horizon_color, top_color, horizon_blend);

    if (dir.y < 0.0) {
        vec3 ground_color = mix(sky_top_night * 0.5, sky_top_day * 0.5, day_amount);
        float ground_blend = 1.0 - smoothstep(-0.1, 0.0, dir.y);
        col = mix(col, ground_color, ground_blend);
    }

    float sd = dot(dir, -sun_direction);
    float sun_disc = smoothstep(0.9985, 0.9995, sd) * sun_disc_strength;
    col += sun_disc_color * sun_disc;

    float md = dot(dir, -moon_direction);
    float moon_disc = smoothstep(0.9990, 0.9997, md) * moon_disc_strength;
    col += moon_disc_color * moon_disc;

    COLOR = col;
}