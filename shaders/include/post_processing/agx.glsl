#if !defined INCLUDE_AGX_TONEMAP
#define INCLUDE_AGX_TONEMAP

// Minimal implementation of Troy Sobotka's AgX display transform by bwrensch
// Source: https://www.shadertoy.com/view/cd3XWr
//         https://iolite-engine.com/blog_posts/minimal_agx_implementation
// Original: https://github.com/sobotka/AgX
//
// Adapted from Photon-GAMS-dev community implementation

vec3 agx_default_contrast_approx(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;

    return + 15.5     * x4 * x2
           - 40.14    * x4 * x
           + 31.96    * x4
           - 6.868    * x2 * x
           + 0.4298   * x2
           + 0.1191   * x
           - 0.00232;
}

vec3 agx_look(vec3 val) {
    const vec3 lw = vec3(0.2126, 0.7152, 0.0722);
    float luma = dot(val, lw);

    const vec3 slope = vec3(1.0);
    const vec3 power = vec3(1.0);
    const float sat = 1.0;

    val = pow(val * slope, power);
    return luma + sat * (val - luma);
}

vec3 agx_pre(vec3 rgb) {
    const mat3 agx_mat = mat3(
        0.842479062253094, 0.0423282422610123, 0.0423756549057051,
        0.0784335999999992,  0.878468636469772,  0.0784336,
        0.0792237451477643, 0.0791661274605434, 0.879142973793104
    );

    const float min_ev = -7.5;
    const float max_ev = 5.5;
    const float middle_grey = 0.18;

    rgb = agx_mat * rgb;

    rgb = clamp(log2(rgb * (1.0 / middle_grey)), min_ev, max_ev);
    rgb = (rgb - min_ev) / (max_ev - min_ev);

    return rgb;
}

vec3 agx_eotf(vec3 val) {
    const mat3 agx_mat_inv = mat3(
        1.19687900512017, -0.0528968517574562, -0.0529716355144438,
        -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
        -0.0990297440797205, -0.0989611768448433, 1.15107367264116
    );

    val = agx_mat_inv * val;

    return val;
}

vec3 tonemap_agx(vec3 rgb) {
    rgb *= 1.2;
    rgb = agx_pre(rgb);

    rgb = agx_default_contrast_approx(rgb);

    rgb = agx_look(rgb);

    rgb = agx_eotf(rgb);

    return srgb_eotf_inv(rgb);
}

#endif // INCLUDE_AGX_TONEMAP
