Shader "Unlit/PlaneFur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        // _NormalMap("NormalMap",2D) = "white" {}
        // _BumpScale("BumpScale",Range(0.0,5.0)) = 1.0
        // _AOMap("AOMap",2D) = "white" {}
        _AOIntensity("AOIntensity",Range(0.0,1.0)) = 0.5
        _BillBoarding("Billboarding",Range(-5,5)) = 1.0
        _BaseColor("BaseColor",Color) = (1,1,1,1)
        _AOColor("AOColor",Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
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
            #include "Lighting.cginc"
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
                float4 tangent:TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 OriginalPos : TEXCOORD1;
                float3 centerOffset : TEXCOORD2;
                float4 worldPos : TEXCOORD3;
				float3 testdata : TEXCOORD4;

            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _BillBoarding;
            // sampler2D _NormalMap;
            // sampler2D _AOMap;
            float _AOIntensity;
            half4 _BaseColor;
            // float _BumpScale;
            float4 _AOColor;
            
            v2f vert (appdata v)
            {
                v2f o;
                float3 center = float3(0, 0, 0);
                float3 object_viewer = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                float3 normalDir = object_viewer - center;
                normalDir.y = (normalDir.y * _BillBoarding);
                normalDir = normalize(normalDir);
                float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                float3 rightDir = normalize(cross(normalDir, upDir));
                upDir = normalize(cross(normalDir, rightDir));
                float3 centerOffs = v.vertex.xyz - center;
                float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
                o.worldPos = mul(unity_ObjectToWorld, float4(localPos, 1.0));
                o.vertex = mul(UNITY_MATRIX_VP, o.worldPos);
                
                o.uv = TRANSFORM_TEX(v.uv , _MainTex);
                o.OriginalPos = float3(unity_ObjectToWorld[0][3], unity_ObjectToWorld[1][3], unity_ObjectToWorld[2][3]);
				o.centerOffset = centerOffs;
				o.testdata = v.normal;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {

                fixed4 col = tex2D(_MainTex, i.uv);
                col.a = col.r;
                fixed AO =col.g;
                col.rgb = lerp(_BaseColor.rgb, _AOColor ,_AOIntensity* AO);

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);

				float3 objScale = float3(unity_ObjectToWorld[0][0], unity_ObjectToWorld[1][1], unity_ObjectToWorld[2][2]);

				//圆形法线重构
                float3 curWorldPos = i.worldPos + viewDir * sqrt(max( 0.25 - dot(i.centerOffset.xy, i.centerOffset.xy) , 0.0)) * objScale;
                float3 worldNormal = normalize(curWorldPos - i.OriginalPos) ;

                float3 lightDir = normalize(UnityWorldSpaceLightDir(curWorldPos));
				float ndl = saturate(dot(worldNormal, lightDir)) *0.5 + 0.3;
				col.rgb *= ndl;
				//col.rgb = worldNormal;
				//col.a = 1.0;
                return col;
            }
            ENDCG
        }
    }
}
