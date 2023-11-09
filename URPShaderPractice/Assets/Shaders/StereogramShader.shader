Shader"Unlit/stereogram"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
        [NoScaleOffset]_PatternTex ("_PatternTex", 2D) = "white" {}
        [NoScaleOffset]_PatternTex2 ("_PatternTex2", 2D) = "black" {}
        [NoScaleOffset]_DepthTex ("_DepthTex", 2D) = "white" {}
        _DepthContrast ("_DepthContrast", Range(0,10)) = 10
        _ScrollingSpeed ("_ScrollingSpeed", Range(0,1)) = 1
    }
    SubShader
    {
        // No culling or depth
Cull Off
ZWrite Off
ZTest Always

        Pass
        {
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
    float4 vertex : SV_POSITION;
};

sampler2D _PatternTex;
sampler2D _PatternTex2;
sampler2D _MainTex;
sampler2D _DepthTex;

float _DepthContrast;
float _ScrollingSpeed;

int _CurrentStrip;
int _NumOfStrips;
float _DepthFactor;

v2f vert(appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;

    return o;
}

float3 Contrast(float3 col, float k) //k=1 is neutral, 0 to 2
{
    return ((col - 0.5f) * max(k, 0)) + 0.5f;
}

float4 frag(v2f i) : SV_Target
{
                //reference:
                //https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-41-real-time-stereograms
                //https://www.ime.usp.br/~otuyama/stereogram/basic/index.html

    float2 uv = i.uv;

                //the first reference strip
    if (_CurrentStrip == 0)
    {
                    //pattern tiling
        float2 patternUV = uv;
        patternUV.x *= _NumOfStrips;
        patternUV.y *= _ScreenParams.y / _ScreenParams.x * _NumOfStrips;
        float2 patternUV2 = patternUV;

                    //scrolling UV
        patternUV.x -= _Time.x * _ScrollingSpeed;
        patternUV2.x += _Time.x * _ScrollingSpeed;

                    //pattern
        float4 p1 = tex2D(_PatternTex, patternUV);
        float4 p2 = tex2D(_PatternTex2, patternUV2);

                    //result
                    //float4 p = lerp(p1,p2,p2.a);
        float4 p = min(p1, p2);
        p.a = 1;

        return p;
    }

                //don't change anything in previous strip
    float stripWidth = 1 / float(_NumOfStrips);
    float stripRangeMin = float(_CurrentStrip) * stripWidth;
    float stripRangeMax = float(_CurrentStrip + 1) * stripWidth;
    if (uv.x < stripRangeMin)
    {
        return tex2D(_MainTex, uv);
    }

                //depth
    float2 depthUV = uv;
    depthUV.x = depthUV.x * (1 + stripWidth) - stripWidth; //"shrink" it so it fit into remaining strips
    float depth = tex2D(_DepthTex, depthUV).r;
    float odepth = depth;
    depth = Contrast(depth * _DepthContrast, _DepthContrast);
    depth *= odepth;
    depth *= _DepthFactor;

                //distort the texture
    uv.x -= stripWidth; //take the previous strip
    uv.x *= 1 + depth;

    float4 col = tex2D(_MainTex, uv);
    return col;
}
            ENDCG
        }
    }
}

