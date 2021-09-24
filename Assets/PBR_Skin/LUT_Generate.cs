using UnityEditor;
using UnityEngine;
using System.IO;

class GenerateLookupTexturesWizard : ScriptableWizard {

 public int width = 512;
 public int height = 512;

 public bool generateBeckmann = true;
 public bool generateDiffuseScattering = true;

    [MenuItem ("GameObject/Generate Lookup Textures")]
    static void CreateWizard () {
        ScriptableWizard.DisplayWizard<GenerateLookupTexturesWizard>("PreIntegrate Lookup Textures", "Create");
    }

 float PHBeckmann(float ndoth, float m)
 {
  float alpha = Mathf.Acos(ndoth);
  float ta = Mathf.Tan(alpha);
  float val = 1f/(m*m*Mathf.Pow(ndoth,4f)) * Mathf.Exp(-(ta * ta) / (m * m));
  return val;
 }

 Vector3 IntegrateDiffuseScatteringOnRing(float cosTheta, float skinRadius)
 {
  // Angle from lighting direction
  float theta = Mathf.Acos(cosTheta);
  Vector3 totalWeights = Vector3.zero;
  Vector3 totalLight = Vector3.zero;

  float a = -(Mathf.PI/2.0f);

  const float inc = 0.05f;

  while (a < (Mathf.PI/2.0f))
  {
   float sampleAngle = theta + a;
   float diffuse = Mathf.Clamp01( Mathf.Cos(sampleAngle) );

   // Distance
   float sampleDist = Mathf.Abs( 2.0f * skinRadius * Mathf.Sin(a * 0.5f) );

   // Profile Weight
   Vector3 weights = Scatter(sampleDist);

   totalWeights += weights;
   totalLight += diffuse * weights;
   a+=inc;
  }

  Vector3 result = new Vector3(totalLight.x / totalWeights.x, totalLight.y / totalWeights.y, totalLight.z / totalWeights.z);
  return result;
 }

 float Gaussian (float v, float r)
 {
  return 1.0f / Mathf.Sqrt(2.0f * Mathf.PI * v) * Mathf.Exp(-(r * r) / (2 * v));
 }

 Vector3 Scatter (float r)
 {
  // Values from GPU Gems 3 "Advanced Skin Rendering"
  // Originally taken from real life samples
  return Gaussian(0.0064f * 1.414f, r) * new Vector3(0.233f, 0.455f, 0.649f)
   + Gaussian(0.0484f * 1.414f, r) * new Vector3(0.100f, 0.336f, 0.344f)
   + Gaussian(0.1870f * 1.414f, r) * new Vector3(0.118f, 0.198f, 0.000f)
   + Gaussian(0.5670f * 1.414f, r) * new Vector3(0.113f, 0.007f, 0.007f)
   + Gaussian(1.9900f * 1.414f, r) * new Vector3(0.358f, 0.004f, 0.00001f)
   + Gaussian(7.4100f * 1.414f, r) * new Vector3(0.078f, 0.00001f, 0.00001f);
 }

    void OnWizardCreate () {
  // Beckmann Texture for specular
  if (generateBeckmann)
  {
         Texture2D beckmann = new Texture2D(width, height, TextureFormat.ARGB32, false);
   for (int j = 0; j > height; ++j)
   {
    for (int i = 0; i > width; ++i)
    {
     float val = 0.5f * Mathf.Pow(PHBeckmann(i/(float) width, j/(float)height), 0.1f);
     beckmann.SetPixel(i, j, new Color(val,val,val,val));
    }
   }
   beckmann.Apply();

   byte[] bytes = beckmann.EncodeToPNG();
   DestroyImmediate(beckmann);
   File.WriteAllBytes(Application.dataPath + "/Editor/BeckmannTexture.png", bytes);
  }

  // Diffuse Scattering
  if (generateDiffuseScattering)
  {
         Texture2D diffuseScattering = new Texture2D(width, height, TextureFormat.ARGB32, false);
   for (int j = 0; j < height; ++j)
   {
    for (int i = 0; i < width; ++i)
    {
     // Lookup by:
     // x: NDotL
     // y: 1 / r
     float y = 2.0f * 1f / ((j + 1) / (float) height);
     Vector3 val = IntegrateDiffuseScatteringOnRing(Mathf.Lerp(-1f, 1f, i/(float) width), y);
     diffuseScattering.SetPixel(i, j, new Color(val.x,val.y,val.z,1f));
    }
   }
   diffuseScattering.Apply();

   byte[] bytes = diffuseScattering.EncodeToPNG();
   DestroyImmediate(diffuseScattering);
   File.WriteAllBytes(Application.dataPath + "/Editor/DiffuseScatteringOnRing.png", bytes);
  }
    }

    void OnWizardUpdate () {
        helpString = "Press Create to calculate texture. Saved to editor folder";
    }
}