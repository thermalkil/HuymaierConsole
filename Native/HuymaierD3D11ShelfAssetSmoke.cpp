#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <DirectXMath.h>
#include <wrl/client.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>

#include "HuymaierD3D11ShelfAsset.h"

using namespace DirectX;
using Microsoft::WRL::ComPtr;
using HuymaierGpuShelf::Asset;
using HuymaierGpuShelf::DrawBatch;
using HuymaierGpuShelf::Vertex;

namespace
{
    struct Constants
    {
        XMFLOAT4X4 worldViewProjection;
        XMFLOAT4X4 world;
        XMFLOAT4 baseColor;
        XMFLOAT4 emissive;
        XMFLOAT4 surface;
        XMINT4 flags;
    };

    const char* kModelShader = R"HLSL(
cbuffer ModelConstants : register(b0)
{
    row_major float4x4 WorldViewProjection;
    row_major float4x4 World;
    float4 BaseColor;
    float4 Emissive;
    float4 Surface;
    int4 Flags;
};
Texture2D BaseTexture : register(t0);
Texture2D EmissiveTexture : register(t1);
SamplerState BaseSampler : register(s0);
SamplerState EmissiveSampler : register(s1);
struct VSIn { float3 p:POSITION; float3 n:NORMAL; float2 uv0:TEXCOORD0; float2 uv1:TEXCOORD1; };
struct VSOut { float4 p:SV_POSITION; float3 n:NORMAL; float2 uv0:TEXCOORD0; float2 uv1:TEXCOORD1; };
VSOut VSMain(VSIn v)
{
    VSOut o;
    o.p = mul(float4(v.p,1), WorldViewProjection);
    o.n = normalize(mul(float4(v.n,0), World).xyz);
    o.uv0 = v.uv0;
    o.uv1 = v.uv1;
    return o;
}
float4 PSMain(VSOut i) : SV_TARGET
{
    // HC3D v1 cache-space UV convention: restore authored glTF V before sampling.
    float2 baseUv = float2(i.uv0.x, 1.0 - i.uv0.y);
    float2 emissiveUv = float2(i.uv1.x, 1.0 - i.uv1.y);
    float4 tex = Flags.x != 0 ? BaseTexture.Sample(BaseSampler, baseUv) : float4(1,1,1,1);
    float4 base = tex * BaseColor;
    if (Flags.z == 1 && base.a < Surface.w) discard;
    float3 n = normalize(i.n);
    float3 lightDir = normalize(float3(-0.45,0.70,-0.65));
    float diffuse = Flags.w != 0 ? 1.0 : (0.28 + 0.72 * saturate(dot(n, -lightDir)));
    float3 lit = base.rgb * diffuse;
    float3 emissive = Emissive.rgb * Emissive.a;
    if (Flags.y != 0) emissive *= EmissiveTexture.Sample(EmissiveSampler, emissiveUv).rgb;
    float specPower = lerp(8.0, 58.0, 1.0 - saturate(Surface.y));
    float3 viewDir = float3(0,0,-1);
    float3 halfDir = normalize(-lightDir + viewDir);
    float spec = Flags.w != 0 ? 0.0 : pow(saturate(dot(n, halfDir)), specPower) * saturate(Surface.z + Surface.x * .35 + Surface.w * .15);
    float alpha = Flags.z == 0 ? 1.0 : base.a;
    return float4((lit + emissive + spec.xxx) * alpha, alpha);
}
)HLSL";

    D3D11_TEXTURE_ADDRESS_MODE AddressMode(int wrap)
    {
        if (wrap == 33071) return D3D11_TEXTURE_ADDRESS_CLAMP;
        if (wrap == 33648) return D3D11_TEXTURE_ADDRESS_MIRROR;
        return D3D11_TEXTURE_ADDRESS_WRAP;
    }

    HRESULT MakeSampler(ID3D11Device* device, int wrapS, int wrapT, ID3D11SamplerState** state)
    {
        D3D11_SAMPLER_DESC d{};
        d.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
        d.AddressU = AddressMode(wrapS);
        d.AddressV = AddressMode(wrapT);
        d.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
        d.MaxLOD = D3D11_FLOAT32_MAX;
        return device->CreateSamplerState(&d, state);
    }

    int RunCachedSmoke(const wchar_t* cachePath)
    {
        const D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0 };
        D3D_FEATURE_LEVEL level{};
        ComPtr<ID3D11Device> device;
        ComPtr<ID3D11DeviceContext> context;
        HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            levels, ARRAYSIZE(levels), D3D11_SDK_VERSION, device.GetAddressOf(), &level, context.GetAddressOf());
        if (FAILED(hr)) return 30;

        Asset* rawAsset = nullptr;
        hr = HuymaierGpuShelf::LoadAsset(device.Get(), context.Get(), cachePath, &rawAsset);
        if (FAILED(hr) || !rawAsset) return 31;
        std::unique_ptr<Asset, void(*)(Asset*)> asset(rawAsset, HuymaierGpuShelf::DestroyAsset);

        ComPtr<ID3DBlob> vsBlob, psBlob, errors;
        hr = D3DCompile(kModelShader, strlen(kModelShader), "HC3DModel", nullptr, nullptr, "VSMain", "vs_4_0", D3DCOMPILE_OPTIMIZATION_LEVEL3, 0, vsBlob.GetAddressOf(), errors.GetAddressOf());
        if (FAILED(hr)) return 32;
        errors.Reset();
        hr = D3DCompile(kModelShader, strlen(kModelShader), "HC3DModel", nullptr, nullptr, "PSMain", "ps_4_0", D3DCOMPILE_OPTIMIZATION_LEVEL3, 0, psBlob.GetAddressOf(), errors.GetAddressOf());
        if (FAILED(hr)) return 33;
        ComPtr<ID3D11VertexShader> vs; ComPtr<ID3D11PixelShader> ps; ComPtr<ID3D11InputLayout> layout;
        if (FAILED(device->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, vs.GetAddressOf()))) return 34;
        if (FAILED(device->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, ps.GetAddressOf()))) return 35;
        const D3D11_INPUT_ELEMENT_DESC elements[] = {
            {"POSITION",0,DXGI_FORMAT_R32G32B32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"NORMAL",0,DXGI_FORMAT_R32G32B32_FLOAT,0,12,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",0,DXGI_FORMAT_R32G32_FLOAT,0,24,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",1,DXGI_FORMAT_R32G32_FLOAT,0,32,D3D11_INPUT_PER_VERTEX_DATA,0}
        };
        if (FAILED(device->CreateInputLayout(elements, ARRAYSIZE(elements), vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), layout.GetAddressOf()))) return 36;

        D3D11_BUFFER_DESC cbd{}; cbd.ByteWidth = sizeof(Constants); cbd.Usage = D3D11_USAGE_DYNAMIC; cbd.BindFlags = D3D11_BIND_CONSTANT_BUFFER; cbd.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
        ComPtr<ID3D11Buffer> cb; if (FAILED(device->CreateBuffer(&cbd, nullptr, cb.GetAddressOf()))) return 37;

        const UINT width = 256, height = 192;
        D3D11_TEXTURE2D_DESC td{}; td.Width=width;td.Height=height;td.MipLevels=1;td.ArraySize=1;td.Format=DXGI_FORMAT_B8G8R8A8_UNORM;td.SampleDesc.Count=1;td.Usage=D3D11_USAGE_DEFAULT;td.BindFlags=D3D11_BIND_RENDER_TARGET;
        ComPtr<ID3D11Texture2D> target; ComPtr<ID3D11RenderTargetView> rtv;
        if (FAILED(device->CreateTexture2D(&td,nullptr,target.GetAddressOf())) || FAILED(device->CreateRenderTargetView(target.Get(),nullptr,rtv.GetAddressOf()))) return 38;
        D3D11_TEXTURE2D_DESC dd=td;dd.Format=DXGI_FORMAT_D24_UNORM_S8_UINT;dd.BindFlags=D3D11_BIND_DEPTH_STENCIL;
        ComPtr<ID3D11Texture2D> depth;ComPtr<ID3D11DepthStencilView>dsv;
        if(FAILED(device->CreateTexture2D(&dd,nullptr,depth.GetAddressOf()))||FAILED(device->CreateDepthStencilView(depth.Get(),nullptr,dsv.GetAddressOf())))return 39;

        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_NONE;rd.DepthClipEnable=TRUE;
        ComPtr<ID3D11RasterizerState> rs;device->CreateRasterizerState(&rd,rs.GetAddressOf());
        D3D11_BLEND_DESC bd{};bd.RenderTarget[0].BlendEnable=TRUE;bd.RenderTarget[0].SrcBlend=D3D11_BLEND_ONE;bd.RenderTarget[0].DestBlend=D3D11_BLEND_INV_SRC_ALPHA;bd.RenderTarget[0].BlendOp=D3D11_BLEND_OP_ADD;bd.RenderTarget[0].SrcBlendAlpha=D3D11_BLEND_ONE;bd.RenderTarget[0].DestBlendAlpha=D3D11_BLEND_INV_SRC_ALPHA;bd.RenderTarget[0].BlendOpAlpha=D3D11_BLEND_OP_ADD;bd.RenderTarget[0].RenderTargetWriteMask=D3D11_COLOR_WRITE_ENABLE_ALL;
        ComPtr<ID3D11BlendState> blend;device->CreateBlendState(&bd,blend.GetAddressOf());

        const float clear[4]={0,0,0,0};context->OMSetRenderTargets(1,rtv.GetAddressOf(),dsv.Get());context->ClearRenderTargetView(rtv.Get(),clear);context->ClearDepthStencilView(dsv.Get(),D3D11_CLEAR_DEPTH,1,0);
        D3D11_VIEWPORT vp{};vp.Width=(float)width;vp.Height=(float)height;vp.MaxDepth=1;context->RSSetViewports(1,&vp);context->RSSetState(rs.Get());
        UINT stride=sizeof(Vertex),offset=0;ID3D11Buffer* vb=asset->vertexBuffer.Get();context->IASetVertexBuffers(0,1,&vb,&stride,&offset);context->IASetIndexBuffer(asset->indexBuffer.Get(),DXGI_FORMAT_R32_UINT,0);context->IASetInputLayout(layout.Get());context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);context->VSSetShader(vs.Get(),nullptr,0);context->PSSetShader(ps.Get(),nullptr,0);ID3D11Buffer* cbRaw=cb.Get();context->VSSetConstantBuffers(0,1,&cbRaw);context->PSSetConstantBuffers(0,1,&cbRaw);float bf[4]={0,0,0,0};context->OMSetBlendState(blend.Get(),bf,0xffffffffu);

        const float cx=(asset->minBounds[0]+asset->maxBounds[0])*.5f,cy=(asset->minBounds[1]+asset->maxBounds[1])*.5f,cz=(asset->minBounds[2]+asset->maxBounds[2])*.5f;
        const float sx=asset->maxBounds[0]-asset->minBounds[0],sy=asset->maxBounds[1]-asset->minBounds[1],sz=asset->maxBounds[2]-asset->minBounds[2];
        float diameter=std::sqrt(sx*sx+sy*sy+sz*sz);if(diameter<.00001f)diameter=1;
        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(2.55f/diameter,2.55f/diameter,2.55f/diameter)*XMMatrixRotationX(XMConvertToRadians(-10))*XMMatrixRotationY(XMConvertToRadians(42));
        XMMATRIX view=XMMatrixLookAtLH(XMVectorSet(0,.08f,-4.2f,1),XMVectorZero(),XMVectorSet(0,1,0,0));
        XMMATRIX proj=XMMatrixPerspectiveFovLH(XMConvertToRadians(34.0f),(float)width/(float)height,.01f,100.0f);
        XMMATRIX wvp=world*view*proj;

        for(const DrawBatch& d:asset->draws)
        {
            Constants c{};XMStoreFloat4x4(&c.worldViewProjection,wvp);XMStoreFloat4x4(&c.world,world);c.baseColor=XMFLOAT4(d.baseColor[0],d.baseColor[1],d.baseColor[2],d.baseColor[3]);c.emissive=XMFLOAT4(d.emissiveColor[0],d.emissiveColor[1],d.emissiveColor[2],d.emissiveStrength);c.surface=XMFLOAT4(d.metallic,d.roughness,d.specular,d.alphaCutoff);c.flags=XMINT4(d.baseImage>=0?1:0,d.emissiveImage>=0?1:0,d.alphaMode,(d.flags&2)?1:0);
            D3D11_MAPPED_SUBRESOURCE map{};if(FAILED(context->Map(cb.Get(),0,D3D11_MAP_WRITE_DISCARD,0,&map)))return 40;memcpy(map.pData,&c,sizeof(c));context->Unmap(cb.Get(),0);
            ID3D11ShaderResourceView* srvs[2]={nullptr,nullptr};if(d.baseImage>=0&&(size_t)d.baseImage<asset->textures.size())srvs[0]=asset->textures[(size_t)d.baseImage].view.Get();if(d.emissiveImage>=0&&(size_t)d.emissiveImage<asset->textures.size())srvs[1]=asset->textures[(size_t)d.emissiveImage].view.Get();context->PSSetShaderResources(0,2,srvs);
            ComPtr<ID3D11SamplerState> s0,s1;if(FAILED(MakeSampler(device.Get(),d.baseWrapS,d.baseWrapT,s0.GetAddressOf())))return 41;if(FAILED(MakeSampler(device.Get(),d.emissiveWrapS,d.emissiveWrapT,s1.GetAddressOf())))return 42;ID3D11SamplerState* samplers[2]={s0.Get(),s1.Get()};context->PSSetSamplers(0,2,samplers);
            context->DrawIndexed(d.indexCount,d.firstIndex,0);
        }
        context->Flush();

        D3D11_TEXTURE2D_DESC sd=td;sd.Usage=D3D11_USAGE_STAGING;sd.BindFlags=0;sd.CPUAccessFlags=D3D11_CPU_ACCESS_READ;
        ComPtr<ID3D11Texture2D> staging;if(FAILED(device->CreateTexture2D(&sd,nullptr,staging.GetAddressOf())))return 43;context->CopyResource(staging.Get(),target.Get());D3D11_MAPPED_SUBRESOURCE mapped{};if(FAILED(context->Map(staging.Get(),0,D3D11_MAP_READ,0,&mapped)))return 44;
        int visible=0,colorful=0;for(UINT y=0;y<height;y+=2){const uint8_t* row=(const uint8_t*)mapped.pData+y*mapped.RowPitch;for(UINT x=0;x<width;x+=2){const uint8_t* p=row+x*4;if(p[3]>24){visible++;int mx=std::max(p[0],std::max(p[1],p[2]));int mn=std::min(p[0],std::min(p[1],p[2]));if(mx-mn>28)colorful++;}}}context->Unmap(staging.Get(),0);
        return (visible>=120&&colorful>=30)?1:45;
    }
}

extern "C" __declspec(dllexport) int __cdecl HC_D3D11CachedAssetSmokeTest(const wchar_t* cachePath)
{
    try { return RunCachedSmoke(cachePath); }
    catch (...) { return 99; }
}
