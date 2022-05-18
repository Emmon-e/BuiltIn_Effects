using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[ImageEffectAllowedInSceneView]
public class Atmosphere : MonoBehaviour
{
    private Shader mShader;
    private Material material;
    public Light Sun;
    [Range(0, 100.0f)]
    public float DistanceScale = 1;
    [Range(0, 10.0f)]
    public float RayleighScatterCoef = 1;
    [Range(0, 10.0f)]
    public float RayleighExtinctionCoef = 1;
    [Range(0, 10.0f)]
    public float MieScatterCoef = 1;
    [Range(0, 10.0f)]
    public float MieExtinctionCoef = 1;
    [Range(1, 128)]
    public float SampleCount = 16;
    [Range(0, 0.999f)]
    public float MieG = 0.76f;
    [ColorUsage(false, true, 0, 10, 0, 10)]
    public Color  IncomingLightColor = new Color(4, 4, 4, 4);

    //大气数据
    private const float AtmosphereHeight = 80000.0f;
    private const float PlanetRadius = 6371000.0f;
    private readonly Vector4 RayleighSct = new Vector4(5.8f, 13.5f, 33.1f, 0.0f) * 0.000001f; //瑞丽散射红绿蓝系数
    private readonly Vector4 MieSct = new Vector4(2.0f, 2.0f, 2.0f, 0.0f) * 0.00001f;//mie散射红绿蓝系数
    private readonly Vector4  DensityOfHeight = new Vector4(7994.0f, 1200.0f, 0, 0);



    // Start is called before the first frame update
    void Start()
    {
        mShader = Shader.Find("Unlit/Atmosphere");
        material = new Material(mShader);
        EnableLightShafts();
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (material)
        {
            var projectionMareix = GL.GetGPUProjectionMatrix(Camera.current.projectionMatrix, false);
            material.SetMatrix("_InverseViewMatrix", Camera.current.worldToCameraMatrix.inverse);
            material.SetMatrix("_InverseProjectionMatrix", projectionMareix.inverse);

            RenderTexture rt = RenderTexture.GetTemporary(source.width, source.height, 24);
            material.SetTexture("_MainTex", rt);
            material.SetFloat("_DistanceScale", DistanceScale);
            material.SetFloat("_SampleCount", SampleCount);
            material.SetFloat("_PlanetRadius", PlanetRadius);
            material.SetVector("_LightDir", new Vector4(Sun.transform.forward.x, Sun.transform.forward.y, Sun.transform.forward.z, 1 / (Sun.range * Sun.range)));
            material.SetVector("_DensityOfHeight", DensityOfHeight);
            material.SetFloat("_AtmosphereHeight", AtmosphereHeight);

            material.SetVector("_ScatteringR", RayleighSct * RayleighScatterCoef);
            material.SetVector("_ScatteringM", MieSct * MieScatterCoef);
            material.SetVector("_ExtinctionR", RayleighSct * RayleighExtinctionCoef);
            material.SetVector("_ExtinctionM", MieSct * MieExtinctionCoef);

            material.SetFloat("_MieG", MieG);

            material.SetColor("_IncomingLightColor", IncomingLightColor);

            Graphics.Blit(source, destination,material);

        }
        else
            Graphics.Blit(source, destination);
    }

    // shadow map
    private CommandBuffer _cascadeShadowCommandBuffer;
    public void EnableLightShafts()
    {
        if (_cascadeShadowCommandBuffer == null)
            InitializeLightShafts();

        Sun.RemoveCommandBuffer(LightEvent.AfterShadowMap, _cascadeShadowCommandBuffer);

        Sun.AddCommandBuffer(LightEvent.AfterShadowMap, _cascadeShadowCommandBuffer);
    }


    public void InitializeLightShafts()
    {
        if (_cascadeShadowCommandBuffer == null)
        {
            _cascadeShadowCommandBuffer = new CommandBuffer();
            _cascadeShadowCommandBuffer.name = "CascadeShadowCommandBuffer";
            _cascadeShadowCommandBuffer.SetGlobalTexture("_CascadeShadowMapTexture", new UnityEngine.Rendering.RenderTargetIdentifier(UnityEngine.Rendering.BuiltinRenderTextureType.CurrentActive));
        }
    }


}
