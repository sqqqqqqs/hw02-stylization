// Procedural three-tone palette from a base (texture) color, watercolor style:
// shadows drift toward a cool hue and keep some saturation, highlights get lighter, warmer and a bit paler.
// Colors arrive in linear space; the HSV edits happen in sRGB space so hue/value behave like a color picker.

float3 TP_LinearToSRGB(float3 c)
{
    c = max(c, 0.0);
    return lerp(12.92 * c, 1.055 * pow(c, 1.0 / 2.4) - 0.055, step(0.0031308, c));
}

float3 TP_SRGBToLinear(float3 c)
{
    return lerp(c / 12.92, pow((c + 0.055) / 1.055, 2.4), step(0.04045, c));
}

float3 TP_RGBToHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-5;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 TP_HSVToRGB(float3 c)
{
    float3 p = abs(frac(c.xxx + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * lerp(1.0, saturate(p - 1.0), c.y);
}

// Move hue h toward target along the shorter way around the color wheel.
float TP_ShiftHue(float h, float target, float amount)
{
    float delta = frac(target - h + 0.5) - 0.5;
    return frac(h + delta * amount);
}

void ToonPalette_float(float3 BaseColor,
    float ShadowHue, float ShadowHueShift, float ShadowValue, float ShadowMinSaturation,
    float HighlightHueShift, float HighlightValue,
    out float3 Highlight, out float3 Midtone, out float3 Shadow)
{
    const float WarmHue = 0.12; // yellow-orange

    float3 hsv = TP_RGBToHSV(TP_LinearToSRGB(BaseColor));

    // Shadow: cooler hue, darker, saturation kept (with a floor so white/grey still gets a tinted shadow).
    // Grey has no meaningful hue, so low-saturation colors take the shadow hue outright.
    float3 s = hsv;
    float hueAmount = lerp(1.0, ShadowHueShift, saturate(hsv.y / 0.2));
    s.x = TP_ShiftHue(hsv.x, ShadowHue, hueAmount);
    s.y = max(hsv.y * 0.95, ShadowMinSaturation);
    s.z = hsv.z * ShadowValue;

    // Highlight: slightly warmer and brighter; desaturate a little so it reads as light, not as a stronger color.
    float3 h = hsv;
    h.x = TP_ShiftHue(hsv.x, WarmHue, HighlightHueShift);
    h.y = hsv.y * 0.85;
    h.z = saturate(hsv.z * HighlightValue);

    Midtone = BaseColor;
    Shadow = TP_SRGBToLinear(TP_HSVToRGB(s));
    Highlight = TP_SRGBToLinear(TP_HSVToRGB(h));
}
