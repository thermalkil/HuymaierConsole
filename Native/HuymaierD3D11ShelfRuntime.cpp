#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <d3d11.h>
#include <d3d9.h>
#include <d3dcompiler.h>
#include <DirectXMath.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

#include "HuymaierD3D11ShelfAsset.h"

using namespace DirectX;
using Microsoft::WRL::ComPtr;
using HuymaierGpuShelf::Asset;
using HuymaierGpuShelf::DrawBatch;
using HuymaierGpuShelf::Vertex;

namespace
{
    // HUYMAIER_D3D11_SHARED_SHELF_RUNTIME_V1
    struct Constants
    {
        XMFLOAT4X4 worldViewProjection;
        XMFLOAT4X4 world;
        XMFLOAT4 baseColor;
        XMFLOAT4 emissive;
        XMFLOAT4 surface;
        XMFLOAT4 extra;
        XMINT4 flags;
    };

    struct Item
    {
        int id = 0;
        std::shared_ptr<Asset> asset;
        float x = 0, y = 0, width = 1, height = 1;
        float modelScale = 0.70f;
        bool selected = false;
        bool visible = false;
    };

    struct ShelfSurface
    {
        UINT width = 0;
        UINT height = 0;
        ComPtr<IDirect3D9Ex> d3d9;
        ComPtr<IDirect3DDevice9Ex> device9;
        ComPtr<IDirect3DTexture9> texture9;
        ComPtr<IDirect3DSurface9> surface9;
        HANDLE sharedHandle = nullptr;
        ComPtr<ID3D11Texture2D> texture11;
        ComPtr<ID3D11RenderTargetView> rtv;
        ComPtr<ID3D11Texture2D> depth;
        ComPtr<ID3D11DepthStencilView> dsv;
        std::unordered_map<int, Item> items;
    };

    struct Core
    {
        std::mutex lock;
        bool initialized = false;
        HRESULT initResult = E_PENDING;
        ComPtr<ID3D11Device> device;
        ComPtr<ID3D11DeviceContext> context;
        ComPtr<ID3D11VertexShader> vertexShader;
        ComPtr<ID3D11PixelShader> pixelShader;
        ComPtr<ID3D11InputLayout> inputLayout;
        ComPtr<ID3D11Buffer> constants;
        ComPtr<ID3D11RasterizerState> rasterizer;
        ComPtr<ID3D11BlendState> blend;
        std::unordered_map<uint64_t, ComPtr<ID3D11SamplerState>> samplers;
        std::unordered_map<std::wstring, std::weak_ptr<Asset>> assets;
    };

    Core g_core;

