Shader "Unlit/Grass"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

		_TopColor("TopColor",Color) =(1,1,1,1)
		_BottonColor("BottonColor",Color) = (1,1,1,1)
		_Cutoff("Cutoff",Range(0,1)) = 0.6

    }
    SubShader
    {
		Tags{ "RenderType" = "TransparentCutout"  "Queue" = "Geometry+0" }
		Cull Off
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

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
			float4 _TopColor;
			float4 _BottonColor;
			float _Cutoff;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
				float lerp_fac = smoothstep(0.2, 1.0, i.uv.y);
				col.rgb = lerp( _BottonColor.rgb, _TopColor.rgb, lerp_fac);
				clip(col.a - _Cutoff);

                // apply fog


                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
