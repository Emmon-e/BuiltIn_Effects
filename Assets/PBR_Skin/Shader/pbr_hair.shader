Shader "Unlit/pbr_hair"
{
    Properties
    {
		_MainTex("Texture", 2D) = "white" {}
		_NoiseTex("NoiseTex", 2D) = "white" {}
		_AOIntensity("AOIntensity",Range(0,5)) = 1

		_HairColor1("BaseColor",Color) = (1,1,1,1)

		_HairMask("HairMask",2D) = "white" {}
		_AlphaCut("AlphaCut",Range(0,1)) = 0.2
		_AlphaBlend("AlphaBlend",Range(0,1)) = 0.8
		_Shift1("Shift1",Range(-1,1)) = 0.2
		_Shift2("Shift2",Range(-1,1)) = 0.4
		_Pow1("Pow1",Range(0,500)) = 2
		_Pow2("Pow2",Range(0,500)) = 1
		_SpecIntensity1("SpecIntensity1",Range(0,1)) = 1
		_SpecIntensity2("SpecIntensity2",Range(0,1)) = 1
		_HairColor2("HairColor2",Color) = (1,1,1,1)
		_HairColor3("HairColor3",Color) = (1,1,1,1)
	}
		SubShader
		{
			Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "IgnoreProjector" = "True" }

			LOD 100
			CGINCLUDE
			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal: NORMAL;
				float4 tangent:TANGENT;
			};

			struct v2f
			{
				float4 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float3 worldTangent: TEXCOORD3;
				float3 worldBinormal: TEXCOORD4;
			};
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _NoiseTex;
			float4 _NoiseTex_ST;

			float _AlphaCut;
			half _AlphaBlend;
			sampler2D _HairMask;
			half _AOIntensity;
			half4 _HairColor1;
			half4 _HairColor2;
			half4 _HairColor3;
			half _Shift1;
			half _Shift2;
			half _Pow1;
			half _Pow2;
			half _SpecIntensity1;
			half _SpecIntensity2;

			inline float3 ShiftTangent(float3 T, float3 N, float shift)
			{
				return normalize(T + shift * N);
			}

			inline float3 StrandSpecular(float3 T, float3 V, float3 L, float exp, float intensity)
			{
				float3 H = normalize(V + L);
				float tdh = dot(T, H);
				float sinTH = sqrt(1 - tdh * tdh);
				float dirAtten = smoothstep(-1.0, 0, tdh);
				return dirAtten * pow(sinTH, exp) * intensity;

			}


			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);

				return o;
			}
			fixed4 frag(v2f i) : SV_Target
			{
				fixed alpha = tex2D(_HairMask,i.uv.xy).r;
				clip(alpha - _AlphaCut);

				return fixed4(_HairColor1.rgb, 1);
			}

			v2f vert2(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv, _NoiseTex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldTangent = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent));
				o.worldBinormal = normalize(cross(o.worldNormal, o.worldTangent)) * v.tangent.w;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}
			fixed4 frag2(v2f i) : SV_Target
			{
				float3 worldNormal = normalize(i.worldNormal);
				float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed noise = tex2D(_NoiseTex, i.uv.zw).r;
				float3 T1 = ShiftTangent(i.worldBinormal, worldNormal,_Shift1 + noise);
				float3 T2 = ShiftTangent(i.worldBinormal, worldNormal, _Shift2 + noise);
				fixed3 spec1 = StrandSpecular(T1, viewDir, lightDir, _Pow1, _SpecIntensity1);
				fixed3 spec2 = StrandSpecular(T2,viewDir, lightDir,_Pow2, _SpecIntensity2);
				fixed3 spec = spec1 * _HairColor2.rgb + spec2 * _HairColor3.rgb;
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * _HairColor1.rgb;
				fixed3 diffuse = _LightColor0.rgb * _HairColor1.rgb * max(0, dot(worldNormal, lightDir));
				diffuse += ambient;
				diffuse *= pow(noise ,_AOIntensity);// lerp(diffuse, diffuse * AO, _AOIntensity);
				fixed mask = tex2D(_HairMask,i.uv);
				return fixed4(diffuse + spec, mask * _AlphaBlend);
			}

			ENDCG

		// pass1 写深度不输出颜色，处理alphatest
		Pass
		{
			ZWrite On
			//ColorMask 0
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			ENDCG
		}
		
		// pass2 正常计算光照
		Pass{
				Tags{ "LightMode" = "ForwardBase" }
				Cull Off
				ZWrite Off
				Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert2
			#pragma fragment frag2
			ENDCG

		}
    }
}
