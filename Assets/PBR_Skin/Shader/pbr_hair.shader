Shader "Unlit/pbr_hair"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_HairMask("HairMask",2D) = "white" {}
		_Color("Color",Color) = (0,0,0,1)
	}
		SubShader
		{
			Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "LightMode" = "ForwardBase"}
			LOD 100
			Blend SrcAlpha OneMinusSrcAlpha
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
			sampler2D _HairMask;
			half4 _Color;

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
                fixed4 col =0;
			fixed mask = tex2D(_HairMask, i.uv).r;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
				col.rgb = _Color.rgb;
				col.a = mask;
                return col;
            }
            ENDCG
        }
    }
}