    const char* kShader = R"HLSL(
cbuffer ModelConstants : register(b0)
{
    row_major float4x4 WorldViewProjection;
    row_major float4x4 World;
    float4 BaseColor;
    float4 Emissive;
    float4 Surface;
    float4 Extra;
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
    float4 tex = Flags.x != 0 ? BaseTexture.Sample(BaseSampler, i.uv0) : float4(1,1,1,1);
    float4 base = tex * BaseColor;
    if (Flags.z == 1 && base.a < Extra.x) discard;
    float3 n = normalize(i.n);
    float3 l0 = normalize(float3(-0.45,0.72,-0.62));
    float3 l1 = normalize(float3(0.75,0.25,-0.55));
    float d0 = saturate(dot(n,-l0));
    float d1 = saturate(dot(n,-l1));
    float diffuse = Flags.w != 0 ? 1.0 : (0.24 + d0 * .60 + d1 * .20);
    float3 lit = base.rgb * diffuse;
    float3 em = Emissive.rgb * Emissive.a;
    if (Flags.y != 0) em *= EmissiveTexture.Sample(EmissiveSampler, i.uv1).rgb;
    float specPower = lerp(8.0, 62.0, 1.0 - saturate(Surface.y));
    float3 halfDir = normalize(-l0 + float3(0,0,-1));
    float spec = Flags.w != 0 ? 0.0 : pow(saturate(dot(n,halfDir)),specPower) * saturate(Surface.z + Surface.x*.30 + Surface.w*.18);
    float selectedLift = Extra.y > .5 ? .045 : 0.0;
    float alpha = Flags.z == 0 ? 1.0 : base.a;
    return float4((lit + em + spec.xxx + selectedLift.xxx) * alpha, alpha);
}
)HLSL";

    D3D11_TEXTURE_ADDRESS_MODE AddressMode(int wrap)
    {
        if (wrap == 33071) return D3D11_TEXTURE_ADDRESS_CLAMP;
        if (wrap == 33648) return D3D11_TEXTURE_ADDRESS_MIRROR;
        return D3D11_TEXTURE_ADDRESS_WRAP;
    }

    uint64_t SamplerKey(int s, int t)
    {
        return (static_cast<uint64_t>(static_cast<uint32_t>(s)) << 32) | static_cast<uint32_t>(t);
    }

    ID3D11SamplerState* GetSampler(int wrapS, int wrapT)
    {
        const uint64_t key = SamplerKey(wrapS, wrapT);
        auto found = g_core.samplers.find(key);
        if (found != g_core.samplers.end()) return found->second.Get();
        D3D11_SAMPLER_DESC d{};
        d.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
        d.AddressU = AddressMode(wrapS);
        d.AddressV = AddressMode(wrapT);
        d.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
        d.MaxLOD = D3D11_FLOAT32_MAX;
        ComPtr<ID3D11SamplerState> sampler;
        if (FAILED(g_core.device->CreateSamplerState(&d, sampler.GetAddressOf()))) return nullptr;
        ID3D11SamplerState* raw = sampler.Get();
        g_core.samplers.emplace(key, std::move(sampler));
        return raw;
    }

    HRESULT InitializeCoreLocked()
    {
        if (g_core.initialized) return g_core.initResult;
        g_core.initialized = true;
        const D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_1,D3D_FEATURE_LEVEL_11_0,D3D_FEATURE_LEVEL_10_1,D3D_FEATURE_LEVEL_10_0 };
        D3D_FEATURE_LEVEL selected{};
        HRESULT hr = D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_HARDWARE,nullptr,D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            levels,ARRAYSIZE(levels),D3D11_SDK_VERSION,g_core.device.GetAddressOf(),&selected,g_core.context.GetAddressOf());
        if (FAILED(hr)) { g_core.initResult = hr; return hr; }

        ComPtr<ID3DBlob> vs, ps, errors;
        hr = D3DCompile(kShader,strlen(kShader),"HuymaierGpuShelf",nullptr,nullptr,"VSMain","vs_4_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,vs.GetAddressOf(),errors.GetAddressOf());
        if (FAILED(hr)) { g_core.initResult=hr; return hr; }
        errors.Reset();
        hr = D3DCompile(kShader,strlen(kShader),"HuymaierGpuShelf",nullptr,nullptr,"PSMain","ps_4_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,ps.GetAddressOf(),errors.GetAddressOf());
        if (FAILED(hr)) { g_core.initResult=hr; return hr; }
        if (FAILED(hr=g_core.device->CreateVertexShader(vs->GetBufferPointer(),vs->GetBufferSize(),nullptr,g_core.vertexShader.GetAddressOf()))) { g_core.initResult=hr; return hr; }
        if (FAILED(hr=g_core.device->CreatePixelShader(ps->GetBufferPointer(),ps->GetBufferSize(),nullptr,g_core.pixelShader.GetAddressOf()))) { g_core.initResult=hr; return hr; }
        const D3D11_INPUT_ELEMENT_DESC layout[] = {
            {"POSITION",0,DXGI_FORMAT_R32G32B32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"NORMAL",0,DXGI_FORMAT_R32G32B32_FLOAT,0,12,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",0,DXGI_FORMAT_R32G32_FLOAT,0,24,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",1,DXGI_FORMAT_R32G32_FLOAT,0,32,D3D11_INPUT_PER_VERTEX_DATA,0}
        };
        if (FAILED(hr=g_core.device->CreateInputLayout(layout,ARRAYSIZE(layout),vs->GetBufferPointer(),vs->GetBufferSize(),g_core.inputLayout.GetAddressOf()))) { g_core.initResult=hr; return hr; }
        D3D11_BUFFER_DESC cb{};cb.ByteWidth=sizeof(Constants);cb.Usage=D3D11_USAGE_DYNAMIC;cb.BindFlags=D3D11_BIND_CONSTANT_BUFFER;cb.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;
        if (FAILED(hr=g_core.device->CreateBuffer(&cb,nullptr,g_core.constants.GetAddressOf()))) { g_core.initResult=hr; return hr; }
        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_NONE;rd.DepthClipEnable=TRUE;rd.MultisampleEnable=FALSE;
        if (FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizer.GetAddressOf()))) { g_core.initResult=hr; return hr; }
        D3D11_BLEND_DESC bd{};bd.RenderTarget[0].BlendEnable=TRUE;bd.RenderTarget[0].SrcBlend=D3D11_BLEND_ONE;bd.RenderTarget[0].DestBlend=D3D11_BLEND_INV_SRC_ALPHA;bd.RenderTarget[0].BlendOp=D3D11_BLEND_OP_ADD;bd.RenderTarget[0].SrcBlendAlpha=D3D11_BLEND_ONE;bd.RenderTarget[0].DestBlendAlpha=D3D11_BLEND_INV_SRC_ALPHA;bd.RenderTarget[0].BlendOpAlpha=D3D11_BLEND_OP_ADD;bd.RenderTarget[0].RenderTargetWriteMask=D3D11_COLOR_WRITE_ENABLE_ALL;
        if (FAILED(hr=g_core.device->CreateBlendState(&bd,g_core.blend.GetAddressOf()))) { g_core.initResult=hr; return hr; }
        g_core.initResult=S_OK;
        return S_OK;
    }

    std::shared_ptr<Asset> AcquireAssetLocked(const wchar_t* path)
    {
        if (!path || !*path) return {};
        std::wstring key(path);
        auto it=g_core.assets.find(key);
        if(it!=g_core.assets.end()) { auto existing=it->second.lock(); if(existing) return existing; }
        Asset* raw=nullptr;
        if(FAILED(HuymaierGpuShelf::LoadAsset(g_core.device.Get(),g_core.context.Get(),path,&raw))||!raw) return {};
        std::shared_ptr<Asset> asset(raw,HuymaierGpuShelf::DestroyAsset);
        g_core.assets[key]=asset;
        return asset;
    }

    HRESULT CreateSurfaceTarget(ShelfSurface& s, int width, int height)
    {
        HRESULT hr=Direct3DCreate9Ex(D3D_SDK_VERSION,s.d3d9.GetAddressOf());if(FAILED(hr))return hr;
        D3DPRESENT_PARAMETERS pp{};pp.Windowed=TRUE;pp.SwapEffect=D3DSWAPEFFECT_DISCARD;pp.hDeviceWindow=GetDesktopWindow();pp.BackBufferWidth=1;pp.BackBufferHeight=1;pp.BackBufferFormat=D3DFMT_A8R8G8B8;pp.PresentationInterval=D3DPRESENT_INTERVAL_IMMEDIATE;
        hr=s.d3d9->CreateDeviceEx(D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,GetDesktopWindow(),D3DCREATE_HARDWARE_VERTEXPROCESSING|D3DCREATE_MULTITHREADED|D3DCREATE_FPU_PRESERVE,&pp,nullptr,s.device9.GetAddressOf());if(FAILED(hr))return hr;
        s.sharedHandle=nullptr;
        hr=s.device9->CreateTexture(width,height,1,D3DUSAGE_RENDERTARGET,D3DFMT_A8R8G8B8,D3DPOOL_DEFAULT,s.texture9.GetAddressOf(),&s.sharedHandle);if(FAILED(hr)||!s.sharedHandle)return FAILED(hr)?hr:E_FAIL;
        if(FAILED(hr=s.texture9->GetSurfaceLevel(0,s.surface9.GetAddressOf())))return hr;
        if(FAILED(hr=g_core.device->OpenSharedResource(s.sharedHandle,__uuidof(ID3D11Texture2D),reinterpret_cast<void**>(s.texture11.GetAddressOf()))))return hr;
        if(FAILED(hr=g_core.device->CreateRenderTargetView(s.texture11.Get(),nullptr,s.rtv.GetAddressOf())))return hr;
        D3D11_TEXTURE2D_DESC depth{};depth.Width=width;depth.Height=height;depth.MipLevels=1;depth.ArraySize=1;depth.Format=DXGI_FORMAT_D24_UNORM_S8_UINT;depth.SampleDesc.Count=1;depth.Usage=D3D11_USAGE_DEFAULT;depth.BindFlags=D3D11_BIND_DEPTH_STENCIL;
        if(FAILED(hr=g_core.device->CreateTexture2D(&depth,nullptr,s.depth.GetAddressOf())))return hr;
        if(FAILED(hr=g_core.device->CreateDepthStencilView(s.depth.Get(),nullptr,s.dsv.GetAddressOf())))return hr;
        s.width=width;s.height=height;return S_OK;
    }

    void RenderAssetLocked(ShelfSurface& s, Item& item, float phase)
    {
        Asset& a=*item.asset;
        const float x=std::max(0.0f,item.x),y=std::max(0.0f,item.y);
        const float right=std::min(static_cast<float>(s.width),item.x+item.width),bottom=std::min(static_cast<float>(s.height),item.y+item.height);
        if(right<=x+2||bottom<=y+2)return;
        D3D11_VIEWPORT vp{};vp.TopLeftX=x;vp.TopLeftY=y;vp.Width=right-x;vp.Height=bottom-y;vp.MinDepth=0;vp.MaxDepth=1;g_core.context->RSSetViewports(1,&vp);
        g_core.context->ClearDepthStencilView(s.dsv.Get(),D3D11_CLEAR_DEPTH,1,0);
        UINT stride=sizeof(Vertex),offset=0;ID3D11Buffer* vb=a.vertexBuffer.Get();g_core.context->IASetVertexBuffers(0,1,&vb,&stride,&offset);g_core.context->IASetIndexBuffer(a.indexBuffer.Get(),DXGI_FORMAT_R32_UINT,0);
        const float cx=(a.minBounds[0]+a.maxBounds[0])*.5f,cy=(a.minBounds[1]+a.maxBounds[1])*.5f,cz=(a.minBounds[2]+a.maxBounds[2])*.5f;
        const float sx=a.maxBounds[0]-a.minBounds[0],sy=a.maxBounds[1]-a.minBounds[1],sz=a.maxBounds[2]-a.minBounds[2];float diameter=std::sqrt(sx*sx+sy*sy+sz*sz);if(diameter<.00001f)diameter=1;
        const float scale=(2.60f/diameter)*std::max(.45f,std::min(.82f,item.modelScale))*(item.selected?1.04f:1.0f);
        const float yaw=24.0f+phase*16.0f+static_cast<float>((item.id*11)%360);
        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(scale,scale,scale)*XMMatrixRotationX(XMConvertToRadians(-10.0f))*XMMatrixRotationY(XMConvertToRadians(yaw));
        XMMATRIX view=XMMatrixLookAtLH(XMVectorSet(0,.08f,-4.2f,1),XMVectorZero(),XMVectorSet(0,1,0,0));
        XMMATRIX proj=XMMatrixPerspectiveFovLH(XMConvertToRadians(34.0f),vp.Width/vp.Height,.01f,100.0f);XMMATRIX wvp=world*view*proj;
        for(const DrawBatch& d:a.draws)
        {
            Constants c{};XMStoreFloat4x4(&c.worldViewProjection,wvp);XMStoreFloat4x4(&c.world,world);c.baseColor=XMFLOAT4(d.baseColor[0],d.baseColor[1],d.baseColor[2],d.baseColor[3]);c.emissive=XMFLOAT4(d.emissiveColor[0],d.emissiveColor[1],d.emissiveColor[2],d.emissiveStrength);c.surface=XMFLOAT4(d.metallic,d.roughness,d.specular,d.clearcoat);c.extra=XMFLOAT4(d.alphaCutoff,item.selected?1.0f:0.0f,0,0);c.flags=XMINT4(d.baseImage>=0?1:0,d.emissiveImage>=0?1:0,d.alphaMode,(d.flags&2)?1:0);
            D3D11_MAPPED_SUBRESOURCE mapped{};if(FAILED(g_core.context->Map(g_core.constants.Get(),0,D3D11_MAP_WRITE_DISCARD,0,&mapped)))continue;memcpy(mapped.pData,&c,sizeof(c));g_core.context->Unmap(g_core.constants.Get(),0);
            ID3D11ShaderResourceView* srvs[2]={nullptr,nullptr};if(d.baseImage>=0&&(size_t)d.baseImage<a.textures.size())srvs[0]=a.textures[(size_t)d.baseImage].view.Get();if(d.emissiveImage>=0&&(size_t)d.emissiveImage<a.textures.size())srvs[1]=a.textures[(size_t)d.emissiveImage].view.Get();g_core.context->PSSetShaderResources(0,2,srvs);
            ID3D11SamplerState* samplers[2]={GetSampler(d.baseWrapS,d.baseWrapT),GetSampler(d.emissiveWrapS,d.emissiveWrapT)};g_core.context->PSSetSamplers(0,2,samplers);
            g_core.context->DrawIndexed(d.indexCount,d.firstIndex,0);
        }
    }

    int RenderSurfaceLocked(ShelfSurface& s, float phase)
    {
        if(!s.rtv||!s.dsv)return 0;const float clear[4]={0,0,0,0};g_core.context->OMSetRenderTargets(1,s.rtv.GetAddressOf(),s.dsv.Get());g_core.context->ClearRenderTargetView(s.rtv.Get(),clear);
        g_core.context->IASetInputLayout(g_core.inputLayout.Get());g_core.context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);g_core.context->VSSetShader(g_core.vertexShader.Get(),nullptr,0);g_core.context->PSSetShader(g_core.pixelShader.Get(),nullptr,0);ID3D11Buffer* cb=g_core.constants.Get();g_core.context->VSSetConstantBuffers(0,1,&cb);g_core.context->PSSetConstantBuffers(0,1,&cb);g_core.context->RSSetState(g_core.rasterizer.Get());float blendFactor[4]={0,0,0,0};g_core.context->OMSetBlendState(g_core.blend.Get(),blendFactor,0xffffffffu);
        for(auto& pair:s.items)if(pair.second.visible&&pair.second.asset)RenderAssetLocked(s,pair.second,phase);g_core.context->Flush();return 1;
    }
}

