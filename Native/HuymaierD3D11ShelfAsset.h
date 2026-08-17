#pragma once

#include <Windows.h>
#include <d3d11.h>
#include <wrl/client.h>
#include <cstdint>
#include <string>
#include <vector>

namespace HuymaierGpuShelf
{
    // HUYMAIER_D3D11_SHELF_SHADER_V5_BALANCED_COLOR_PRESERVING_UI_PBR
    // Shared production shader for the shelf runtime and WARP pixel regressions.
    // glTF base-color/emissive textures are authored in sRGB; MR/normal/AO remain linear.
    // The WPF/D3DImage target is an ordinary UNORM desktop surface, so the final linear
    // result is encoded to sRGB. Lighting is deliberately UI-oriented: authored hue is
    // preserved for metallic surfaces and over-range energy is normalized by peak rather
    // than clipping individual channels to white.
    static const char* HcShelfShaderSource = R"HLSL(
    // HUYMAIER_D3D11_SHELF_SHADER_V5_BALANCED_COLOR_PRESERVING_UI_PBR
    // HUYMAIER_D3D11_SHELF_SHADER_V4_COLOR_MANAGED_UI_PBR (staged compatibility marker; V5 owns rendering)
    cbuffer ModelConstants : register(b0)
    {
        row_major float4x4 WorldViewProjection;
        row_major float4x4 World;
        float4 BaseColor;
        float4 Emissive;
        float4 Surface;
        float4 Extra;
        float4 MaterialParams;
        int4 Flags;
        int4 Maps;
    };
    Texture2D BaseTexture : register(t0);
    Texture2D EmissiveTexture : register(t1);
    Texture2D MetallicRoughnessTexture : register(t2);
    Texture2D NormalTexture : register(t3);
    Texture2D OcclusionTexture : register(t4);
    SamplerState BaseSampler : register(s0);
    SamplerState EmissiveSampler : register(s1);
    SamplerState MetallicRoughnessSampler : register(s2);
    SamplerState NormalSampler : register(s3);
    SamplerState OcclusionSampler : register(s4);

    float3 SrgbToLinear(float3 c)
    {
        c=saturate(c);
        float3 lo=c/12.92;
        float3 hi=pow(max((c+0.055)/1.055,0.0),2.4);
        return lerp(lo,hi,step(float3(0.04045,0.04045,0.04045),c));
    }
    float3 LinearToSrgb(float3 c)
    {
        c=max(c,0.0);
        float3 lo=c*12.92;
        float3 hi=1.055*pow(max(c,0.0),1.0/2.4)-0.055;
        return lerp(lo,hi,step(float3(0.0031308,0.0031308,0.0031308),c));
    }

