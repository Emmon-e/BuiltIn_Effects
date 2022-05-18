using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
[ExecuteInEditMode]
public class FXAA : MonoBehaviour
{
    public enum LuminanceMode {
        Alpha,
        Green,
        Calculate }
    public LuminanceMode luminanceSource;

    const int luminancePass = 0;
    const int fxaaPass = 1;

    public Shader m_shader;
    [NonSerialized]
    Material fxaa_mat;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (fxaa_mat == null)
        {
            fxaa_mat = new Material(m_shader);
            fxaa_mat.hideFlags = HideFlags.HideAndDontSave;
        }
        if(luminanceSource == LuminanceMode.Calculate)
        {
            fxaa_mat.DisableKeyword("LUMINANCE_GREEN");
            RenderTexture luminanceTex = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
            Graphics.Blit(source, luminanceTex, fxaa_mat, luminancePass);
            RenderTexture.ReleaseTemporary(luminanceTex);
        }
        else if(luminanceSource == LuminanceMode.Green)
            fxaa_mat.EnableKeyword("LUMINANCE_GREEN");
        else
            fxaa_mat.EnableKeyword("LUMINANCE_GREEN");

        Graphics.Blit(source, destination, fxaa_mat,fxaaPass);
    }
}
