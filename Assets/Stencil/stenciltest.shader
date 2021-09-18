Shader "Unlit/stenciltest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_OutlineScale("OutlineScale",Range(0,3)) = 0.2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Transparent" }
        LOD 100
		Blend One SrcAlpha
        Pass
        {

			Stencil{
				Ref 2
				Comp Always
				Pass Replace
				Fail Keep
				ZFail Replace
			}
			 ZTest LEqual
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
        }

		// outline pass
		Pass
		{
			ZTest Greater
			ZWrite Off
			Stencil{
				Ref 2
				Comp NotEqual
			}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

				#include "UnityCG.cginc"

				struct appdata
				{
					float4 vertex : POSITION;
					float2 uv : TEXCOORD0;
					float3 normal:NORMAL;

				};

				struct v2f
				{
					float2 uv : TEXCOORD0;
					float4 vertex : SV_POSITION;
				};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float _OutlineScale;
				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex + float4(v.normal * _OutlineScale,0));
					o.uv = TRANSFORM_TEX(v.uv, _MainTex);
					return o;
				}

				fixed4 frag(v2f i) : SV_Target
				{
					fixed4 col = float4(0,0,0,0);
				return col;
			}
			ENDCG
		}
    }
}
