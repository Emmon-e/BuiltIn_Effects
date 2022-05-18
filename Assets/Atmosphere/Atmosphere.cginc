
#define PI 3.14159265359

struct appdata
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
};

struct v2f
{
	float2 uv : TEXCOORD0;
	float4 vertex : SV_POSITION;
};

sampler2D _MainTex;
float4 _MainTex_ST;

float4x4 _InverseViewMatrix;
float4x4 _InverseProjectionMatrix;
sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_ST;
float _PlanetRadius;
//float _SunIntensity;
float3 _LightDir;
float2 _DensityOfHeight;
float _AtmosphereHeight;
float4 _ScatteringR;
float4 _ScatteringM;
float4 _ExtinctionR;
float4 _ExtinctionM;
float _SampleCount;
float _MieG;
float4 _IncomingLightColor;
float _DistanceScale;
//tonemap
float3 ACESFilm(float3 x)
{
	float a = 2.51f;
	float b = 0.03f;
	float c = 2.43f;
	float d = 0.59f;
	float e = 0.14f;
	return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}


//-----------------------------------------------------------------------------------------
// Helper Funcs 2 : ShaodwMap Funcs
//-----------------------------------------------------------------------------------------

inline fixed4 GetCascadeWeights_SplitSpheres(float3 wpos)
{
	float3 fromCenter0 = wpos.xyz - unity_ShadowSplitSpheres[0].xyz;
	float3 fromCenter1 = wpos.xyz - unity_ShadowSplitSpheres[1].xyz;
	float3 fromCenter2 = wpos.xyz - unity_ShadowSplitSpheres[2].xyz;
	float3 fromCenter3 = wpos.xyz - unity_ShadowSplitSpheres[3].xyz;
	float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));
	//#if SHADER_TARGET > 30
	fixed4 weights = float4(distances2 < unity_ShadowSplitSqRadii);
	weights.yzw = saturate(weights.yzw - weights.xyz);
	//#else
	//			fixed4 weights = float4(distances2 >= unity_ShadowSplitSqRadii);
	//#endif
	return weights;
}

inline float getShadowFade_SplitSpheres(float3 wpos)
{
	float sphereDist = distance(wpos.xyz, unity_ShadowFadeCenterAndType.xyz);
	half shadowFade = saturate(sphereDist * _LightShadowData.z + _LightShadowData.w);
	return shadowFade;
}

inline float4 GetCascadeShadowCoord(float4 wpos, fixed4 cascadeWeights)
{
	float3 sc0 = mul(unity_WorldToShadow[0], wpos).xyz;
	float3 sc1 = mul(unity_WorldToShadow[1], wpos).xyz;
	float3 sc2 = mul(unity_WorldToShadow[2], wpos).xyz;
	float3 sc3 = mul(unity_WorldToShadow[3], wpos).xyz;
	float4 shadowMapCoordinate = float4(sc0 * cascadeWeights[0] + sc1 * cascadeWeights[1] + sc2 * cascadeWeights[2] + sc3 * cascadeWeights[3], 1);
#if defined(UNITY_REVERSED_Z)
	float  noCascadeWeights = 1 - dot(cascadeWeights, float4(1, 1, 1, 1));
	shadowMapCoordinate.z += noCascadeWeights;
#endif
	return shadowMapCoordinate;
}

UNITY_DECLARE_SHADOWMAP(_CascadeShadowMapTexture);

float GetLightAttenuation(float3 wpos)
{
	float atten = 1;
	// sample cascade shadow map
	float4 cascadeWeights = GetCascadeWeights_SplitSpheres(wpos);
	bool inside = dot(cascadeWeights, float4(1, 1, 1, 1)) < 4;
	float4 samplePos = GetCascadeShadowCoord(float4(wpos, 1), cascadeWeights);

	//atten = UNITY_SAMPLE_SHADOW(_CascadeShadowMapTexture, samplePos.xyz);
	atten = inside ? UNITY_SAMPLE_SHADOW(_CascadeShadowMapTexture, samplePos.xyz) : 1.0f;
	//atten += getShadowFade_SplitSpheres(wpos);

	//atten = _LightShadowData.r + atten * (1 - _LightShadowData.r);

	return atten;
}

