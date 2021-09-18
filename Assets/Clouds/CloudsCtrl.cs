using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class CloudsCtrl : MonoBehaviour
{
    // Start is called before the first frame update
	public Shader shader;
	public Transform container;
	Material mat;

    public Texture3D  CloudBase;
    public Texture3D CloudDetail;
    public float DensityThresold = 0.3f;
    public float DensityMul = 1;

    public int CloudSteps = 10;
    public float CloudFade = 1;
    public float TimeScale = 1;

    public float BaseScale = 1;
    public float BaseOffset = 0.5f;
    public float BaseSpeed = 1.0f;
    public Vector3  BaseWeights = new Vector3(1, 1, 1);

    public float DetailNoiseScale = 1.0f;
    public float DetailOffset = 0.0f;
    public float DetailSpeed = 1.0f;
    public Vector3 DetailWeights = new Vector3(1,1, 1);

    public int LightSteps = 10;
    [Range(0, 1)]
    public float LightAbsorptionTowardSun = 1;
    [Range(0,1)]
    public float DarknessThresold = 0.5f;
    [Range(0, 1)]
    public float PhaseValue = 1;

    void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if(mat == null)
        {
        	mat = new Material(shader);
        }

        if (mat)
        {
            mat.SetVector("_BoundsMin", container.position - container.localScale / 2);
            mat.SetVector("_BoundsMax", container.position + container.localScale / 2);
            mat.SetTexture("_CloudBase", CloudBase);
            mat.SetTexture("_CloudDetail", CloudDetail);
            mat.SetFloat("_DensityThresold", DensityThresold);
            mat.SetFloat("_DensityMul", DensityMul);
            mat.SetFloat("_CloudFade", CloudFade);
            mat.SetInt("_CloudSteps", CloudSteps);
            mat.SetFloat("_TimeScale", TimeScale);

            mat.SetFloat("_BaseScale", BaseScale);
            mat.SetFloat("_BaseOffset", BaseOffset);
            mat.SetFloat("_BaseSpeed", BaseSpeed);
            mat.SetVector("_BaseWeights", BaseWeights);


            mat.SetFloat("_DetailNoiseScale", DetailNoiseScale);
            mat.SetFloat("_DetailOffset", DetailOffset);
            mat.SetFloat("_DetailSpeed", DetailSpeed);
            mat.SetVector("_DetailWeights", DetailWeights);


            mat.SetInt("_LightSteps", LightSteps);
            mat.SetFloat("_LightAbsorptionTowardSun", LightAbsorptionTowardSun);
            mat.SetFloat("_DarknessThresold", DarknessThresold);
            mat.SetFloat("_PhaseValue", PhaseValue);


            Graphics.Blit(src, dest, mat);
        }
        else{
            Graphics.Blit(src, dest);
        }
    }
}
