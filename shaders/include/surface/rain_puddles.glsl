#if !defined INCLUDE_MISC_RAIN_PUDDLES
#define INCLUDE_MISC_RAIN_PUDDLES

#include "/include/misc/material_masks.glsl"

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float get_flow_height(vec2 coord) {
    const float flow_frequency = 0.3;
    const float flow_speed = 0.15;
    const vec2 flow_dir_0 = vec2(3.0, 4.0) / 5.0;
    const vec2 flow_dir_1 = vec2(-5.0, -12.0) / 13.0;

    float noise_1 =
        texture(
            noisetex,
            coord * flow_frequency +
                frameTimeCounter * flow_speed * flow_dir_0
        )
            .y;
    float noise_2 =
        texture(
            noisetex,
            coord * flow_frequency +
                frameTimeCounter * flow_speed * flow_dir_1
        )
            .y;

    return mix(noise_1, noise_2, 0.5);
}

vec2 get_circular_ripple(vec2 coord) {
    const float cell_density = 4.5;
    const int MAX_RADIUS = 1;
    const float wave_frequency = 28.0;

    vec2 uv = coord * cell_density;
    vec2 p0 = floor(uv);

    vec2 circles = vec2(0.0);

    for (int j = -MAX_RADIUS; j <= MAX_RADIUS; ++j) {
        for (int i = -MAX_RADIUS; i <= MAX_RADIUS; ++i) {
            vec2 pi = p0 + vec2(float(i), float(j));

            float h1 = hash12(pi);
            if (h1 > 0.55) continue;

            vec2 hsh = hash22(pi);
            vec2 p = pi + hsh;

            float speed_var = 0.5 + 0.5 * hsh.y;
            float phase_offset = h1 * 6.28318;

            float raw_t = speed_var * frameTimeCounter + phase_offset;
            float t = fract(raw_t);

            float life_fade = smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.7, t);

            vec2 v = p - uv;
            float d = length(v) - (float(MAX_RADIUS) + 1.0) * t;

            const float h = 1e-3;
            float d1 = d - h;
            float d2 = d + h;

            float p1 = sin(wave_frequency * d1)
                * smoothstep(-0.8, -0.25, d1)
                * smoothstep(0.05, -0.25, d1);
            float p2 = sin(wave_frequency * d2)
                * smoothstep(-0.8, -0.25, d2)
                * smoothstep(0.05, -0.25, d2);

            circles += 0.5 * normalize(v)
                * ((p2 - p1) / (2.0 * h) * (1.0 - t) * (1.0 - t) * life_fade);
        }
    }

    circles /= float((MAX_RADIUS * 2 + 1) * (MAX_RADIUS * 2 + 1));

    return circles;
}

float get_puddle_noise(vec3 world_pos, vec3 flat_normal, vec2 light_levels) {
    const float puddle_frequency = 0.012;

    float puddle = texture(noisetex, world_pos.xz * puddle_frequency).w;

    float wet_factor = cube(wetness);
    puddle -= (1.0 - wet_factor) * 0.55;
    puddle = linear_step(0.15, 0.45, puddle) * biome_may_rain
        * linear_step(0.70, 0.95, flat_normal.y);

    puddle *= (1.0 - cube(light_levels.x))
        * linear_step(14.0 / 15.0, 1.0, light_levels.y);

    return puddle;
}

bool get_rain_puddles(
    vec3 world_pos,
    vec3 flat_normal,
    vec2 light_levels,
    float porosity,
    uint material_mask,
    inout vec3 normal,
    inout vec3 albedo,
    inout vec3 f0,
    inout float roughness,
    inout float ssr_multiplier
) {
#ifndef RAIN_PUDDLES
    return false;
#endif

    const float puddle_f0 = 0.12;
    const float puddle_roughness_min = 0.001;

    if (wetness < eps || biome_may_rain < eps
        || material_mask == MATERIAL_LEAVES) {
        return false;
    }

    float noise_val = get_puddle_noise(world_pos, flat_normal, light_levels);

    if (noise_val < eps * eps) {
        return false;
    }

    float damp = 1.0 - porosity * clamp01(noise_val * 2.0);
    float puddle_strength = sqrt(noise_val);

    f0 = max(f0, mix(f0, vec3(puddle_f0), puddle_strength));
    roughness = mix(roughness, puddle_roughness_min, damp * puddle_strength);
    ssr_multiplier = max(ssr_multiplier, 0.8 * puddle_strength);

    float puddle_zone = linear_step(0.5, 0.75, noise_val);

    float view_dist = distance(world_pos, cameraPosition);
    float dist_fade = 1.0 - dampen(linear_step(16.0, 64.0, view_dist));

    // --- Flow perturbed flat surface (subtle wobbly flatNormal) ---

    const float h = 0.1;
    float flow_h0 = get_flow_height(world_pos.xz);
    float flow_hx = get_flow_height(world_pos.xz + vec2(h, 0.0));
    float flow_hz = get_flow_height(world_pos.xz + vec2(0.0, h));

    vec2 flow_gradient = (vec2(flow_hx, flow_hz) - flow_h0) / h;
    flow_gradient *= 0.003 * dist_fade * rainStrength;

    vec3 flow_normal = normalize(vec3(-flow_gradient.x, 1.0, -flow_gradient.y));

    vec3 puddle_surface = mix(flat_normal, flow_normal, puddle_zone);

    // --- Circular ripple (only when raining) ---

    vec2 ripple_xy = get_circular_ripple(world_pos.xz);

    ripple_xy
        *= 0.25 * dist_fade
        * smoothstep(
               0.0,
               0.1,
               abs(dot(flat_normal, normalize(world_pos - cameraPosition)))
        );

    vec3 ripple_normal = normalize(
        vec3(ripple_xy, sqrt(max(0.0, 1.0 - dot(ripple_xy, ripple_xy))))
    );
    ripple_normal = ripple_normal.xzy;

    // --- Combine ---

    vec3 puddle_base = mix(normal, puddle_surface, puddle_zone);

    float ripple_weight = puddle_zone * rainStrength * dist_fade;
    vec3 ripple_offset = ripple_normal - vec3(0.0, 1.0, 0.0);
    vec3 final_normal = puddle_base + ripple_offset * ripple_weight;
    normal = normalize_safe(final_normal);

    return true;
}

#endif // INCLUDE_MISC_RAIN_PUDDLES
