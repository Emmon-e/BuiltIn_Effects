Shader "Unlit/PlaneFur1"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap("NormalMap",2D) = "white" {}
        _BumpScale("BumpScale",Range(0.0,5.0)) = 1.0
        _AOMap("AOMap",2D) = "white" {}
        _AOIntensity("AOIntensity",Range(0.0,1.0)) = 0.5
        _BillBoarding("Billboarding",Range(0.0,1.0)) = 1.0
        _BaseColor("BaseColor",Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent"}
        LOD 100
        
        Pass 
        {
            // ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal:NORMAL;
                float4 tangent:TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD4;                
                float3 N : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _BillBoarding;
            sampler2D _NormalMap;
            sampler2D _AOMap;
            float _AOIntensity;
            half4 _BaseColor;
            float _BumpScale;
            
            
            v2f vert (appdata v)
            {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.vertex = mul(UNITY_MATRIX_VP, o.worldPos);
                o.N = v.normal;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return float4(i.N.xyz, 1.0);
            }
            ENDCG
        }
    }
}
