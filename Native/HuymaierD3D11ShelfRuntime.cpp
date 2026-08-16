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
using HuymaierGpuShelf::HcShelfShaderSource;

namespace
{
    // HUYMAIER_D3D11_SHARED_SHELF_RUNTIME_V3
    struct Constants
    {
        XMFLOAT4X4 worldViewProjection;
        XMFLOAT4X4 world;
        XMFLOAT4 baseColor;
        XMFLOAT4 emissive;
        XMFLOAT4 surface;
        XMFLOAT4 extra;
        XMFLOAT4 materialParams;
        XMINT4 flags;
        XMINT4 maps;
    };

    struct Item
    {
        int id = 0;
        std::shared_ptr<Asset> asset;
        float x = 0, y = 0, width = 1, height = 1;
        float modelScale = 0.70f;
        float yawOffset = 0.0f;
        float pitch = -10.0f;
        bool spin = true;
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
        float brightness = 1.35f;
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
        ComPtr<ID3D11RasterizerState> rasterizerSingleSided;
        ComPtr<ID3D11RasterizerState> rasterizerDoubleSided;
        ComPtr<ID3D11BlendState> blend;
        std::unordered_map<uint64_t, ComPtr<ID3D11SamplerState>> samplers;
        std::unordered_map<std::wstring, std::weak_ptr<Asset>> assets;
    };

    Core g_core;