    struct VSIn
    {
        float3 p:POSITION;
        float3 n:NORMAL;
        float4 t:TANGENT;
        float2 uv0:TEXCOORD0;
        float2 uv1:TEXCOORD1;
        float2 uv2:TEXCOORD2;
        float2 uv3:TEXCOORD3;
        float2 uv4:TEXCOORD4;
    };
    struct VSOut
    {
        float4 p:SV_POSITION;
        float3 n:NORMAL;
        float4 t:TANGENT;
        float2 uv0:TEXCOORD0;
        float2 uv1:TEXCOORD1;
        float2 uv2:TEXCOORD2;
        float2 uv3:TEXCOORD3;
        float2 uv4:TEXCOORD4;
        float3 wp:TEXCOORD5;
    };
    VSOut VSMain(VSIn v)
    {
        VSOut o;
        float4 worldPosition=mul(float4(v.p,1),World);
        o.p=mul(float4(v.p,1),WorldViewProjection);
        o.wp=worldPosition.xyz;
        o.n=normalize(mul(float4(v.n,0),World).xyz);
        o.t=float4(normalize(mul(float4(v.t.xyz,0),World).xyz),v.t.w);
        o.uv0=v.uv0;o.uv1=v.uv1;o.uv2=v.uv2;o.uv3=v.uv3;o.uv4=v.uv4;
        return o;
    }
    float4 PSMain(VSOut i, bool isFrontFace : SV_IsFrontFace) : SV_TARGET
    {
        float4 sampledBase=Flags.x!=0?BaseTexture.Sample(BaseSampler,i.uv0):float4(1,1,1,1);
        float3 baseTextureLinear=Flags.x!=0?SrgbToLinear(sampledBase.rgb):float3(1,1,1);
        float3 baseRgb=max(baseTextureLinear*BaseColor.rgb,0.0);
        float baseAlpha=saturate(sampledBase.a*BaseColor.a);
        if(Flags.z==1 && baseAlpha<Extra.x)discard;

        float metallic=saturate(Surface.x);
        float roughness=saturate(Surface.y);
        if(Maps.x!=0)
        {
            float4 mr=MetallicRoughnessTexture.Sample(MetallicRoughnessSampler,i.uv2);
            roughness=saturate(roughness*mr.g);
            metallic=saturate(metallic*mr.b);
        }

        float3 n=normalize(i.n);
        float3 t=normalize(i.t.xyz-n*dot(n,i.t.xyz));
        if(Maps.w!=0 && !isFrontFace)n=-n;
        if(Maps.y!=0)
        {
            float3 sampled=NormalTexture.Sample(NormalSampler,i.uv3).xyz*2.0-1.0;
            sampled.xy*=MaterialParams.x;
            sampled=normalize(sampled);
            float3 b=normalize(cross(n,t)*i.t.w);
            n=normalize(t*sampled.x+b*sampled.y+n*sampled.z);
        }

        float occlusion=1.0;
        if(Maps.z!=0)
        {
            float ao=OcclusionTexture.Sample(OcclusionSampler,i.uv4).r;
            occlusion=lerp(1.0,ao,saturate(MaterialParams.y));
        }

        float3 em=Emissive.rgb*Emissive.a;
        if(Flags.y!=0)em*=SrgbToLinear(EmissiveTexture.Sample(EmissiveSampler,i.uv1).rgb);

        float3 lit;
        if(Flags.w!=0)
        {
            lit=baseRgb;
        }
        else
        {
            // Balanced showroom lighting. Metallic materials retain a substantial
            // base-color body term so provider/logo assets never collapse to gray.
            float3 v=normalize(float3(0.0,0.08,-4.2)-i.wp);
            float3 l0=normalize(float3(-0.45,0.72,-0.62));
            float3 l1=normalize(float3(0.75,0.25,-0.55));
            float d0=saturate(dot(n,l0));
            float d1=saturate(dot(n,l1));
            float3 h0=normalize(l0+v);
            float3 h1=normalize(l1+v);

            float diffuseLight=0.42+d0*0.30+d1*0.12;
            float bodyRetention=lerp(1.0,0.78,metallic);
            float3 body=baseRgb*diffuseLight*bodyRetention;

            float specularFactor=saturate(Surface.z);
            float3 dielectricF0=float3(0.04,0.04,0.04)*specularFactor;
            float3 f0=lerp(dielectricF0,baseRgb*specularFactor,metallic);
            float specPower=lerp(10.0,72.0,1.0-roughness);
            float directSpec0=pow(saturate(dot(n,h0)),specPower)*d0;
            float directSpec1=pow(saturate(dot(n,h1)),specPower)*d1;
            float3 directSpec=f0*(directSpec0*0.18+directSpec1*0.07);

            float environmentStrength=0.055+(1.0-roughness)*0.085+saturate(Surface.w)*0.025;
            float3 environmentSpec=f0*environmentStrength;
            float3 metallicFill=baseRgb*metallic*(0.12+d0*0.08);
            lit=(body+directSpec+environmentSpec+metallicFill)*occlusion;
        }

        float selectedLift=Extra.y>.5?0.025:0.0;
        float alpha=Flags.z==2?baseAlpha:1.0;
        float brightness=max(0.25,Extra.z);
        float3 linearRgb=max((lit+em+selectedLift.xxx)*brightness,0.0);

        // Never clip RGB channels independently: that is what turned purple GOG
        // and other saturated provider materials into white silhouettes. If energy
        // exceeds display range, scale the whole color by the same amount so hue
        // and saturation survive intact.
        float peak=max(linearRgb.r,max(linearRgb.g,linearRgb.b));
        linearRgb*=1.0/max(1.0,peak);
        float3 displayRgb=LinearToSrgb(linearRgb);
        return float4(displayRgb*alpha,alpha);
    }
    )HLSL";

    // HUYMAIER_D3D11_GPU_ASSET_V3
    struct Vertex
    {
        float px, py, pz;
        float nx, ny, nz;
        float tx, ty, tz, tw;
        float u0, v0;
        float u1, v1;
        float u2, v2;
        float u3, v3;
        float u4, v4;
    };

    struct DrawBatch
    {
        uint32_t firstIndex = 0;
        uint32_t indexCount = 0;
        int32_t baseImage = -1;
        int32_t emissiveImage = -1;
        int32_t metallicRoughnessImage = -1;
        int32_t normalImage = -1;
        int32_t occlusionImage = -1;
        float baseColor[4] = { 1, 1, 1, 1 };
        float emissiveColor[3] = { 0, 0, 0 };
        float emissiveStrength = 1.0f;
        float metallic = 1.0f;
        float roughness = 1.0f;
        float specular = 1.0f;
        float clearcoat = 0.0f;
        float normalScale = 1.0f;
        float occlusionStrength = 1.0f;
        int32_t baseWrapS = 10497;
        int32_t baseWrapT = 10497;
        int32_t emissiveWrapS = 10497;
        int32_t emissiveWrapT = 10497;
        int32_t metallicRoughnessWrapS = 10497;
        int32_t metallicRoughnessWrapT = 10497;
        int32_t normalWrapS = 10497;
        int32_t normalWrapT = 10497;
        int32_t occlusionWrapS = 10497;
        int32_t occlusionWrapT = 10497;
        int32_t alphaMode = 0;
        float alphaCutoff = 0.5f;
        int32_t flags = 0;
    };

    struct Texture
    {
        uint32_t width = 0;
        uint32_t height = 0;
        Microsoft::WRL::ComPtr<ID3D11Texture2D> resource;
        Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> view;
    };

    struct Asset
    {
        std::wstring cachePath;
        uint32_t quality = 0;
        uint32_t vertexCount = 0;
        uint32_t indexCount = 0;
        float minBounds[3] = { 0, 0, 0 };
        float maxBounds[3] = { 0, 0, 0 };
        Microsoft::WRL::ComPtr<ID3D11Buffer> vertexBuffer;
        Microsoft::WRL::ComPtr<ID3D11Buffer> indexBuffer;
        std::vector<DrawBatch> draws;
        std::vector<Texture> textures;
    };

    HRESULT LoadAsset(
        ID3D11Device* device,
        ID3D11DeviceContext* context,
        const wchar_t* cachePath,
        Asset** assetOut);

    void DestroyAsset(Asset* asset);
}
