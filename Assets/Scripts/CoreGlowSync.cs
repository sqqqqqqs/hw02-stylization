using UnityEngine;

// Colors the point light next to Starmie with the same band sequence as HeroGlow.hlsl,
// but fades smoothly between bands instead of stepping.
[RequireComponent(typeof(Light))]
public class CoreGlowSync : MonoBehaviour
{
    public Material heroMaterial;
    [Range(0, 1)] public float saturation = 0.8f;
    public float pulseAmount = 0.5f;

    private Light coreLight;
    private float baseIntensity;

    void Start()
    {
        coreLight = GetComponent<Light>();
        baseIntensity = coreLight.intensity;
    }

    void Update()
    {
        if (heroMaterial == null) return;

        float cycleSpeed = heroMaterial.GetFloat("_CycleSpeed");

        // Same clock as the shader's _Time.y.
        float t = Time.timeSinceLevelLoad;

        // 0.25 = the shader's average noise offset (0.5 * 0.5).
        float phase = 0.25f - t * cycleSpeed;
        float bandIndex = Mathf.Floor(phase);
        float blend = Mathf.SmoothStep(0f, 1f, 1f - (phase - bandIndex));
        coreLight.color = Color.Lerp(BandColor(bandIndex), BandColor(bandIndex - 1f), blend);

        float pulse = 1f - Mathf.Abs(Mathf.Repeat(t * 0.5f, 1f) * 2f - 1f);
        coreLight.intensity = baseIntensity * (1f - pulseAmount + pulseAmount * 2f * pulse);
    }

    // Shader HG_BandHue: 3/7 stride through seven quantized hues.
    Color BandColor(float bandIndex)
    {
        float hue = Mathf.Floor(Mathf.Repeat(bandIndex * 3f / 7f, 1f) * 7f) / 7f;
        return Color.HSVToRGB(hue, saturation, 1f);
    }
}
