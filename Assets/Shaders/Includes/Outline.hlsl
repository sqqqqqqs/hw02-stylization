// Post-process outlines from the depth and normal buffers.
// Depth edges (silhouettes) wobble with stepped noise ("boiling" hand-drawn lines);
// normal edges (inner creases) stay still so the drawing keeps its structure.
// EdgeMethod: 0 = Roberts Cross (2x2), 1 = Sobel (3x3).

// The node preview compiles without URP's Core.hlsl; pulling it in there redefines _Time.
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#endif

SAMPLER(sampler_OL_point_clamp);

float OL_Hash21(float2 p)
{
    p = frac(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return frac(p.x * p.y);
}

float OL_ValueNoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = OL_Hash21(i);
    float b = OL_Hash21(i + float2(1, 0));
    float c = OL_Hash21(i + float2(0, 1));
    float d = OL_Hash21(i + float2(1, 1));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

float OL_EyeDepth(float2 uv)
{
#ifdef SHADERGRAPH_PREVIEW
    return 1.0;
#else
    return LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
#endif
}

float3 OL_Normal(UnityTexture2D normalTex, float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(normalTex.tex, sampler_OL_point_clamp, uv, 0).rgb * 2.0 - 1.0;
}

// Relative depth edge strength; also reports the uv of the nearest sample (the object side of a silhouette).
float OL_DepthEdge(float2 uv, float2 stepUV, float method, out float2 nearUV)
{
    float center = OL_EyeDepth(uv);
    float edge;
    nearUV = uv;
    float nearest = center;

    if (method < 0.5)
    {
        float2 o0 = float2(-1, -1) * stepUV, o1 = float2(1, 1) * stepUV;
        float2 o2 = float2(1, -1) * stepUV, o3 = float2(-1, 1) * stepUV;
        float d0 = OL_EyeDepth(uv + o0), d1 = OL_EyeDepth(uv + o1);
        float d2 = OL_EyeDepth(uv + o2), d3 = OL_EyeDepth(uv + o3);
        edge = sqrt((d1 - d0) * (d1 - d0) + (d3 - d2) * (d3 - d2));
        if (d0 < nearest) { nearest = d0; nearUV = uv + o0; }
        if (d1 < nearest) { nearest = d1; nearUV = uv + o1; }
        if (d2 < nearest) { nearest = d2; nearUV = uv + o2; }
        if (d3 < nearest) { nearest = d3; nearUV = uv + o3; }
    }
    else
    {
        float gx = 0, gy = 0;
        [unroll] for (int y = -1; y <= 1; y++)
        {
            [unroll] for (int x = -1; x <= 1; x++)
            {
                float2 o = float2(x, y) * stepUV;
                float d = OL_EyeDepth(uv + o);
                float wx = x * (y == 0 ? 2.0 : 1.0);
                float wy = y * (x == 0 ? 2.0 : 1.0);
                gx += d * wx;
                gy += d * wy;
                if (d < nearest) { nearest = d; nearUV = uv + o; }
            }
        }
        edge = sqrt(gx * gx + gy * gy) * 0.25;
    }
    return edge / center;
}

float OL_NormalEdge(UnityTexture2D normalTex, float2 uv, float2 stepUV, float method)
{
    if (method < 0.5)
    {
        float3 n0 = OL_Normal(normalTex, uv + float2(-1, -1) * stepUV);
        float3 n1 = OL_Normal(normalTex, uv + float2(1, 1) * stepUV);
        float3 n2 = OL_Normal(normalTex, uv + float2(1, -1) * stepUV);
        float3 n3 = OL_Normal(normalTex, uv + float2(-1, 1) * stepUV);
        float3 a = n1 - n0, b = n3 - n2;
        return sqrt(dot(a, a) + dot(b, b));
    }

    float3 gx = 0, gy = 0;
    [unroll] for (int y = -1; y <= 1; y++)
    {
        [unroll] for (int x = -1; x <= 1; x++)
        {
            float3 n = OL_Normal(normalTex, uv + float2(x, y) * stepUV);
            gx += n * (x * (y == 0 ? 2.0 : 1.0));
            gy += n * (y * (x == 0 ? 2.0 : 1.0));
        }
    }
    return sqrt(dot(gx, gx) + dot(gy, gy)) * 0.25;
}

void Outline_float(UnityTexture2D MainTex, UnityTexture2D NormalTex, float2 UV, float Time,
    float EdgeMethod, float LineWidth, float DepthThreshold, float NormalThreshold,
    float WobbleAmount, float WobbleRate, float WobbleScale, float ThicknessJitter,
    float LineDarken, float3 OutlineColor, float OutlineColorMix,
    out float3 Color, out float Edge)
{
    float2 texel = 1.0 / _ScreenParams.xy;

    // New noise pattern only WobbleRate times per second: lines "boil" like hand-drawn animation.
    float2 seed = floor(Time * WobbleRate) * float2(17.31, 31.73);

    // Hand-drawn thickness variation along the lines.
    float width = LineWidth * (1.0 + ThicknessJitter * (OL_ValueNoise(UV * WobbleScale * 0.5 + seed * 0.5) * 2.0 - 1.0));
    float2 stepUV = texel * width * 0.5;

    float2 wobble = float2(OL_ValueNoise(UV * WobbleScale + seed),
                           OL_ValueNoise(UV * WobbleScale + seed + 7.7)) * 2.0 - 1.0;
    float2 depthUV = UV + wobble * WobbleAmount * texel;
    float2 nearUV;
    float depthEdge = OL_DepthEdge(depthUV, stepUV, EdgeMethod, nearUV);
    depthEdge = smoothstep(DepthThreshold, DepthThreshold * 1.5 + 0.0001, depthEdge);

    float normalEdge = OL_NormalEdge(NormalTex, UV, stepUV, EdgeMethod);
    normalEdge = smoothstep(NormalThreshold, NormalThreshold * 1.5 + 0.0001, normalEdge);

    Edge = max(depthEdge, normalEdge);

    // Line color: a darker version of the object it outlines, mixed with a shared ink color.
    float3 scene = SAMPLE_TEXTURE2D_LOD(MainTex.tex, sampler_OL_point_clamp, UV, 0).rgb;
    float2 inkUV = depthEdge > normalEdge ? nearUV : UV;
    float3 objectColor = SAMPLE_TEXTURE2D_LOD(MainTex.tex, sampler_OL_point_clamp, inkUV, 0).rgb;
    float3 ink = lerp(objectColor * LineDarken, OutlineColor, OutlineColorMix);

    Color = lerp(scene, ink, Edge);
}
