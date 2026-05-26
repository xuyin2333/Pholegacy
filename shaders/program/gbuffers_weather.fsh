/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge
  Modified by xuyin2333

  program/gbuffers_weather:
  Handle rain and snow particles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout(location = 0) out vec4 refraction_data;
layout(location = 1) out vec4 frag_color;

/* RENDERTARGETS: 3,13 */

in vec2 uv;

flat in vec4 tint;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;
uniform sampler2D depthtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform int moonPhase;
uniform int frameCounter;

uniform vec3 sun_dir;
uniform vec3 cameraPosition;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;

uniform float biome_may_snow;
uniform float rainStrength;
uniform float wetness;

uniform float near;
uniform float far;

#include "/include/lighting/colors/weather_color.glsl"
#include "/include/utility/encoding.glsl"
#include "/include/utility/phase_functions.glsl"
#include "/include/utility/space_conversion.glsl"

void main() {
#if defined TAA && defined TAAU
    vec2 coord = gl_FragCoord.xy * view_pixel_size * rcp(taau_render_scale);
    if (clamp01(coord) != coord) {
        discard;
    }
#endif

    vec4 base_color = texture(gtexture, uv);
    if (base_color.a < 0.1) {
        discard;
    }

    bool is_rain = (abs(base_color.r - base_color.b) > eps);

    vec3 weather_color = is_rain ? get_rain_color() : get_snow_color();
    float opacity = is_rain ? RAIN_OPACITY : SNOW_OPACITY;

    frag_color = vec4(weather_color, opacity * base_color.a) * tint;
    frag_color.rgb *= frag_color.a;

    refraction_data = vec4(0.0, 0.0, 0.0, 1.0);
}
