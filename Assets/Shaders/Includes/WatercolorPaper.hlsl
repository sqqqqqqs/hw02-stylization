// Full-screen pass that makes the frame look painted on watercolor paper.
// The paper lives in pixel space, so it stays fixed to the screen like a page.

SAMPLER(sampler_WP_linear_clamp);

float WP_Hash21(float2 p)
{
    p = frac(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return frac(p.x * p.y);
}

float WP_ValueNoise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = WP_Hash21(i);
    float b = WP_Hash21(i + float2(1, 0));
    float c = WP_Hash21(i + float2(0, 1));
    float d = WP_Hash21(i + float2(1, 1));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

float WP_FBM(float2 p)
{
    float sum = 0.0;
    float amp = 0.5;
    [unroll] for (int i = 0; i < 3; i++)
    {
        sum += amp * WP_ValueNoise(p);
        p = p * 2.03 + 11.7;
        amp *= 0.5;
    }
    return sum / 0.875;
}

void WatercolorPaper_float(UnityTexture2D MainTex, float2 UV,
    float Saturation, float PastelLift, float Warmth,
    float GrainStrength, float GrainScale, float BleedAmount,
    float VignetteStrength, float FiberStrength,
    out float3 Color)
{
    const float3 PaperColor = float3(0.97, 0.95, 0.91); // sRGB
    const float3 lumaW = float3(0.2126, 0.7152, 0.0722);

    float2 px = UV * _ScreenParams.xy;
    float2 texel = 1.0 / _ScreenParams.xy;

    // Wet-edge bleed: low-frequency wobble of the lookup, a couple of pixels at most.
    float2 bleed = float2(WP_FBM(px / 45.0), WP_FBM(px / 45.0 + 31.4)) * 2.0 - 1.0;
    float3 col = SAMPLE_TEXTURE2D_LOD(MainTex.tex, sampler_WP_linear_clamp, UV + bleed * BleedAmount * texel, 0).rgb;

    // Grade in sRGB so the sliders feel like a paint program.
    col = pow(max(col, 0.0), 1.0 / 2.2);

    // Pastel grade: desaturate, lift toward the paper, warm slightly.
    float luma = dot(col, lumaW);
    col = lerp(luma.xxx, col, Saturation);
    col = lerp(col, PaperColor, PastelLift);
    col *= lerp(1.0, float3(1.04, 1.0, 0.93), Warmth);

    // Pigment granulation: paint settles into the paper grain, bare paper barely changes.
    float pigment = saturate(1.0 - dot(col, lumaW) / dot(PaperColor, lumaW));
    float grain = WP_FBM(px / GrainScale);
    col *= 1.0 + GrainStrength * (0.5 - grain) * (0.3 + 0.7 * pigment) * 2.0;

    // Paper fibers: faint horizontal and vertical strands, slightly warped.
    float2 fiberPx = px + (float2(WP_ValueNoise(px / 120.0), WP_ValueNoise(px / 120.0 + 17.0)) * 2.0 - 1.0) * 6.0;
    float f1 = WP_ValueNoise(fiberPx * float2(1.0 / 110.0, 1.0 / 4.0));
    float f2 = WP_ValueNoise(fiberPx * float2(1.0 / 4.0, 1.0 / 90.0) + 50.0);
    float fiber = max(smoothstep(0.86, 1.0, f1), smoothstep(0.88, 1.0, f2));
    col *= 1.0 - FiberStrength * fiber * 0.15;

    // Warm, darkened page corners.
    float aspect = _ScreenParams.x / _ScreenParams.y;
    float d = length((UV - 0.5) * float2(aspect, 1.0)) / length(float2(aspect, 1.0) * 0.5);
    float vignette = smoothstep(0.45, 1.0, d);
    col = lerp(col, col * float3(0.86, 0.80, 0.72), VignetteStrength * vignette);

    Color = pow(saturate(col), 2.2);
}
