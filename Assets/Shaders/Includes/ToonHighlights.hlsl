// Rim light + hard specular dot masks for the toon shader.
// Both outputs are 0..1 masks; the graph lerps the toon color toward RimColor / SpecColor with them.
void ToonHighlights_float(float3 WorldNormal, float3 ViewDir, float3 LightDir, float ShadowAtten,
    float RimSize, float RimSoftness, float SpecSize,
    out float Rim, out float Spec)
{
    float3 N = normalize(WorldNormal);
    float3 V = normalize(ViewDir);
    float3 L = normalize(LightDir);

    // Rim: 1 - N.V grows toward the silhouette; smoothstep turns it into a thin band.
    float fresnel = 1.0 - saturate(dot(N, V));
    float rimEdge = 1.0 - RimSize;
    float rimSoft = max(RimSoftness, 0.0001);
    Rim = smoothstep(rimEdge - rimSoft, rimEdge + rimSoft, fresnel);

    // Specular: Blinn-Phong N.H cut into a hard dot, only on the lit side and outside cast shadows.
    float3 H = normalize(L + V);
    float NdotH = saturate(dot(N, H));
    float specEdge = 1.0 - SpecSize;
    Spec = smoothstep(specEdge - 0.002, specEdge + 0.002, NdotH);
    Spec *= step(0.0, dot(N, L)) * ShadowAtten;
}