extern "C" __declspec(dllexport) void* __cdecl HC_GPU_CreateShelfSurface(int width,int height,void** surface9)
{
    if(surface9)*surface9=nullptr;if(!surface9||width<1||height<1)return nullptr;
    std::lock_guard<std::mutex> guard(g_core.lock);if(FAILED(InitializeCoreLocked()))return nullptr;
    std::unique_ptr<ShelfSurface>s(new(std::nothrow)ShelfSurface());if(!s)return nullptr;if(FAILED(CreateSurfaceTarget(*s,width,height)))return nullptr;*surface9=s->surface9.Get();if(*surface9)static_cast<IUnknown*>(*surface9)->AddRef();return s.release();
}

extern "C" __declspec(dllexport) int __cdecl HC_GPU_LoadShelfModel(void* handle,int id,const wchar_t* cachePath)
{
    if(!handle||!cachePath)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto asset=AcquireAssetLocked(cachePath);if(!asset)return 0;Item&item=s->items[id];item.id=id;item.asset=asset;return 1;
}

extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItem(void* handle,int id,float x,float y,float width,float height,float scale,int selected,int visible)
{
    if(!handle||width<0||height<0)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.x=x;i.y=y;i.width=width;i.height=height;i.modelScale=scale;i.selected=selected!=0;i.visible=visible!=0;return 1;
}

