Shader "Unlit/PBR_Skin"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_BaseNormal("BaseNormal",2D) = "white" {}
		_BaseNormalIntensity("BaseNormalIntensity",Range(0,1)) = 0.5

		_DetailNormal("DetailNormal",2D) = "white" {}
		_DetailMaskMap("DetailMaskMap",2D) = "white" {}
		_DetailNormalScale("DetailNormalScale",Range(0,5)) = 1
		_DetailNormalIntensity("DetaiNormalIntensity",Range(0,3)) = 0.5

		_ConcaveMap("ConcaveMap",2D) = "white" {}
		_ConcaveInyensity("ConcaveIntensity",Range(0,2)) = 0.5

		_RoughnessMap("RoughnessMap",2D) = "white" {}
		_Smoothness("Smoothness",Range(0,2)) = 0.3

		_ThicknessMap("ThicknessMap",2D) = "white" {}
		_Thickness("Thickness", Range(0, 1)) = 0.5

		_LUTMap("LUT Map", 2D) = "white" {}
		_SSSIntensity("SSSIntensity",Range(0,3)) = 0.5

		_Metallic("Metallic", Range(0,1)) = 0.0
		_Emission("Emission",Color) = (0,0,0,1)

	}
		SubShader
		{
			Tags { "RenderType" = "Opaque"  }
		
			Pass
			{
				Tags { "LightMode" = "ForwardBase"}

				CGPROGRAM
				#pragma enable_d3d11_debug_symbols
				#pragma vertex vert
				#pragma fragment frag
				#pragma target 3.0
				#pragma multi_compile_fog
				#pragma multi_compile_fwdbase

				#include "UnityCG.cginc"
				#include "Lighting.cginc"
				#include "UnityPBSLighting.cginc"
				#include "AutoLight.cginc"
				#include "myBXDF.cginc"

				struct v2f
				{
					float4 pos : SV_POSITION;
					float2 uv : TEXCOORD0;
					float4 t2w0: TEXCOORD1;
					float4 t2w1: TEXCOORD2;
					float4 t2w2: TEXCOORD3;

					UNITY_FOG_COORDS(4)//
						UNITY_SHADOW_COORDS(5)//
				#if UNITY_SHOULD_SAMPLE_SH
					half3 sh: TEXCOORD6;
				#endif

				};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				sampler2D _BaseNormal;
				half _BaseNormalIntensity;
				sampler2D _DetailNormal;
				sampler2D _DetailMaskMap;
				half _DetailNormalScale;
				half _DetailNormalIntensity;
				sampler2D _RoughnessMap;
				sampler2D _ConcaveMap;
				half _ConcaveInyensity;
				sampler2D _ThicknessMap;
				half _Thickness;
				sampler2D _LUTMap;
				half _Metallic;
				half _Smoothness;
				half4 _Emission;
				half _SSSIntensity;
			inline float3 BlendNormal(float3 N1, float3 N2)
				{
					float3 ret = normalize(float3(N1.xy + N2.xy, N1.z ));
					return ret*0.5 + 0.5;
				}

				v2f vert(appdata_full v)
				{
					v2f o;
					UNITY_INITIALIZE_OUTPUT(v2f, o);
					o.pos = UnityObjectToClipPos(v.vertex);
					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
					float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

					float3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));
					float3 worldTangent = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent));
					float3 worldBinormal = normalize(cross(worldNormal, worldTangent)) * v.tangent.w * unity_WorldTransformParams.w; //unity_WorldTransformParams.w判定模型是否有变形翻转。
					o.t2w0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
					o.t2w1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
					o.t2w2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
					// sh ambient
					#ifndef LIGHTMAP_ON
						#if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
								o.sh = 0;
							#ifdef VERTEXLIGHT_ON
								o.sh += Shade4PointLights(
									unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
									unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
									unity_4LightAtten0, worldPos, worldNormal);
							#endif
								o.sh = ShadeSHPerVertex(worldNormal, o.sh);
						#endif
					#endif
					UNITY_TRANSFER_LIGHTING(o, v.texcoord1.xy);
					UNITY_TRANSFER_FOG(o, o.pos); 
					return o;
				}

				fixed4 frag(v2f i) : SV_Target
				{
					float3  baseNormal = UnpackNormal(tex2D(_BaseNormal, i.uv));
					baseNormal.xy *= _BaseNormalIntensity;
					baseNormal.z = sqrt(1 - min(1.0, dot(baseNormal.xy, baseNormal.xy)));

					float3 detailNormal = UnpackNormal(tex2D(_DetailNormal, i.uv * _DetailNormalScale));
					detailNormal.xy *= _DetailNormalIntensity;
					detailNormal.z = sqrt(1 - min(1.0,dot(detailNormal.xy, detailNormal.xy)));

					float detailMask = tex2D(_DetailMaskMap, i.uv).r;
					detailNormal = lerp(baseNormal, detailNormal, detailMask);
					float3 blendNormal = BlendNormal(baseNormal, detailNormal);

					float3 worldNormal = float3(dot(i.t2w0, blendNormal), dot(i.t2w1, blendNormal), dot(i.t2w2, blendNormal));
					worldNormal = normalize(worldNormal);
					float3 worldPos = float3(i.t2w0.w, i.t2w1.w, i.t2w2.w);
					float3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));// normalize(_WorldSpaceCameraPos.xyz - worldPos.xyz);
					float3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));// normalize(_WorldSpaceLightPos0.xyz - worldPos.xyz);

					// Thickness
					half thickness = tex2D(_ThicknessMap, i.uv).r;

					//sss
					float ddWorldNormal = length(fwidth(worldNormal));
					float ddWorldPos = length(fwidth(worldPos));
					float curvature = ddWorldNormal / ddWorldPos;
					float halfLamb = dot(worldNormal, lightDir) *0.5 + 0.5;
					half3 sssColor = tex2D(_LUTMap, float2(halfLamb, curvature)) ;

					SurfaceOutputStandard o;
					UNITY_INITIALIZE_OUTPUT(SurfaceOutputStandard, o);
					fixed4 Albedo = tex2D(_MainTex, i.uv);
					float roughness = tex2D(_RoughnessMap, i.uv).r;
					float AO = tex2D(_ConcaveMap,i.uv).r;
					AO = lerp(1, AO, _ConcaveInyensity);

					o.Albedo = lerp(Albedo, Albedo.rgb * sssColor, _SSSIntensity);
					o.Emission = _Emission.rgb;
					o.Normal = worldNormal;
					o.Metallic = _Metallic;
					o.Smoothness = (1 - roughness) * _Smoothness;
					o.Alpha = Albedo.a;
					o.Occlusion = AO;

					// light atten
					UNITY_LIGHT_ATTENUATION(atten, i, worldPos);
					UnityGI gi;
					UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
					gi.indirect.diffuse = 0;
					gi.indirect.specular = 0;
					gi.light.color = _LightColor0.rgb;
					gi.light.dir = lightDir;

					UnityGIInput giInput;
					UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
					giInput.light = gi.light;
					giInput.worldPos = worldPos;
					giInput.worldViewDir = viewDir;
					giInput.atten = atten;
					// ambient reflection
					#if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
						giInput.ambient = i.sh;
					#else
						giInput.ambient.rgb = 0.0;
					#endif

					giInput.probeHDR[0] = unity_SpecCube0_HDR;
					giInput.probeHDR[1] = unity_SpecCube1_HDR;
					#if defined (UNITY_SPECCUBE_BLENDING) || defined (UNITY_SPECCUBE_BOX_PROJECTION)
					giInput.boxMin[0] = unity_SpecCube0_BoxMin;
					#endif
					#ifdef UNITY_SPECCUBE_BOX_PROJECTION
						giInput.boxMax[0] = unity_SpecCube0_BoxMax;
						giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
						giInput.boxMax[1] = unity_SpecCube1_BoxMax;
						giInput.boxMin[1] = unity_SpecCube1_BoxMin;
						giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
					#endif
						LightingStandard_GI(o, giInput, gi);
						fixed4 c = 0;
						c += LightingSkinShadingMode(o, viewDir, gi);//PBS
						UNITY_EXTRACT_FOG(i);
						UNITY_APPLY_FOG(_unity_fogCoord, c);
					return c;
				}
				ENDCG
			}
		}
		FallBack "Diffuse"
}