//-----------------------------------------------------------------------------------------
// RenderSun
//-----------------------------------------------------------------------------------------
float Sun(float cosAngle)
{
	float g = 0.98;
	float g2 = g * g;

	float sun = pow(1 - g, 2.0) / (4 * PI * pow(1.0 + g2 - 2.0*g*cosAngle, 1.5));
	sun = smoothstep(0.4,1.0, sun);
	return sun * 0.003;
}

float3 RenderSun(in float3 scatterM, float cosAngle)
{
	float sun_fac = smoothstep(0.9, 1.0, cosAngle);
	return scatterM * Sun(cosAngle) ;
}



// 计算射线与球的交点   https://matrix4f.com/Math/Geometry/line-sphere-intersection/
float2 RaySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius)
{
	float3 oc = rayOrigin - sphereCenter;
	float a = dot(rayDir, rayDir);
	float b = 2.0 * dot(oc, rayDir);
	float c = dot(oc, oc) - sphereRadius * sphereRadius;
	float d = b * b - 4 * a * c;
	if (d < 0)
		return -1;
	else
	{
		d = sqrt(d);
		return float2(-b - d, -b + d) / (2 * a);
	}
}

float3 GetWorldSpacePosition(float2 uv)
{
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	float4 viewPos = mul(_InverseProjectionMatrix, float4(2 * uv - 1, depth, 1));
	viewPos = viewPos / viewPos.w;
	float4 worldPos = mul(_InverseViewMatrix, viewPos);
	return worldPos.xyz;
}

void LightSample(float3 worldPos, float3 lightDir, float3 planetCenter,out float2 opticalDepthCP)
{
	float3 rayStart = worldPos;
	float3 rayDir = -lightDir;
	float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
	float3 rayEnd = rayStart + rayDir * intersection.y;
	float stepCount =8;
	float3 step = (rayEnd - rayStart) / stepCount;
	float stepSize = length(step);
	float2 density = 0;
	[loop]
	for (float s = 0.5; s < stepCount; s+= 1.0)
	{
		float3 nextPos = rayStart + step * s;
		float height = abs(length(nextPos.xyz - planetCenter.xyz) - _PlanetRadius);
		float perStepDensity = exp(-height.xx / _DensityOfHeight.xy);
		density += perStepDensity * stepSize;
	}
	opticalDepthCP = density;
}

//dpa dpc 光学深度
bool GetAtmosphereDensityRealtime(float3 position, float3 planetCenter, float3 lightDir, out float2 dpa, out float2 dpc)
{
	float height = length(position.xyz - planetCenter.xyz) - _PlanetRadius;
	dpa = exp(-height.xx / _DensityOfHeight.xy);
	LightSample(position, lightDir, planetCenter, dpc);
	return true;
}

//内部散射吸收
void ComputeLocalInscattering(float2 localDensity, float2 densityPA, float2 densityCP, out float3 localInscatterR, out float3 localInscatterM)
{
	float2 densityCPA = densityCP + densityPA;
	float3 tr = densityCPA.x * _ExtinctionR;
	float3 tm = densityCPA.y * _ExtinctionM;
	float3 extinction = exp(-(tr + tm));
	localInscatterR = localDensity.x * extinction;
	localInscatterM = localDensity.y * extinction;
}

//相位：散射在某个方向的占比
void ApplyPhaseFunction(inout float3 scatterR,inout float3 scatterM,float cosAngle)
{
	//Reyleigh
	float phase = (3.0 / (16.0 * PI)) * (1 + (cosAngle * cosAngle));
	scatterR *= phase;
	//Mie
	float g =  _MieG;
	float g2 = g * g;
	phase = (1.0 / (4.0 * PI)) * ((3.0 * (1.0 - g2)) / (2.0 * (2.0 + g2))) * ((1 + cosAngle * cosAngle) / (pow((1 + g2 - 2 * g * cosAngle), 3.0 / 2.0)));
	scatterM *= phase;
}

	//T(CP)T(PA) = exp(-β(入)*(Dcp + Dpa))
	// P - current integration point
	// A - camera position
	// C - top of the atmosphere
