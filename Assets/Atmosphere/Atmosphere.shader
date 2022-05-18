Shader "Unlit/Atmosphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
		Cull Off 
		ZWrite Off
		ZTest Always

        LOD 100

        Pass
        {
            CGPROGRAM
			#pragma enable_d3d11_debug_symbols

            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
			#include "Atmosphere.cginc"

            ENDCG
        }
    }
}
