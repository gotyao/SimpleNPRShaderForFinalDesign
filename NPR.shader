Shader "Unlit/NPR"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

        _RampStart("Ramp Start", Range(0.1, 1)) = 0.1
        _DarkColor("Dark Color",Color) = (0.4,0.4,0.4,1)
        _LightColor("Light Color",Color) = (0.8,0.8,0.8,1)
        
        _SpecPow("Spec Pow", Range(0,1)) = 0.1
        _SpecColor("Spec Color", Color) = (1.0, 1.0, 1.0, 1)
        _SpecIntensity("Spec Intensity", Range(0,1)) = 0.1
        _SpecSmooth("Spec Smooth", Range(0,0.5)) = 0.1
        
        _RimColor("Rim Color", Color) = (1.0, 1.0, 1.0, 1)
        _RimThreshold("Rim Threshold", Range(0,1)) = 0.5
        _RimSmooth("Rim Smooth", Range(0, 0.5)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // support unity's built-in fog
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _RampStart;
            float3 _DarkColor;
            float3 _LightColor;
            
            float _SpecPow;
            float3 _SpecColor;
            float _SpecIntensity;
            float _SpecSmooth;

            float3 _RimColor;
            float _RimThreshold;
            float _RimSmooth;

            // vertex shader
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                o.worldNormal = normalize(UnityObjectToWorldNormal(v.normal));  // world space normal vector
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  // world space vertex position

                UNITY_TRANSFER_FOG(o,o.vertex);  // implement fragment shader using fog to accelerate
                return o;
            }

            // fragment shader
            fixed4 frag (v2f i) : SV_Target
            {
                // Sample main texture color
                fixed4 col = tex2D(_MainTex, i.uv);

                // preprocess lighting and normal vec
                float3 normal = normalize(i.worldNormal);
                float3 worldLightDir = UnityWorldSpaceLightDir(i.worldPos);
                float LI = dot(i.worldNormal, worldLightDir);

                // calculate Blinn-Phong hightlight
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                float3 halfDir = normalize(viewDir + worldLightDir);
                float NoH = dot(normal, halfDir);
                float HightLight = pow(max(0, NoH), _SpecPow * 128.0);
                
                // smooth highlight
                float3 specularColor = smoothstep(0.7 - _SpecSmooth / 2, 0.7 + _SpecSmooth / 2, HightLight) * _SpecColor + _SpecIntensity;

                // rim lighting
                float rim = (1 - max(0, dot(i.worldNormal, viewDir))) * LI;  // cal area
                float3 rimColor = smoothstep(_RimThreshold - _RimSmooth / 2, _RimThreshold + _RimSmooth / 2, rim) * _RimColor;  // soft transition

                // toon shading
                float halfLambert = LI * 0.5 + 0.5;  // halfLamber
                float ramp = clamp((halfLambert - _RampStart) / 0.1, 0.0, 1.0);

                fixed3 finalColor = lerp(_DarkColor, _LightColor, ramp) + specularColor + rimColor;
                finalColor = col.rgb * finalColor;

                return fixed4(finalColor, col.a);
            }
            ENDCG
        }
    }
}