float4 IntergrateInScatteringRealtime(float3 rayStart, float3 rayDir, float rayLength, float3 planetCenter, float distanceScale, float3 lightDir, float sampleCount, inout float4 extinction)
{
	float3 step = rayDir * rayLength / sampleCount;
	float3 stepSize = length(step) * distanceScale;
	float2 densityPA = 0;
	float2 densityCP = 0;
	float3 scatterR = 0;
	float3 scatterM = 0;

	float2 localDensity = 0;
	float2 preLocalDensity = 0;
	float3 preLocalInscatterR = 0;
	float3 preLocalInscatterM = 0;

	GetAtmosphereDensityRealtime(rayStart, planetCenter, lightDir, preLocalDensity, densityCP);
	ComputeLocalInscattering(preLocalDensity, densityCP, densityPA,  preLocalInscatterR, preLocalInscatterM);

	[loop]
	for (float s = 1.0; s < sampleCount; s++)
	{
		float3 p = rayStart + step * s;
		GetAtmosphereDensityRealtime(p, planetCenter, lightDir, localDensity, densityCP);

		bool InShadow = GetLightAttenuation(p) < 0.1;
		if (!InShadow) {

			densityPA += (localDensity + preLocalDensity) * stepSize * 0.5;

			float3 localInscatterR;
			float3 localInscatterM;
			ComputeLocalInscattering(localDensity, densityCP, densityPA, localInscatterR, localInscatterM);
			scatterR +=  (localInscatterR + preLocalInscatterR) * stepSize * 0.5;
			scatterM +=  (localInscatterM + preLocalInscatterM) * stepSize * 0.5;
			preLocalInscatterR = localInscatterR;
			preLocalInscatterM = localInscatterM;
		}
		preLocalDensity = localDensity;
	}
	float m_sun = scatterM;
	ApplyPhaseFunction(scatterR, scatterM, dot(rayDir, -lightDir.xyz));

	float3 lightInscatter = (scatterR * _ScatteringR + scatterM * _ScatteringM) * _IncomingLightColor.rgb;
	lightInscatter += lightInscatter *  RenderSun(m_sun, dot(rayDir, -lightDir));

	float3 lightExtinction = exp(-(densityCP.x * _ExtinctionR + densityCP.y * _ExtinctionM));
	extinction = float4(lightExtinction, 1);
	return float4(lightInscatter,1);
}

v2f vert(appdata v)
{
	v2f o;
	o.vertex = UnityObjectToClipPos(v.vertex);
	o.uv = v.uv;
	return o;
}

fixed4 frag(v2f i) : SV_Target
{
	float deviceZ = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
	float3 worldPos = GetWorldSpacePosition(i.uv);
	float3 rayStart = _WorldSpaceCameraPos;
	float3 rayDir = worldPos - _WorldSpaceCameraPos;
	float rayLength = length(rayDir);
	rayDir /= rayLength ;

	if (deviceZ < 0.000001)
	{
		rayLength = 1e20;
	}

	float3 planetCenter = float3(0, -_PlanetRadius, 0);
	// 与地球大气做视线碰撞检测
	float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
	rayLength = min(intersection.y, rayLength);

	//落到地平线以下，需要做遮挡检测
	//intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius);
	if (intersection.x > 0)
	{
		rayLength = min(rayLength, intersection.x);
	}

	float4 extinction;
	float4 inscattering;
	float4 final;
	float4 screenCol = tex2D(_MainTex, i.uv);
	if (deviceZ < 0.00001)
	{
		 inscattering = IntergrateInScatteringRealtime(rayStart, rayDir, rayLength, planetCenter, 1, _LightDir, _SampleCount, extinction);
		final = inscattering;
	}
	else
	{
		 inscattering = IntergrateInScatteringRealtime(rayStart, rayDir, rayLength, planetCenter, _DistanceScale, _LightDir, _SampleCount, extinction);
		final = screenCol * extinction + inscattering;
	}

	final.xyz =  ACESFilm(final.xyz);
	// sun
	float3 lightpos = planetCenter + (-_LightDir)*(_PlanetRadius + _AtmosphereHeight);
	float3 p = normalize(worldPos - planetCenter);
	float pdl = dot(p, -_LightDir);

	return  final;
}