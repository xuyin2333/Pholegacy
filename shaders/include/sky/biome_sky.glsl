#if !defined INCLUDE_SKY_BIOME_SKY
#define INCLUDE_SKY_BIOME_SKY

#if defined BIOME_SKY && defined WORLD_OVERWORLD

#include "/include/utility/color.glsl"
#include "/include/utility/fast_math.glsl"

uniform vec3 skyColor;

vec3 get_biome_sky(vec3 ray_dir) {
    float VdotU = ray_dir.y;
    float VdotS = dot(ray_dir, sun_dir);

    vec3 skyColorLin = from_srgb(skyColor);
    vec3 skyColorSqrt = sqrt(skyColorLin);

    float invRainStr2 = sqr(1.0 - rainStrength);
    vec3 skyColorM = mix(max(skyColorSqrt, vec3(0.63, 0.67, 0.73)), skyColorSqrt, invRainStr2);
    vec3 skyColorM2 = mix(max(skyColorLin, max(sun_dir.y, 0.0) * vec3(0.265, 0.295, 0.35)), skyColorLin, invRainStr2);

    float sunFactor = max(sun_dir.y, 0.0);
    float noonFactor = time_noon + 0.5 * (time_sunrise + time_sunset);
    float invNoonFactor2 = sqr(1.0 - noonFactor);
    float rainFactor = rainStrength;
    float invRainFactor = 1.0 - rainFactor;

    vec3 nmscSnowM = biome_snowy * vec3(-0.1, 0.3, 0.6);
    vec3 nmscDryM  = biome_arid  * vec3(-0.1, -0.2, -0.3);
    vec3 ndscSnowM = biome_snowy * vec3(-0.25, -0.01, 0.25);
    vec3 ndscDryM  = biome_arid  * vec3(-0.05, -0.09, -0.1);
    vec3 nmscRainM = biome_may_rain * vec3(-0.15, 0.025, 0.1);
    vec3 ndscRainM = biome_may_rain * vec3(-0.125, -0.005, 0.125);

    vec3 nuscWeatherM = vec3(0.1, 0.0, 0.1);
    vec3 nmscWeatherM = vec3(-0.1, -0.4, -0.6) + vec3(0.0, 0.06, 0.12) * noonFactor;
    vec3 ndscWeatherM = vec3(-0.15, -0.3, -0.42) + vec3(0.0, 0.02, 0.08) * noonFactor;

    vec3 noonUpSkyColor     = pow(skyColorM, vec3(2.9)) * (vec3(0.85, 0.92, 0.81) + rainFactor * nuscWeatherM);
    vec3 noonMiddleSkyColor = pow(skyColorM, vec3(1.5)) * (vec3(1.3) + rainFactor * (nmscWeatherM + nmscRainM + nmscSnowM + nmscDryM))
                              + noonUpSkyColor * 0.65;
    vec3 noonDownSkyColor   = skyColorM * (vec3(0.9) + rainFactor * (ndscWeatherM + ndscRainM + ndscSnowM + ndscDryM))
                              + noonUpSkyColor * 0.25;

    vec3 sunsetUpSkyColor     = skyColorM2 * (vec3(0.72, 0.522, 0.47) + vec3(0.1, 0.2, 0.35) * sqr(invRainFactor));
    vec3 sunsetMiddleSkyColor = skyColorM2 * (vec3(1.8, 1.3, 1.2) + vec3(0.15, 0.25, -0.05) * sqr(invRainFactor));
    vec3 sunsetDownSkyColorP  = vec3(1.45, 0.86, 0.5) - vec3(0.8, 0.3, 0.0) * rainFactor;
    vec3 sunsetDownSkyColor   = sunsetDownSkyColorP * 0.5 + 0.25 * sunsetMiddleSkyColor;

    vec3 dayUpSkyColor     = mix(noonUpSkyColor, sunsetUpSkyColor, invNoonFactor2);
    vec3 dayMiddleSkyColor = mix(noonMiddleSkyColor, sunsetMiddleSkyColor, invNoonFactor2);
    vec3 dayDownSkyColor   = mix(noonDownSkyColor, sunsetDownSkyColor, invNoonFactor2);

    vec3 nightColFactor      = 0.9 * vec3(0.07, 0.14, 0.24) * (1.0 - 0.5 * rainFactor) + skyColorLin;
    vec3 nightUpSkyColor     = pow(nightColFactor, vec3(0.90)) * 0.45;
    vec3 nightMiddleSkyColor = sqrt(nightUpSkyColor) * 0.65;
    vec3 nightDownSkyColor   = nightMiddleSkyColor * vec3(0.82, 0.82, 0.88);

    vec3 upColor     = mix(nightUpSkyColor, dayUpSkyColor, sunFactor);
    vec3 middleColor = mix(nightMiddleSkyColor, dayMiddleSkyColor, sunFactor);
    vec3 downColor   = mix(nightDownSkyColor, dayDownSkyColor, (sunFactor + smoothstep(0.40, 0.55, sunAngle)) * 0.5);

    float VdotUmax0 = max(VdotU, 0.0);

    float VdotUM1 = sqr(1.0 - VdotUmax0);
    VdotUM1 = pow(VdotUM1, 1.0 - sqr(max(VdotS, 0.0)) * 0.4);
    VdotUM1 = mix(VdotUM1, 1.0, sqr(invRainFactor) * 0.15);
    vec3 biome_sky = mix(upColor, middleColor, VdotUM1);

    float VdotUM2 = sqr(1.0 - abs(VdotU));
    VdotUM2 = sqr(VdotUM2) * (3.0 - 2.0 * VdotUM2);
    VdotUM2 *= (0.7 + max(VdotS, 0.0) * 0.3) * (1.0 - noonFactor) * sunFactor;
    biome_sky = mix(biome_sky, sunsetDownSkyColorP * (1.0 + max(VdotS, 0.0) * 0.3), VdotUM2 * invRainFactor);

    float VdotUM3 = min(max(-VdotU + 0.08, 0.0) / 0.35, 1.0);
    VdotUM3 = VdotUM3 * VdotUM3 * (3.0 - 2.0 * VdotUM3);
    vec3 scatteredGroundMixer = vec3(sqr(VdotUM3), sqrt(max(VdotUM3, 0.0)), sqrt(max(cube(VdotUM3), 0.0)));
    scatteredGroundMixer = mix(vec3(VdotUM3), scatteredGroundMixer, 0.75 - 0.5 * rainFactor);
    biome_sky = mix(biome_sky, downColor, scatteredGroundMixer);

    return biome_sky;
}

#endif
#endif
