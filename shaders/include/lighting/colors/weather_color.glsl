#if !defined INCLUDE_LIGHTING_COLORS_WEATHER_COLOR
#define INCLUDE_LIGHTING_COLORS_WEATHER_COLOR

#include "/include/sky/atmosphere.glsl"

uniform float biome_may_sandstorm;

vec3 get_rain_color() {
    // Sun-driven component: dominates during daytime
    float day_factor = smoothstep(-0.1, 0.5, sun_dir.y);
    float sun_brightness = mix(0.08, 0.45, day_factor);
    vec3 sun_component = sun_brightness * sunlight_color;

    // Moon-compatible night floor: neutral gray so rain blends into dark
    // backgrounds without standing out as blue streaks (matching Rev)
    vec3 night_floor = vec3(0.09, 0.095, 0.11) * (1.0 - day_factor * 0.8);

    // Combine with smooth twilight transition
    vec3 base = max(sun_component, night_floor);

    // Adaptive tint: bright = blue-white water color, dark = near-neutral
    // so rain doesn't glow blue in shadows
    float luminance = dot(base, vec3(0.2126, 0.7152, 0.0722));
    vec3 bright_tint = vec3(0.65, 0.75, 1.00);
    vec3 dark_tint  = vec3(0.95, 0.97, 1.02);
    vec3 rain_tint = mix(dark_tint, bright_tint, clamp01(luminance * 3.0));

    return base * rain_tint;
}

vec3 get_snow_color() {
#if defined PROGRAM_WEATHER
    float day_factor = smoothstep(-0.1, 0.5, sun_dir.y);
    float sun_brightness = mix(0.25, 0.90, day_factor);
    vec3 sun_component = sun_brightness * sunlight_color;

    vec3 night_floor = vec3(0.15, 0.18, 0.22) * (1.0 - day_factor * 0.8);

    vec3 base = max(sun_component, night_floor);
    return base * vec3(0.49, 0.65, 1.00);
#else
    float day_factor = smoothstep(-0.1, 0.5, sun_dir.y);
    float sun_brightness = mix(0.06, 1.60, day_factor);
    return sun_brightness * sunlight_color * vec3(0.49, 0.65, 1.00);
#endif
}

vec3 get_sandstorm_color() {
    return mix(0.033, 0.66, smoothstep(-0.1, 0.5, sun_dir.y)) * sunlight_color
        * vec3(1.00, 0.83, 0.60);
}

vec3 get_weather_color() {
    vec3 weather_color
        = mix(get_rain_color(), get_snow_color(), biome_may_snow);
    weather_color
        = mix(weather_color, get_sandstorm_color(), biome_may_sandstorm);

    return weather_color;
}

#endif // INCLUDE_LIGHTING_COLORS_WEATHER_COLOR
