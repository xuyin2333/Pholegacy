#if !defined INCLUDE_MISC_TONEMAP_OPERATORS
#define INCLUDE_MISC_TONEMAP_OPERATORS

#include "/include/post_processing/aces/aces.glsl"
#include "/include/post_processing/agx.glsl"
#include "/include/utility/color.glsl"

// ACES RRT and ODT approximation
vec3 tonemap_aces_fit(vec3 rgb) {
    rgb *= 1.2;
    rgb = rgb * rec2020_to_ap0;

    rgb = rrt_sweeteners(rgb);
    rgb = rrt_and_odt_fit(rgb);

    vec3 grayscale = vec3(dot(rgb, luminance_weights));
    rgb = mix(grayscale, rgb, odt_sat_factor);

    return rgb * ap1_to_rec2020;
}

// Timothy Lottes 2016, "Advanced Techniques and Optimization of HDR Color
// Pipelines" https://gpuopen.com/wp-content/uploads/2016/03/GdcVdrLottes.pdf
vec3 tonemap_lottes(vec3 rgb) {
    const vec3 a = vec3(1.5);
    const vec3 d = vec3(0.91);
    const vec3 hdr_max = vec3(8.0);
    const vec3 mid_in = vec3(0.26);
    const vec3 mid_out = vec3(0.32);

    const vec3 b = (-pow(mid_in, a) + pow(hdr_max, a) * mid_out)
        / ((pow(hdr_max, a * d) - pow(mid_in, a * d)) * mid_out);
    const vec3 c = (pow(hdr_max, a * d) * pow(mid_in, a)
                    - pow(hdr_max, a) * pow(mid_in, a * d) * mid_out)
        / ((pow(hdr_max, a * d) - pow(mid_in, a * d)) * mid_out);

    return pow(rgb, a) / (pow(rgb, a * d) * b + c);
}

// Filmic tonemapping operator made by John Hable for Uncharted 2
vec3 tonemap_uncharted_2_partial(vec3 rgb) {
    const float a = 0.15;
    const float b = 0.50;
    const float c = 0.10;
    const float d = 0.20;
    const float e = 0.02;
    const float f = 0.30;

    return ((rgb * (a * rgb + (c * b)) + (d * e))
            / (rgb * (a * rgb + b) + d * f))
        - e / f;
}

vec3 tonemap_uncharted_2(vec3 rgb) {
    const float exposure_bias = 2.0;
    const vec3 w = vec3(11.2);

    vec3 curr = tonemap_uncharted_2_partial(rgb * exposure_bias);
    vec3 white_scale = vec3(1.0) / tonemap_uncharted_2_partial(w);
    return curr * white_scale;
}

#endif // INCLUDE_MISC_TONEMAP_OPERATORS