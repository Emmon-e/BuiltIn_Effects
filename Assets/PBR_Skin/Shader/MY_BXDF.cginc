#ifndef MY_BRDF_CGINCLUDE
#define _MY_BRDF_CGINCLUDE

inline float3 m_SafeNormalize(float3 Vec)
{
	float3 dp3 = max(0.001, dot(vec, vec));
	return vec * rsqrt(dp3); // rsqrt-> 1 / sqrt(x)
}

inline  half3 m_SchlickFresnel(half3 F0, half cosA)
{
	half t = Pow5(1 - cosA);
	return F0 + (1 - F0) * t;
}

inline half3 m_SchlickFresnelLerp(half3 F0, half3 F90, half cosA)
{
	half t = Pow5(1 - cosA);
	return lerp(F0, F90, t);
}

float m_GGX(float ndh, float roughness)
{
	float a2 = roughness * roughness;
	float d = (ndh * a2 - ndh) * ndh + 1.0f;
	return UNITY_INV_PI * a2 / (d* d + 0.0000001);
}

float m_SmithJointGGX(float ndl, float ndv, float roughness)
{
	float a = roughness;
	float lambdaV = ndl * (ndv * (1 - a) + a);
	float lambdaL = ndv * (ndl * (1 - a) + a);
#if defined(SHADER_API_SWITCH)
	return 0.5f / (lambdaV + lambdaL + 1e-4f); // work-around against hlslcc rounding error
#else
	return 0.5f / (lambdaV + lambdaL + 1e-5f);
#endif
}

half4 MyBRDF(half3 diffuseColor, half3 specularColor, half oneMinusReflectivity, half smoothness, float3 normal, float3 viewDir, UnityLight light, UnityIndirect gi)
{
	float roughness = 1 - smoothness;
	float3 halfDir = Unity_SafeNormalize(light.dir.xyz + viewDir); // Unity_SafeNormalize --> float dp3 = max(0.001f, dot(inVec, inVec)); return inVec * rsqrt(dp3);

	   // 1、要避免dot(normal,viewDir)为负。但透视视角和法线贴图映射时有可能出现这种为负情况。
		// 2、解决这个问题提供了两种方案。1>把法线扭到偏向摄影机方向再做点积计算（准确但耗性能）2>直接对点积取绝对值（不完全准确，但效果可接受，省性能）
#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0//默认情况下走方法2，假如要走方法1需要注释此行

#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV//方法1
	half shiftAmount = dot(normal, viewDir);
	normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
	float nv = saturate(dot(normal, viewDir)); // TODO: this saturate should no be necessary here
#else//方法2，默认走此方法
	half nv = abs(dot(normal, viewDir));    // This abs allow to limit artifact
#endif

	half ndl = saturate(dot(normal, light.dir));
	float ndh = saturate(dot(normal, halfDir));
	half vdl = saturate(dot(light.dir, viewDir));
	half hdl = saturate(dot(light.dir, halfDir));

	half diffuseTerm = DisneyDiffuse(ndv, ndl, hdl, roughness) * nl;  //迪士尼的漫反射计算没有除以PI， 正常是要除的，这里是因为要兼容非重要灯光及旧效果
	float roughness2 = roughness * roughness;

#if UNITY_BRDF_GGX
	roughness2 = max(0.002, roughness2);
	float D = m_GGX(ndh, roughness2);
	float G = m_SmithJointGGX(ndl, ndv, roughness2);
	float specularTerm = V * D * UNITY_PI;

#ifdef UNITY_COLORSPACE_GAMMA // 忽略Gama
	specularTerm = sqrt(max(1e-4h, specularTerm));
#endif
	specularTerm = max(0, specularTerm * ndl);
#if defined(_SPECULARHIGHLIGHTS_OFF)// 材质面板中的specular Highlight开关
	specularTerm = 0.0;
#endif
	// 根据粗糙度减弱反射量
	half surfaceReduction;
#ifdef UNITY_COLORSPACE_GAMMA // 忽略Gama
	surfaceReduction = 1.0 - 0.28 * roughness2 * roughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
#else
	surfaceReduction = 1.0 / (roughness2 * roughness2 + 1.0);  
#endif
	specularTerm *= any(specularColor) ? 1.0 : 0.0; // any() 检查是否所有分量为0
	half grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity)); //掠射角度下的反射颜色
	half3 diffuseResult = diffuseColor * (gi.diffuse + light.color * diffuseTerm);
	half3 specularResult = specularTerm * light.color * m_SchlickFresnel(specularColor, hdl) + surfaceReduction * gi.specular * m_SchlickFresnelLerp(specularColor, grazingTerm, ndv);
	return half4(diffuseResult + specularResult, 1);

}


inline half4 LightingMyShadingMode(SurfaceOutputStandard s, float3 viewDir, UnityGI gi)
{
	s.Normal = normalize(s.Normal);
	
	half oneMinusReflectivity;// 漫反射系数（Albedo中参与漫反射的比例）
	half3 specularColor;
	half3 s.Albedo = DiffuseAndSpecularFromMetallic(s.Albedo, s.Metallic, specularColor, oneMinusReflectivity); // UnityStandardUtils.cginc 
	
	half outAlpha;
	s.Albedo = PreMultiplyAlpha(s.Albedo, s.Alpha, oneMinusReflectivity, outAlpha);// 根据金属度处理Alpha混和
	half col = MyBRDF(s.Albedo, specularColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
	
	c.a = outAlpha;
	return c;

}

#endif