extern "C" __declspec(dllexport) void __cdecl HC_GPU_ClearShelfItems(void* handle)
{
    if(!handle)return;std::lock_guard<std::mutex>guard(g_core.lock);static_cast<ShelfSurface*>(handle)->items.clear();
}

extern "C" __declspec(dllexport) int __cdecl HC_GPU_RenderShelfSurface(void* handle,float phase)
{
    if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);return RenderSurfaceLocked(*static_cast<ShelfSurface*>(handle),phase);
}

extern "C" __declspec(dllexport) void __cdecl HC_GPU_ReleaseShelfSurfacePointer(void* surface9)
{
    if(surface9)static_cast<IUnknown*>(surface9)->Release();
}

extern "C" __declspec(dllexport) void __cdecl HC_GPU_DestroyShelfSurface(void* handle)
{
    if(!handle)return;std::lock_guard<std::mutex>guard(g_core.lock);delete static_cast<ShelfSurface*>(handle);
}

extern "C" __declspec(dllexport) int __cdecl HC_GPU_GetCachedAssetCount()
{
    std::lock_guard<std::mutex>guard(g_core.lock);int count=0;for(auto it=g_core.assets.begin();it!=g_core.assets.end();){if(it->second.expired())it=g_core.assets.erase(it);else{++count;++it;}}return count;
}
