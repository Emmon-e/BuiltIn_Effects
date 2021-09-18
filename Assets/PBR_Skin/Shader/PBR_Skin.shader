Shader "Custom/PBR_Skin"
{
    Properties
    {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}


		_BaseNormal("BaseNormal",2D) = "white" {}
		_BaseNormalIntensity("BaseNormalIntensity",Range(0,1)) = 0.5

		_DetailNormal("DetailNormal",2D) = "white" {}
		_DetailMaskMap("DetailMaskMap",2D) = "white" {}
		_DetailNormalScale("DetailNormalScale",Range(0,5)) = 1
		_DetailNormalIntensity("DetaiNormalIntensity",Range(0,3)) = 0.5

		_ConcaveMap("ConcaveMap",2D) = "white" {}
		_ConcaveInyensity("ConcaveIntensity",Range(0,1)) = 0.5
		
		_RoughnessMap("RoughnessMap",2D) = "white" {}
		_Smoothness("Smoothness",Range(0,2)) = 0.3

		_ThicknessMap("ThicknessMap",2D) = "white" {}
		_Thickness("Thickness", Range(0, 1)) = 0.5

		_LUTMap("LUT Map", 2D) = "white" {}

        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullfor?wardshadows
		//#pragma surface surf CustomShading
        #pragma target 3.0

        sampler2D _MainTex;
        struct Input
        {
            float2 uv_MainTex;
			float3 worldNormal;
			float3 worldPos;
			INTERNAL_DATA
        };
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

        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

		void vert(inout appdata_tan v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
		}

		float3 BlendNormal(float3 N1, float3 N2)
		{
			float3 ret = normalize(float3(N1.xy + N2.xy, N1.z));
			return ret * 0.5 + 0.5;
		}

		//fixed3 LightingCustomShading(SurfaceOutputStandard s, float3 lightDir, float atten)
		//{
		//	fixed4 col;

		//}

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
			float3 baseNormal = tex2D(_BaseNormal, IN.uv_MainTex) * 2 - 1;
			baseNormal.xy *= _BaseNormalIntensity;
			baseNormal.z = sqrt(1 - dot(baseNormal.xy,baseNormal.xy));

			float3 detailNormal = tex2D(_DetailNormal, IN.uv_MainTex * _DetailNormalScale) * 2 - 1;
			detailNormal.xy *= _DetailNormalIntensity;
			detailNormal.z = sqrt(1 - dot(detailNormal.xy, detailNormal.xy));
			float detailMask = tex2D(_DetailMaskMap, IN.uv_MainTex).r;
			detailNormal *= detailMask;
			float3 blendNormal = BlendNormal(baseNormal, detailNormal);
			//float3 worldNormal = WorldNormalVector(IN,blendNormal);

			float roughness = tex2D(_RoughnessMap, IN.uv_MainTex).r;
			float AO = tex2D(_ConcaveMap, IN.uv_MainTex).r ;
			AO = lerp(1, AO, _ConcaveInyensity) ;

			// curvature_y
			//float detailWorldNormal = length(fwidth(worldNormal));
			//float detailWorldPos = length(fwidth(IN.worldPos.xyz));
			//float curvature = detailWorldNormal / detailWorldPos;
			//// curvature_x
			//float halfLamb = dot(worldNormal, lightDir) * 0.5 + 0.5;

			//fixed3 SSS = tex2D(_LUTMap, float2(halfLamb, curvature)).rgb;

			o.Normal = blendNormal;
			o.Albedo =  c.rgb ;
            o.Metallic = _Metallic;
			o.Smoothness = (1 - roughness) * _Smoothness;
            o.Alpha = c.a;
			o.Occlusion = AO;
        }
        ENDCG
    }
    FallBack "Diffuse"
}


//	struct SurfaceOutputStandard
//{
//	fixed3 Albedo;      // base (diffuse or specular) color
//	float3 Normal;      // tangent space normal, if written
//	half3 Emission;
//	half Metallic;      // 0=non-metal, 1=metal
//	// Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
//	// Everywhere in the code you meet smoothness it is perceptual smoothness
//	half Smoothness;    // 0=rough, 1=smooth
//	half Occlusion;     // occlusion (default 1)
//	fixed Alpha;        // alpha for transparencies
//};