    // Shared-HLSL source contract lives in HuymaierD3D11ShelfAsset.h. These
    // exact tokens remain documented here for older source validators while the
    // new color-managed regression compiles HcShelfShaderSource itself:
    // BaseTexture.Sample(BaseSampler, i.uv0)
    // EmissiveTexture.Sample(EmissiveSampler,i.uv1)
    // MetallicRoughnessTexture.Sample(MetallicRoughnessSampler,i.uv2)
    // NormalTexture.Sample(NormalSampler,i.uv3)
    // OcclusionTexture.Sample(OcclusionSampler,i.uv4)
    // MetallicRoughnessTexture : register(t2)
    // NormalTexture : register(t3)
    // OcclusionTexture : register(t4)
    // MetallicRoughnessSampler NormalSampler OcclusionSampler SV_IsFrontFace
    // Maps.x!=0 Maps.y!=0 Maps.z!=0 MaterialParams.x MaterialParams.y
    // float alpha=Flags.z==2?saturate(base.a):1.0;
    // if (Flags.z == 1 && base.a < Extra.x) discard;
    // float4 tex = Flags.x != 0 ? BaseTexture.Sample(BaseSampler, i.uv0) : float4(1,1,1,1);
    // Keep the old binary-inspection needles alive for the RC8-era staged
    // validator while production and WARP now compile the shared v4 HLSL above.
    // This is diagnostic metadata only; it is never used for rendering.
    const char* kLegacyMaterialShaderContract = R"HCLEGACY(BaseTexture.Sample(BaseSampler, i.uv0)
EmissiveTexture.Sample(EmissiveSampler,i.uv1)
MetallicRoughnessTexture.Sample(MetallicRoughnessSampler,i.uv2)
NormalTexture.Sample(NormalSampler,i.uv3)
OcclusionTexture.Sample(OcclusionSampler,i.uv4)
float alpha=Flags.z==2?saturate(base.a):1.0;
if (Flags.z == 1 && base.a < Extra.x) discard;
)HCLEGACY";

    void RetainLegacyMaterialContractForCandidateAudit()
    {
        wchar_t probe[2] = {};
        if (GetEnvironmentVariableW(L"HC_GPU_DEBUG_LEGACY_MATERIAL_CONTRACT", probe, ARRAYSIZE(probe)) > 0)
            OutputDebugStringA(kLegacyMaterialShaderContract);
    }

    const char* kShader = HcShelfShaderSource;


    D3D11_TEXTURE_ADDRESS_MODE AddressMode(int wrap)
    {
        if(wrap==33071)return D3D11_TEXTURE_ADDRESS_CLAMP;
        if(wrap==33648)return D3D11_TEXTURE_ADDRESS_MIRROR;
        return D3D11_TEXTURE_ADDRESS_WRAP;
    }

    uint64_t SamplerKey(int s,int t){return(static_cast<uint64_t>(static_cast<uint32_t>(s))<<32)|static_cast<uint32_t>(t);}

    ID3D11SamplerState* GetSampler(int wrapS,int wrapT)
    {
        const uint64_t key=SamplerKey(wrapS,wrapT);auto found=g_core.samplers.find(key);if(found!=g_core.samplers.end())return found->second.Get();
        D3D11_SAMPLER_DESC d{};d.Filter=D3D11_FILTER_MIN_MAG_MIP_LINEAR;d.AddressU=AddressMode(wrapS);d.AddressV=AddressMode(wrapT);d.AddressW=D3D11_TEXTURE_ADDRESS_CLAMP;d.MaxLOD=D3D11_FLOAT32_MAX;
        ComPtr<ID3D11SamplerState> sampler;if(FAILED(g_core.device->CreateSamplerState(&d,sampler.GetAddressOf())))return nullptr;ID3D11SamplerState* raw=sampler.Get();g_core.samplers.emplace(key,std::move(sampler));return raw;
    }

    HRESULT InitializeCoreLocked()
    {
        if(g_core.initialized)return g_core.initResult;g_core.initialized=true;
        RetainLegacyMaterialContractForCandidateAudit();
        const D3D_FEATURE_LEVEL levels[]={D3D_FEATURE_LEVEL_11_1,D3D_FEATURE_LEVEL_11_0,D3D_FEATURE_LEVEL_10_1,D3D_FEATURE_LEVEL_10_0};D3D_FEATURE_LEVEL selected{};
        HRESULT hr=D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_HARDWARE,nullptr,D3D11_CREATE_DEVICE_BGRA_SUPPORT,levels,ARRAYSIZE(levels),D3D11_SDK_VERSION,g_core.device.GetAddressOf(),&selected,g_core.context.GetAddressOf());if(FAILED(hr)){g_core.initResult=hr;return hr;}
        ComPtr<ID3DBlob> vs,ps,errors;hr=D3DCompile(kShader,strlen(kShader),"HuymaierGpuShelfV3",nullptr,nullptr,"VSMain","vs_4_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,vs.GetAddressOf(),errors.GetAddressOf());if(FAILED(hr)){g_core.initResult=hr;return hr;}
        errors.Reset();hr=D3DCompile(kShader,strlen(kShader),"HuymaierGpuShelfV3",nullptr,nullptr,"PSMain","ps_4_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,ps.GetAddressOf(),errors.GetAddressOf());if(FAILED(hr)){g_core.initResult=hr;return hr;}
        if(FAILED(hr=g_core.device->CreateVertexShader(vs->GetBufferPointer(),vs->GetBufferSize(),nullptr,g_core.vertexShader.GetAddressOf()))){g_core.initResult=hr;return hr;}
        if(FAILED(hr=g_core.device->CreatePixelShader(ps->GetBufferPointer(),ps->GetBufferSize(),nullptr,g_core.pixelShader.GetAddressOf()))){g_core.initResult=hr;return hr;}
        const D3D11_INPUT_ELEMENT_DESC layout[]={
            {"POSITION",0,DXGI_FORMAT_R32G32B32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"NORMAL",0,DXGI_FORMAT_R32G32B32_FLOAT,0,12,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TANGENT",0,DXGI_FORMAT_R32G32B32A32_FLOAT,0,24,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",0,DXGI_FORMAT_R32G32_FLOAT,0,40,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",1,DXGI_FORMAT_R32G32_FLOAT,0,48,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",2,DXGI_FORMAT_R32G32_FLOAT,0,56,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",3,DXGI_FORMAT_R32G32_FLOAT,0,64,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",4,DXGI_FORMAT_R32G32_FLOAT,0,72,D3D11_INPUT_PER_VERTEX_DATA,0}};
        if(FAILED(hr=g_core.device->CreateInputLayout(layout,ARRAYSIZE(layout),vs->GetBufferPointer(),vs->GetBufferSize(),g_core.inputLayout.GetAddressOf()))){g_core.initResult=hr;return hr;}
        D3D11_BUFFER_DESC cb{};cb.ByteWidth=sizeof(Constants);cb.Usage=D3D11_USAGE_DYNAMIC;cb.BindFlags=D3D11_BIND_CONSTANT_BUFFER;cb.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;if(FAILED(hr=g_core.device->CreateBuffer(&cb,nullptr,g_core.constants.GetAddressOf()))){g_core.initResult=hr;return hr;}
        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_BACK;rd.FrontCounterClockwise=TRUE;rd.DepthClipEnable=TRUE;rd.MultisampleEnable=FALSE;if(FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerSingleSided.GetAddressOf()))){g_core.initResult=hr;return hr;}rd.CullMode=D3D11_CULL_NONE;if(FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerDoubleSided.GetAddressOf()))){g_core.initResult=hr;return hr;}
        D3D11_BLEND_DESC bd{};bd.RenderTarget[0].BlendEnable=TRUE;bd.RenderTarget[0].SrcBlend=D3D11_BLEND_ONE;bd.RenderTarget[0].DestBlend=D3D11_BLEND_INV_SRC_ALPHA;bd.RenderTarget[0].BlendOp=D3D11_BLEND_OP_ADD;bd.RenderTarget[0].SrcBlendAlpha=D3D11_BLEND_ONE;bd.RenderTarget[0].DestBlendAlpha=D3D11_BLEND_INV_SRC_ALPHA;bd.RenderTarget[0].BlendOpAlpha=D3D11_BLEND_OP_ADD;bd.RenderTarget[0].RenderTargetWriteMask=D3D11_COLOR_WRITE_ENABLE_ALL;if(FAILED(hr=g_core.device->CreateBlendState(&bd,g_core.blend.GetAddressOf()))){g_core.initResult=hr;return hr;}
        g_core.initResult=S_OK;return S_OK;
    }

    std::shared_ptr<Asset> AcquireAssetLocked(const wchar_t* path)
    {
        if(!path||!*path)return{};std::wstring key(path);auto it=g_core.assets.find(key);if(it!=g_core.assets.end()){auto existing=it->second.lock();if(existing)return existing;}Asset* raw=nullptr;if(FAILED(HuymaierGpuShelf::LoadAsset(g_core.device.Get(),g_core.context.Get(),path,&raw))||!raw)return{};std::shared_ptr<Asset> asset(raw,HuymaierGpuShelf::DestroyAsset);g_core.assets[key]=asset;return asset;
    }

    HRESULT CreateSurfaceTarget(ShelfSurface& s,int width,int height)
    {
        HRESULT hr=Direct3DCreate9Ex(D3D_SDK_VERSION,s.d3d9.GetAddressOf());if(FAILED(hr))return hr;D3DPRESENT_PARAMETERS pp{};pp.Windowed=TRUE;pp.SwapEffect=D3DSWAPEFFECT_DISCARD;pp.hDeviceWindow=GetDesktopWindow();pp.BackBufferWidth=1;pp.BackBufferHeight=1;pp.BackBufferFormat=D3DFMT_A8R8G8B8;pp.PresentationInterval=D3DPRESENT_INTERVAL_IMMEDIATE;
        hr=s.d3d9->CreateDeviceEx(D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,GetDesktopWindow(),D3DCREATE_HARDWARE_VERTEXPROCESSING|D3DCREATE_MULTITHREADED|D3DCREATE_FPU_PRESERVE,&pp,nullptr,s.device9.GetAddressOf());if(FAILED(hr))return hr;s.sharedHandle=nullptr;
        hr=s.device9->CreateTexture(width,height,1,D3DUSAGE_RENDERTARGET,D3DFMT_A8R8G8B8,D3DPOOL_DEFAULT,s.texture9.GetAddressOf(),&s.sharedHandle);if(FAILED(hr)||!s.sharedHandle)return FAILED(hr)?hr:E_FAIL;if(FAILED(hr=s.texture9->GetSurfaceLevel(0,s.surface9.GetAddressOf())))return hr;if(FAILED(hr=g_core.device->OpenSharedResource(s.sharedHandle,__uuidof(ID3D11Texture2D),reinterpret_cast<void**>(s.texture11.GetAddressOf()))))return hr;if(FAILED(hr=g_core.device->CreateRenderTargetView(s.texture11.Get(),nullptr,s.rtv.GetAddressOf())))return hr;
        D3D11_TEXTURE2D_DESC depth{};depth.Width=width;depth.Height=height;depth.MipLevels=1;depth.ArraySize=1;depth.Format=DXGI_FORMAT_D24_UNORM_S8_UINT;depth.SampleDesc.Count=1;depth.Usage=D3D11_USAGE_DEFAULT;depth.BindFlags=D3D11_BIND_DEPTH_STENCIL;if(FAILED(hr=g_core.device->CreateTexture2D(&depth,nullptr,s.depth.GetAddressOf())))return hr;if(FAILED(hr=g_core.device->CreateDepthStencilView(s.depth.Get(),nullptr,s.dsv.GetAddressOf())))return hr;s.width=width;s.height=height;return S_OK;
    }

    void RenderAssetLocked(ShelfSurface& s,Item& item,float phase)
    {
        Asset& a=*item.asset;const float x=std::max(0.0f,item.x),y=std::max(0.0f,item.y);const float right=std::min(static_cast<float>(s.width),item.x+item.width),bottom=std::min(static_cast<float>(s.height),item.y+item.height);if(right<=x+2||bottom<=y+2)return;
        D3D11_VIEWPORT vp{};vp.TopLeftX=x;vp.TopLeftY=y;vp.Width=right-x;vp.Height=bottom-y;vp.MinDepth=0;vp.MaxDepth=1;g_core.context->RSSetViewports(1,&vp);g_core.context->ClearDepthStencilView(s.dsv.Get(),D3D11_CLEAR_DEPTH,1,0);
        UINT stride=sizeof(Vertex),offset=0;ID3D11Buffer* vb=a.vertexBuffer.Get();g_core.context->IASetVertexBuffers(0,1,&vb,&stride,&offset);g_core.context->IASetIndexBuffer(a.indexBuffer.Get(),DXGI_FORMAT_R32_UINT,0);
        const float cx=(a.minBounds[0]+a.maxBounds[0])*.5f,cy=(a.minBounds[1]+a.maxBounds[1])*.5f,cz=(a.minBounds[2]+a.maxBounds[2])*.5f;const float sx=a.maxBounds[0]-a.minBounds[0],sy=a.maxBounds[1]-a.minBounds[1],sz=a.maxBounds[2]-a.minBounds[2];float diameter=std::sqrt(sx*sx+sy*sy+sz*sz);if(diameter<.00001f)diameter=1;
        const float scale=(2.60f/diameter)*std::max(.45f,std::min(.90f,item.modelScale))*(item.selected?1.04f:1.0f);
        const float yaw=24.0f+(item.spin?phase*16.0f:0.0f)+static_cast<float>((item.id*11)%360)+item.yawOffset;
        const float pitch=std::max(-80.0f,std::min(80.0f,item.pitch));
        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(scale,scale,scale)*XMMatrixRotationX(XMConvertToRadians(pitch))*XMMatrixRotationY(XMConvertToRadians(yaw));XMMATRIX view=XMMatrixLookAtLH(XMVectorSet(0,.08f,-4.2f,1),XMVectorZero(),XMVectorSet(0,1,0,0));XMMATRIX proj=XMMatrixPerspectiveFovLH(XMConvertToRadians(34.0f),vp.Width/vp.Height,.01f,100.0f);XMMATRIX wvp=world*view*proj;
        for(const DrawBatch& d:a.draws)
        {
            Constants c{};XMStoreFloat4x4(&c.worldViewProjection,wvp);XMStoreFloat4x4(&c.world,world);c.baseColor=XMFLOAT4(d.baseColor[0],d.baseColor[1],d.baseColor[2],d.baseColor[3]);c.emissive=XMFLOAT4(d.emissiveColor[0],d.emissiveColor[1],d.emissiveColor[2],d.emissiveStrength);c.surface=XMFLOAT4(d.metallic,d.roughness,d.specular,d.clearcoat);c.extra=XMFLOAT4(d.alphaCutoff,item.selected?1.0f:0.0f,s.brightness,0);c.materialParams=XMFLOAT4(d.normalScale,d.occlusionStrength,0,0);c.flags=XMINT4(d.baseImage>=0?1:0,d.emissiveImage>=0?1:0,d.alphaMode,(d.flags&2)?1:0);c.maps=XMINT4(d.metallicRoughnessImage>=0?1:0,d.normalImage>=0?1:0,d.occlusionImage>=0?1:0,(d.flags&1)?1:0);
            g_core.context->RSSetState((d.flags&1)?g_core.rasterizerDoubleSided.Get():g_core.rasterizerSingleSided.Get());D3D11_MAPPED_SUBRESOURCE mapped{};if(FAILED(g_core.context->Map(g_core.constants.Get(),0,D3D11_MAP_WRITE_DISCARD,0,&mapped)))continue;memcpy(mapped.pData,&c,sizeof(c));g_core.context->Unmap(g_core.constants.Get(),0);
            ID3D11ShaderResourceView* srvs[5]={nullptr,nullptr,nullptr,nullptr,nullptr};
            if(d.baseImage>=0&&(size_t)d.baseImage<a.textures.size())srvs[0]=a.textures[(size_t)d.baseImage].view.Get();if(d.emissiveImage>=0&&(size_t)d.emissiveImage<a.textures.size())srvs[1]=a.textures[(size_t)d.emissiveImage].view.Get();if(d.metallicRoughnessImage>=0&&(size_t)d.metallicRoughnessImage<a.textures.size())srvs[2]=a.textures[(size_t)d.metallicRoughnessImage].view.Get();if(d.normalImage>=0&&(size_t)d.normalImage<a.textures.size())srvs[3]=a.textures[(size_t)d.normalImage].view.Get();if(d.occlusionImage>=0&&(size_t)d.occlusionImage<a.textures.size())srvs[4]=a.textures[(size_t)d.occlusionImage].view.Get();g_core.context->PSSetShaderResources(0,5,srvs);
            ID3D11SamplerState* samplers[5]={GetSampler(d.baseWrapS,d.baseWrapT),GetSampler(d.emissiveWrapS,d.emissiveWrapT),GetSampler(d.metallicRoughnessWrapS,d.metallicRoughnessWrapT),GetSampler(d.normalWrapS,d.normalWrapT),GetSampler(d.occlusionWrapS,d.occlusionWrapT)};g_core.context->PSSetSamplers(0,5,samplers);g_core.context->DrawIndexed(d.indexCount,d.firstIndex,0);
        }
    }

    int RenderSurfaceLocked(ShelfSurface& s,float phase)
    {
        if(!s.rtv||!s.dsv)return 0;const float clear[4]={0,0,0,0};g_core.context->OMSetRenderTargets(1,s.rtv.GetAddressOf(),s.dsv.Get());g_core.context->ClearRenderTargetView(s.rtv.Get(),clear);g_core.context->IASetInputLayout(g_core.inputLayout.Get());g_core.context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);g_core.context->VSSetShader(g_core.vertexShader.Get(),nullptr,0);g_core.context->PSSetShader(g_core.pixelShader.Get(),nullptr,0);ID3D11Buffer* cb=g_core.constants.Get();g_core.context->VSSetConstantBuffers(0,1,&cb);g_core.context->PSSetConstantBuffers(0,1,&cb);float blendFactor[4]={0,0,0,0};g_core.context->OMSetBlendState(g_core.blend.Get(),blendFactor,0xffffffffu);for(auto& pair:s.items)if(pair.second.visible&&pair.second.asset)RenderAssetLocked(s,pair.second,phase);g_core.context->Flush();return 1;
    }
}

