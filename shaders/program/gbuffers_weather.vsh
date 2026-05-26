/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge
  Modified by xuyin2333

  program/gbuffers_weather:
  Handle rain and snow particles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec4 tint;

// ------------
//   Uniforms
// ------------

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform int frameCounter;

uniform float frameTimeCounter;
uniform float wetness;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;

void main() {
    uv = (mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy
        + gl_TextureMatrix[0][3].xy) * vec2(RAIN_SCALE_X, RAIN_SCALE_Y);

    tint = gl_Color;

    vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

#ifdef SLANTED_RAIN
    vec3 scene_pos = transform(gbufferModelViewInverse, view_pos);
    vec3 world_pos = scene_pos + cameraPosition;

    // Wind-driven rain tilt: particles are biased toward a global wind
    // direction (slowly rotating with time) but each particle has its own
    // random offset via spatial hash, creating natural turbulence while
    // maintaining a coherent wind direction.
    float spatial = dot(world_pos, vec3(0.618, 1.618, 0.382));
    float global_wind = frameTimeCounter * 0.025;
    float hash_angle = fract(spatial * 1.618) * 6.283;
    float wind_angle = global_wind + 0.6 * sin(hash_angle);
    vec2 wind_dir = vec2(cos(wind_angle), sin(wind_angle));

    float wind_weight = wetness;
    float wind_mag = 0.25 + 0.45 * wind_weight;
    float gust = 0.12 * sin(spatial + frameTimeCounter * 0.03)
               + 0.08 * cos(spatial * 1.7 + frameTimeCounter * 0.07);
    wind_mag = clamp(wind_mag + gust, 0.0, 1.0);

    float tilt = mix(0.20, 0.26, wind_mag);
    scene_pos.xz -= wind_dir * tilt * scene_pos.y;

    view_pos = transform(gbufferModelView, scene_pos);
#endif

    vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if defined TAA && defined TAAU
    clip_pos.xy = clip_pos.xy * taau_render_scale
        + clip_pos.w * (taau_render_scale - 1.0);
    clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
    clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

    gl_Position = clip_pos;
}
