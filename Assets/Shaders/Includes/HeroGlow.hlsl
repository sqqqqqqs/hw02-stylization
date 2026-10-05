// Hero effect for Starmie's core: "glows brightly in seven colors".
// Keep the hue math in sync with Assets/Scripts/CoreGlowSync.cs.

float HG_Hash21(float2 p)
{
    p = frac(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return frac(p.x * p.y);
}

float HG_Hash31(float3 p)
{
    p = frac(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return frac((p.x + p.y) * p.z);
}

float HG_ValueNoise(float3 p)
{
    float3 i = floor(p);
    float3 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = HG_Hash31(i);
    float n100 = HG_Hash31(i + float3(1, 0, 0));
    float n010 = HG_Hash31(i + float3(0, 1, 0));
    float n110 = HG_Hash31(i + float3(1, 1, 0));
    float n001 = HG_Hash31(i + float3(0, 0, 1));
    float n101 = HG_Hash31(i + float3(1, 0, 1));
    float n011 = HG_Hash31(i + float3(0, 1, 1));
    float n111 = HG_Hash31(i + float3(1, 1, 1));
    return lerp(lerp(lerp(n000, n100, f.x), lerp(n010, n110, f.x), f.y),
                lerp(lerp(n001, n101, f.x), lerp(n011, n111, f.x), f.y), f.z);
}

// 0 -> 1 -> 0 over one period.
float HG_Triangle(float x)
{
    return 1.0 - abs(frac(x) * 2.0 - 1.0);
}

float3 HG_HueToRGB(float h)
{
    return saturate(abs(frac(h + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0);
}

// Seven-color sequence for band index i (3/7 stride walks all seven hues in a pleasing order).
float HG_BandHue(float i)
{
    return floor(frac(i * 3.0 / 7.0) * 7.0) / 7.0;
}

void HeroGlow_float(float3 ToonColor, float3 Midtone, float3 WorldPos, float2 ScreenUV, float Time,
    float StepRate, float CycleSpeed, float ColorMix, float GlowStrength, float SparkleDensity, float SparkleScale,
    out float3 Color)
{
    const float RainbowSaturation = 0.4;
    const float BandFrequency = 2.5;   // bands per world unit
    const float BandWidth = 0.35;      // fraction of each period covered by a band
    const float3 BandDir = float3(0.80, 0.50, 0.33);

    // Stepped time: only advances StepRate times per second, like hand-drawn animation on 2s/3s.
    float frame = floor(Time * StepRate);
    float t = frame / StepRate;

    // Diagonal bands sweep across the gem; static world-space noise wobbles their edges per facet.
    float n = HG_ValueNoise(WorldPos * 4.0);
    float phase = dot(WorldPos, BandDir) * BandFrequency + n * 0.5 - t * CycleSpeed;
    float band = smoothstep(1.0 - BandWidth, 1.0 - BandWidth + 0.08, HG_Triangle(phase));

    // Each band gets one of seven hues, in sequence.
    float3 rainbow = lerp(1.0, HG_HueToRGB(HG_BandHue(floor(phase))), RainbowSaturation);
    rainbow = pow(rainbow, 2.2); // authored as sRGB, output is linear

    // Keep the toon bands: scale the rainbow by how lit this pixel is relative to its midtone.
    float3 lumaW = float3(0.2126, 0.7152, 0.0722);
    float shade = dot(ToonColor, lumaW) / max(dot(Midtone, lumaW), 0.001);
    float3 shaded = rainbow * clamp(shade, 0.3, 1.3);

    float3 col = lerp(ToonColor, shaded, band * ColorMix);
    col *= 1.0 + GlowStrength * HG_Triangle(t * 0.5);

    // Screen-space sparkles: random cells light up as small white dots, reshuffled every frame.
    float2 cellUV = ScreenUV * SparkleScale;
    float lit = step(1.0 - SparkleDensity, HG_Hash21(floor(cellUV) + frame));
    float dotMask = smoothstep(0.25, 0.1, length(frac(cellUV) - 0.5));
    col = lerp(col, 1.0, lit * dotMask);

    Color = col;
}