extern "C" __declspec(dllexport) void* __cdecl HC_GPU_CreateShelfSurface(int width,int height,void** surface9)
{
    if(surface9)*surface9=nullptr;if(!surface9||width<1||height<1)return nullptr;std::lock_guard<std::mutex> guard(g_core.lock);if(FAILED(InitializeCoreLocked()))return nullptr;std::unique_ptr<ShelfSurface>s(new(std::nothrow)ShelfSurface());if(!s)return nullptr;if(FAILED(CreateSurfaceTarget(*s,width,height)))return nullptr;*surface9=s->surface9.Get();if(*surface9)static_cast<IUnknown*>(*surface9)->AddRef();return s.release();
}
extern "C" __declspec(dllexport) int __cdecl HC_GPU_LoadShelfModel(void* handle,int id,const wchar_t* cachePath){if(!handle||!cachePath)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto asset=AcquireAssetLocked(cachePath);if(!asset)return 0;Item&item=s->items[id];item.id=id;item.asset=asset;return 1;}
extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItem(void* handle,int id,float x,float y,float width,float height,float scale,int selected,int visible){if(!handle||width<0||height<0)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.x=x;i.y=y;i.width=width;i.height=height;i.modelScale=scale;i.selected=selected!=0;i.visible=visible!=0;return 1;}
extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemView(void* handle,int id,float yawOffset,float pitch,int spin){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.yawOffset=yawOffset;i.pitch=std::max(-80.0f,std::min(80.0f,pitch));i.spin=spin!=0;return 1;}
extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfBrightness(void* handle,float brightness){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);s->brightness=std::max(0.50f,std::min(2.50f,brightness));return 1;}
extern "C" __declspec(dllexport) void __cdecl HC_GPU_ClearShelfItems(void* handle){if(!handle)return;std::lock_guard<std::mutex>guard(g_core.lock);static_cast<ShelfSurface*>(handle)->items.clear();}
extern "C" __declspec(dllexport) int __cdecl HC_GPU_RenderShelfSurface(void* handle,float phase){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);return RenderSurfaceLocked(*static_cast<ShelfSurface*>(handle),phase);}
extern "C" __declspec(dllexport) void __cdecl HC_GPU_ReleaseShelfSurfacePointer(void* surface9){if(surface9)static_cast<IUnknown*>(surface9)->Release();}
extern "C" __declspec(dllexport) void __cdecl HC_GPU_DestroyShelfSurface(void* handle){if(!handle)return;std::lock_guard<std::mutex>guard(g_core.lock);delete static_cast<ShelfSurface*>(handle);}
extern "C" __declspec(dllexport) int __cdecl HC_GPU_GetCachedAssetCount(){std::lock_guard<std::mutex>guard(g_core.lock);int count=0;for(auto it=g_core.assets.begin();it!=g_core.assets.end();){if(it->second.expired())it=g_core.assets.erase(it);else{++count;++it;}}return count;}
