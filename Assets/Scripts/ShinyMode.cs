using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;

// Press the toggle key to switch the scene into "Shiny mode":
// every renderer using a material from the pairs list swaps to its shiny counterpart,
// and the watercolor post-process switches to its shiny variant.
public class ShinyMode : MonoBehaviour
{
    [System.Serializable]
    public class MaterialPair
    {
        public Material normal;
        public Material shiny;
    }

    public KeyCode toggleKey = KeyCode.Space;
    public List<MaterialPair> materialPairs = new List<MaterialPair>();
    public ScriptableRendererFeature normalPost;
    public ScriptableRendererFeature shinyPost;

    private readonly List<Renderer> renderers = new List<Renderer>();
    private readonly List<Material[]> originalMaterials = new List<Material[]>();
    private bool isShiny;
    private bool normalPostWasActive;
    private bool shinyPostWasActive;

    void Start()
    {
        foreach (Renderer r in FindObjectsOfType<Renderer>())
        {
            renderers.Add(r);
            originalMaterials.Add(r.sharedMaterials);
        }

        normalPostWasActive = normalPost.isActive;
        shinyPostWasActive = shinyPost.isActive;

        Apply(false);
    }

    void Update()
    {
        if (Input.GetKeyDown(toggleKey))
        {
            Apply(!isShiny);
        }
    }

    // Scene objects reset on their own after play mode, but the renderer feature assets don't.
    void OnDisable()
    {
        normalPost.SetActive(normalPostWasActive);
        shinyPost.SetActive(shinyPostWasActive);
    }

    void Apply(bool shiny)
    {
        isShiny = shiny;

        for (int i = 0; i < renderers.Count; i++)
        {
            Material[] mats = (Material[])originalMaterials[i].Clone();
            if (shiny)
            {
                for (int m = 0; m < mats.Length; m++) mats[m] = ShinyFor(mats[m]);
            }
            renderers[i].sharedMaterials = mats;
        }

        normalPost.SetActive(!shiny);
        shinyPost.SetActive(shiny);
    }

    Material ShinyFor(Material normal)
    {
        foreach (MaterialPair pair in materialPairs)
        {
            if (pair.normal == normal && pair.shiny != null) return pair.shiny;
        }
        return normal;
    }
}
