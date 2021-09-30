Shader "Unlit/Clouds"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CloudBase ("_CloudBase", 3D) = "white" {}
        _CloudDetail ("_CloudDetail", 3D) = "white" {}
		
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
			#pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
			#include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 viewDir : TEXCOORD1; 
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float2 ViewParams;
            Texture3D<float4> _CloudBase;
			SamplerState sampler_CloudBase;
            Texture3D<float4> _CloudDetail;
			SamplerState sampler_CloudDetail;
			sampler2D _CameraDepthTexture;

			float3 _BoundsMin;
            float3 _BoundsMax;
			float _DensityThresold;
			float _DensityMul;
			int _CloudSteps;		
			float _TimeScale;
			float _CloudFade;

			float _BaseScale;
			float _BaseOffset;
			float _BaseSpeed;
			float3 _BaseWeights;

			float _DetailNoiseScale;
			float _DetailOffset;
			float _DetailSpeed;
			float3 _DetailWeights;

			int _LightSteps;
			float _LightAbsorptionTowardSun;
			float _DarknessThresold;
			float _PhaseValue;


            v2f vert (appdata_img v)
            { 
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;	

				// Camera space matches OpenGL convention where cam forward is -z. In unity forward is positive z.
				float3 viewVector = mul(unity_CameraInvProjection,float4(v.texcoord *2 - 1,0,-1));
				o.viewDir = mul(unity_CameraToWorld,float4(viewVector,0));
                return o;

            }

			float remap(float v, float minOld, float maxOld, float minNew, float maxNew) {
				return minNew + (v - minOld) * (maxNew - minNew) / (maxOld - minOld);
			}

			// aabb 碰撞检测
            float2 RayBoxDist(float3 boundsMin,float3 boundsMax,float3 rayOrigin, float3 rayDir)
            {
				// Adapted from: http://jcgt.org/published/0007/03/04/
               float3 t0 = (boundsMin - rayOrigin) / rayDir;
                float3 t1 = (boundsMax - rayOrigin) / rayDir;
                float3 tmin = min(t0,t1);
                float3 tmax = max(t0,t1);
                float distA = max(max(tmin.x,tmin.y),tmin.z);
                float distB = min(min(tmax.x,tmax.y),tmax.z);
                float distToBox = max(0,distA);
                float distInsideBox = max(0,distB - distToBox);
                return float2(distToBox,distInsideBox);
            }

			float SampleDensity(float3 rayPos)
			{
				const float baseScale = 0.001;
				const float offsetSpeed = 0.01;
				float3 size = _BoundsMax - _BoundsMin;
				float3 boundsCenter = (_BoundsMax + _BoundsMin) * 0.5;
				float time = _Time.x * _TimeScale;

				// Calculate falloff at along x/z edges of the cloud container
				const float containerEdgeFadeDst = 50;
				float dstFromEdgeX = min(containerEdgeFadeDst, min(rayPos.x - _BoundsMin.x, _BoundsMax.x - rayPos.x));
				float dstFromEdgeZ = min(containerEdgeFadeDst, min(rayPos.z - _BoundsMin.z, _BoundsMax.z - rayPos.z));
				float edgeWeight = min(dstFromEdgeZ, dstFromEdgeX) / containerEdgeFadeDst;
				//Calculate height gradient
				float gMin = .2;
				float gMax = .7;
				float heightPercent = (rayPos.y - _BoundsMin.y) / size.y;
				float heightGradient = saturate(remap(heightPercent, 0.0, gMin, 0, 1)) * saturate(remap(heightPercent, 1, gMax, 0, 1));
				heightGradient *= edgeWeight;

				float3 uvw = rayPos  * _BaseScale * baseScale + _BaseOffset  + float3(time,time * 0.1,time * 0.2) * _BaseSpeed;
				float4 baseNoise = _CloudBase.SampleLevel(sampler_CloudBase,uvw,0);
				float3 baseWeights = normalize(_BaseWeights);
				float baseFBM = dot(baseWeights, baseNoise) * heightGradient;
				float baseShapeDensity = baseFBM + _DensityThresold;
				if (baseShapeDensity > 0)
				{
					float3 detail_uvw = rayPos * _DetailNoiseScale * baseScale + _DetailOffset * offsetSpeed + float3(time * 0.4, -time,time * 0.1) *_DetailSpeed ;
					float4 detailNoise = _CloudDetail.SampleLevel(sampler_CloudDetail, detail_uvw, 0);
					float detailWeights = normalize(_DetailWeights);
					// 分型布朗运动
					float detailFBM = dot(detailWeights, detailNoise);

					float oneMinusShape = 1 - baseFBM;
					float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
					float cloudDensity = baseShapeDensity - (1 - detailFBM) * detailErodeWeight * _DetailWeights;

					return  cloudDensity * _DensityMul;

				}
				return 0;
			}

			float LightMarch(float3 rayOrigin)
			{
				float3 lightDir = WorldSpaceLightDir(float4(rayOrigin,1.0));// _WorldSpaceLightPos0.xyz;
				float distInsideBox = RayBoxDist(_BoundsMin, _BoundsMax, rayOrigin, lightDir).y;
				float stepSize = distInsideBox / _LightSteps;
				float totalDensity = 0;
				for (int step = 0; step < _LightSteps; step++)
				{
					float3 nextPos = rayOrigin + lightDir * stepSize;
					totalDensity += max(0, SampleDensity(nextPos) *stepSize);
				}
				float transmittance = exp(-totalDensity * _LightAbsorptionTowardSun);
				return _DarknessThresold + transmittance * (1 - _DarknessThresold);
			}

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
				float3 rayOrigin = _WorldSpaceCameraPos;
				float3 rayDir = normalize(i.viewDir);
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,i.uv);
				float eyeDepth = LinearEyeDepth( depth) * length(i.viewDir);
				float depth01 = Linear01Depth(depth);
				float2 rayInfo = RayBoxDist(_BoundsMin,_BoundsMax,rayOrigin,rayDir);
				float disToBox = rayInfo.x;
				float disInsideBox = rayInfo.y;

				float curDis = 0;
				float stepSize = rayInfo.y / _CloudSteps;
				float disLimit = min(eyeDepth - disToBox, disInsideBox);
				float lightEnergy = 0;
				float transmittance = 1;
				while (curDis < disLimit)
				{
					float3 rayPos = rayOrigin + rayDir * (disToBox + curDis);
					float density = SampleDensity(rayPos) * stepSize;
					if (density > 0)
					{
						float lightTransmittance = LightMarch(rayPos);
						lightEnergy += lightTransmittance * density * stepSize * transmittance * _PhaseValue;
						transmittance *= exp(-density * stepSize * _LightAbsorptionTowardSun);
						if (transmittance < 0.01)
							break;
					}
					curDis += stepSize;
				}
				float horizon =abs( rayDir.y) /_CloudFade;
				horizon = pow(horizon, 4);
				horizon = max(exp(-2.5 * horizon), 0.0) ;

				float3 cloudCol = lightEnergy * _LightColor0.rgb;
				float3 final =  col.rgb * transmittance  + cloudCol ;
				//final = lerp(final, col.rgb, horizon);
				return float4(final, 0);

            }
            ENDCG
        }
    }
}
