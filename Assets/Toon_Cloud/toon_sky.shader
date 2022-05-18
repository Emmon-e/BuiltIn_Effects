Shader "Unlit/toon_sky"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

		[Header(Sky Color)]
		_DayTopColor("DayTopColor",Color) = (1,1,1,1)
		_DayBottomColor("DayBottomColor",Color) = (1,1,1,1)
		_NightTopColor("NightTopColor",Color) = (1,1,1,1)
		_NightBottomColor("NightBottomColor",Color) = (1,1,1,1)

		[Header(Sky Color)]
		_SunRadius("SunRadius",Range(0,1)) = 0.05
		_SunColor("SunColor",Color) = (1,1,1,1)
		_MoonColor("MoonColor",Color) = (1,1,1,1)
		_MoonShape("MoonShape",Vector) = (-0.02, 0.01, 0, 0)
		[Header(Cloud)]
		_CloudTex("CloudTex", 2D) = "white" {}
		_CloudDensity("CloudDensity",Range(0,1)) = 0.2
		_CloudThreshold("CloudThreshold",Range(0,1.0)) = 0.5
		_CloudSpeed("CloudSpeed",float) = 0.5
		_CloudDir("MoveDir",Vector) = (1.0,1.0,0.0,0.0)
		_CloudDetailTex("CloudDetailTex", 2D) = "white" {}
		_CloudDetailSpeed("CloudDetailSpeed",float) = 0.8
		_CloudDetailDensity("CloudDetailDensity",float) = 1.0
		_CloudDetaiThreshold("CloudDetaiThreshold",Range(0,1)) = 0.2
		_CloudEdgeWidth("CloudEdgeWidth",Range(0,1)) = 0.1
		_CloudRotate("CloudRotate",Range(0,360)) = 0
		[HDR]_CloudBaseColor("CloudBaseColor",Color) = (1,1,1,1)
		[HDR]_CloudAmbientColor("CloudAmbientColor",Color) = (0.5,0.5,0.5,1)
		//_CloudShadowColor("CloudShadowColor",Color) = (0.1,0.1,0.1,1)
		

	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 100

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				// make fog work
				#pragma multi_compile_fog
				//#pragma enable_d3d11_debug_symbols

				#include "UnityCG.cginc"
				#include "toon_sky.cginc"
				
				const float unity_PI = 3.14159265;

			float4 _DayTopColor;
			float4 _DayBottomColor;
			float4 _NightTopColor;
			float4 _NightBottomColor;

			float _SunRadius;
			float4 _SunColor;
			float4 _MoonColor;
			float4 _MoonShape;

			sampler2D _CloudTex;

			sampler2D _CloudDetailTex;
			float _CloudDensity;
			float _CloudThreshold;
			float _CloudSpeed;
			float2 _CloudDir;
			float _CloudDetailSpeed;
			float _CloudDetailDensity;
			float _CloudDetaiThreshold;
			float _CloudEdgeWidth;
			float _CloudRotate;
			float4 _CloudBaseColor;
			float4 _CloudAmbientColor;
			//float4 _CloudShadowColor;


			struct appdata
			{
				float4 vertex : POSITION;
				float3 uv : TEXCOORD0;
			};

			struct v2f
			{
				float3 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 worldPos : TEXCOORD1;
			};

			float2 RotateUV(float2 uv,float x)
			{
				float2 center = float2(0.5, 0.5);
				float2 new_uv = uv - center;
				float cosx = cos(x);
				float sinx = sin(x);
				float2x2 rot = float2x2(cosx, -sinx, sinx, cosx);
				new_uv =mul(rot, new_uv);
				new_uv += center;
				return new_uv ;
			}

			inline float Remap(float val, float oldmin, float oldmax, float newmin, float newmax)
			{
				return (val - oldmin) / (oldmax - oldmin) * (newmax - newmin) + newmin;
			}

			inline float HGPhase(float g, float negLdotV)
			{
				float g2 = g * g;
				return (1 - g2) / (4 * unity_PI * pow(1 + g2 - 2 * g * negLdotV, 1.5));
			}

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				return o;
			}

			fixed4 frag(v2f i) :SV_Target
			{
				//sky color
				float3 dayColor = lerp(_DayBottomColor.rgb, _DayTopColor.rgb, saturate(i.uv.y));
				float3 nightColor = lerp(_NightBottomColor.rgb, _NightTopColor.rgb, saturate(i.uv.y));
				float3 skyColor = lerp(nightColor, dayColor, saturate(_WorldSpaceLightPos0.y));

				//sun and moon
				float sun = distance(i.uv.xyz, _WorldSpaceLightPos0);
				sun = 1 - (sun / _SunRadius);
				sun = saturate(sun * 20);

				float moon_mask = distance(i.uv.xyz, -_WorldSpaceLightPos0);
				moon_mask = 1 - (moon_mask / _SunRadius);
				moon_mask = saturate(moon_mask * 20);

				float3 moonUV = i.uv.xyz;
				float moon = distance(moonUV + _MoonShape.xy, -_WorldSpaceLightPos0);
				moon = 1 - (moon / _SunRadius);
				moon = saturate(moon * 20);
				moon = max(moon - moon_mask,0);

				float change = saturate( _WorldSpaceLightPos0.y);
				float3 sun_moon = lerp(moon * _MoonColor.rgb, sun * _SunColor.rgb, change);

				//light path
				float2 skyUV = i.worldPos.xz/ clamp(i.worldPos.y, 0, 10000);
				skyUV = RotateUV(skyUV, _CloudRotate);
				float2 sunDir = _WorldSpaceLightPos0.xz;
				float2 cloudBaseSpeed = _CloudSpeed * _Time.y * _CloudDir;
				float4 noise = tex2D(_CloudTex, skyUV * _CloudDensity + cloudBaseSpeed);
				float4 Rweight = lerp(float4(0, 0, 0, 1), float4(1, 0, 0, 0), sunDir.x);
				float4 Gweight = lerp(float4(0, 0, 1, 0), float4(0, 1, 0, 0), sunDir.x);
				float4 Bweight = lerp(float4(0, 1, 0, 0), float4(0, 0, 1, 0), sunDir.x);
				float4 Aweight = lerp(float4(1, 0, 0, 0), float4(0, 0, 0, 1), sunDir.x);
				float4 lightDis = noise.r * Rweight +noise.g * Gweight + noise.b * Bweight + noise.a * Aweight;

				float4 noise2 = tex2D(_CloudTex, skyUV.yx * _CloudDensity + cloudBaseSpeed);
				float4 Rweight2 = lerp(float4(0, 0, 0, 1), float4(1, 0, 0, 0), sunDir.y);
				float4 Gweight2 = lerp(float4(0, 0, 1, 0), float4(0, 1, 0, 0), sunDir.y);
				float4 Bweight2 = lerp(float4(0, 1, 0, 0), float4(0, 0, 1, 0), sunDir.y);
				float4 Aweight2 = lerp(float4(1, 0, 0, 0), float4(0, 0, 0, 1), sunDir.y);
				float4 lightDis2 = noise2.r * Rweight2 + noise2.g * Gweight2 + noise2.b * Bweight2 + noise2.a * Aweight2;

				float4 totallightDis = (lightDis + lightDis2) * 0.5;

				// cloud shape
				float detail = tex2D(_CloudDetailTex, skyUV * _CloudDetailDensity + _CloudDetailSpeed * _Time.y).r;
				detail = smoothstep(_CloudDetaiThreshold, 1.0, detail);
				detail = Remap(detail, 0, 1, 0.0, 1.0);

				float thickness = dot(totallightDis.g, 0.25);
				thickness = smoothstep(_CloudThreshold, 1.0, thickness);
				thickness = 1 - exp(-thickness * 32);
				float oneMinus = pow((1 - thickness), 2);
				thickness = thickness - oneMinus * (1 - detail) ;
				thickness = (thickness - _CloudThreshold) / _CloudEdgeWidth;
				thickness = clamp(thickness, 0, 1);

				// cloud color
				float base = (totallightDis.g - _CloudThreshold) / _CloudEdgeWidth;
				base = clamp(base, 0, 1);

				float ambient = (totallightDis.b - _CloudThreshold -0.01 ) / _CloudEdgeWidth;
				ambient = clamp(ambient, 0, 1);
				float shadow = (totallightDis.a - _CloudThreshold - 0.08) / _CloudEdgeWidth;
				shadow = clamp(shadow, 0, 1);
				float4 cloudcol = 1.0;
				cloudcol.rgb = lerp(1.0* thickness,_CloudBaseColor.rgb , base);
				cloudcol.rgb = lerp(cloudcol.rgb, _CloudAmbientColor.rgb, ambient);
				cloudcol.rgb = lerp(cloudcol.rgb, _CloudAmbientColor.rgb * 0.6 , shadow);
				cloudcol.rgb = lerp(0.0, cloudcol.rgb,saturate(i.uv.y)) ;


				fixed4 final = 1.0;
				//final.rgb =(1 - thickness)*(skyColor + sun_moon) + cloudcol  * 3* thickness;
				final.rgb =  skyColor + cloudcol;
				return final;
			}

            ENDCG
        }
    }
}
