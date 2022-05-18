Shader "Unlit/toon_face"
{
    Properties
    {
		_MainTex("Texture", 2D) = "white" {}
		_ShadowMap ("_ShadowMap", 2D) = "white" {}
		_FaceLightOffset("_FaceLightOffset",Range(-1,1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
			#pragma enable_d3d11_debug_symbols

            #include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				float4 worldPos: TEXCOORD2;
				float3 worldNormal : TEXCOORD3;
            };

            sampler2D _MainTex;
			sampler2D _ShadowMap;
            float4 _MainTex_ST;
			float _FaceLightOffset;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld,v.vertex);
				o.worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));// UnityObjectToWorldNormal(v.normal);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
			   fixed4 col = tex2D(_MainTex, i.uv);
			   fixed lightMap = tex2D(_ShadowMap, i.uv).r;

			   float3 lightDir =  -normalize(UnityWorldSpaceLightDir(i.worldPos.xyz).xyz);
			float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos.xyz));
			float3 worldNormal = normalize(i.worldNormal);
			float ndl = dot(lightDir, worldNormal);
			ndl = step(0.2, ndl);


			float4 forward = mul(unity_ObjectToWorld,float4(0,0,1,0));
			float4 right = mul(unity_ObjectToWorld,float4(1,0,0,0));
			float4 up = mul(unity_ObjectToWorld,float4(0,1,0,0));
			float4 left = -right;

			//float3 up = float3(0, 1, 0);
			//float3 forward = float3(0, 0, -1);
			//float3 left = cross(up, forward);
			//float3  right = -left;

			float FL = dot(forward.xz, lightDir.xz);
			float LL = dot(left.xz, lightDir.xz);
			float RL = dot(right.xz, lightDir.xz);
			float faceLight = lightMap + _FaceLightOffset;
			float ramp = (FL > 0) * min((faceLight > LL), (faceLight + RL < 1));
			col.rgb = lerp(col.rgb * 0.5, col.rgb, ramp);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
             return col;
            }
            ENDCG
        }
    }
}
