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
#include <cstring>
#include <memory>

#include "HuymaierD3D11ShelfAsset.h"

using namespace DirectX;
using Microsoft::WRL::ComPtr;
using HuymaierGpuShelf::Asset;
using HuymaierGpuShelf::DrawBatch;
using HuymaierGpuShelf::Vertex;
using HuymaierGpuShelf::HcShelfShaderSource;

namespace
{
    // HUYMAIER_D3D11_CACHED_ASSET_SMOKE_V3
    // HUYMAIER_D3D11_CACHED_ASSET_SMOKE_V5_COLOR_PRESERVATION
    // WARP renders HC3D caches with the exact production shelf shader. The normal
    // pass runs at the UI's minimum 50% brightness. A second diagnostic pass forces
    // a deliberately over-range purple emissive material; it must remain purple
    // rather than channel-clipping to white.
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

    D3D11_TEXTURE_ADDRESS_MODE AddressMode(int wrap)
    {
        if(wrap==33071)return D3D11_TEXTURE_ADDRESS_CLAMP;
        if(wrap==33648)return D3D11_TEXTURE_ADDRESS_MIRROR;
        return D3D11_TEXTURE_ADDRESS_WRAP;
    }

    int RunCachedSmoke(const wchar_t* cachePath,bool forceHotPurple)
    {
        const D3D_FEATURE_LEVEL levels[]={D3D_FEATURE_LEVEL_11_0,D3D_FEATURE_LEVEL_10_1,D3D_FEATURE_LEVEL_10_0};
        D3D_FEATURE_LEVEL level{};ComPtr<ID3D11Device> device;ComPtr<ID3D11DeviceContext> context;
        HRESULT hr=D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_WARP,nullptr,D3D11_CREATE_DEVICE_BGRA_SUPPORT,levels,ARRAYSIZE(levels),D3D11_SDK_VERSION,device.GetAddressOf(),&level,context.GetAddressOf());
        if(FAILED(hr))return 30;
        Asset* raw=nullptr;hr=HuymaierGpuShelf::LoadAsset(device.Get(),context.Get(),cachePath,&raw);if(FAILED(hr)||!raw)return 31;
        std::unique_ptr<Asset,void(*)(Asset*)> asset(raw,HuymaierGpuShelf::DestroyAsset);

        ComPtr<ID3DBlob> vsb,psb,err;
        if(FAILED(D3DCompile(HcShelfShaderSource,strlen(HcShelfShaderSource),"HC3Dv5ProductionSmoke",nullptr,nullptr,"VSMain","vs_4_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,vsb.GetAddressOf(),err.GetAddressOf())))return 32;
        err.Reset();if(FAILED(D3DCompile(HcShelfShaderSource,strlen(HcShelfShaderSource),"HC3Dv5ProductionSmoke",nullptr,nullptr,"PSMain","ps_4_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,psb.GetAddressOf(),err.GetAddressOf())))return 33;
        ComPtr<ID3D11VertexShader> vs;ComPtr<ID3D11PixelShader> ps;ComPtr<ID3D11InputLayout> layout;
        if(FAILED(device->CreateVertexShader(vsb->GetBufferPointer(),vsb->GetBufferSize(),nullptr,vs.GetAddressOf())))return 34;
        if(FAILED(device->CreatePixelShader(psb->GetBufferPointer(),psb->GetBufferSize(),nullptr,ps.GetAddressOf())))return 35;
        const D3D11_INPUT_ELEMENT_DESC elements[]={
            {"POSITION",0,DXGI_FORMAT_R32G32B32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"NORMAL",0,DXGI_FORMAT_R32G32B32_FLOAT,0,12,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TANGENT",0,DXGI_FORMAT_R32G32B32A32_FLOAT,0,24,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",0,DXGI_FORMAT_R32G32_FLOAT,0,40,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",1,DXGI_FORMAT_R32G32_FLOAT,0,48,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",2,DXGI_FORMAT_R32G32_FLOAT,0,56,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",3,DXGI_FORMAT_R32G32_FLOAT,0,64,D3D11_INPUT_PER_VERTEX_DATA,0},
            {"TEXCOORD",4,DXGI_FORMAT_R32G32_FLOAT,0,72,D3D11_INPUT_PER_VERTEX_DATA,0}};
        if(FAILED(device->CreateInputLayout(elements,ARRAYSIZE(elements),vsb->GetBufferPointer(),vsb->GetBufferSize(),layout.GetAddressOf())))return 36;
        D3D11_BUFFER_DESC cbd{};cbd.ByteWidth=sizeof(Constants);cbd.Usage=D3D11_USAGE_DYNAMIC;cbd.BindFlags=D3D11_BIND_CONSTANT_BUFFER;cbd.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;ComPtr<ID3D11Buffer> cb;if(FAILED(device->CreateBuffer(&cbd,nullptr,cb.GetAddressOf())))return 37;

        const UINT width=256,height=192;D3D11_TEXTURE2D_DESC td{};td.Width=width;td.Height=height;td.MipLevels=1;td.ArraySize=1;td.Format=DXGI_FORMAT_B8G8R8A8_UNORM;td.SampleDesc.Count=1;td.Usage=D3D11_USAGE_DEFAULT;td.BindFlags=D3D11_BIND_RENDER_TARGET;
        ComPtr<ID3D11Texture2D> target;ComPtr<ID3D11RenderTargetView> rtv;if(FAILED(device->CreateTexture2D(&td,nullptr,target.GetAddressOf()))||FAILED(device->CreateRenderTargetView(target.Get(),nullptr,rtv.GetAddressOf())))return 38;
        D3D11_TEXTURE2D_DESC dd=td;dd.Format=DXGI_FORMAT_D24_UNORM_S8_UINT;dd.BindFlags=D3D11_BIND_DEPTH_STENCIL;ComPtr<ID3D11Texture2D> depth;ComPtr<ID3D11DepthStencilView>dsv;if(FAILED(device->CreateTexture2D(&dd,nullptr,depth.GetAddressOf()))||FAILED(device->CreateDepthStencilView(depth.Get(),nullptr,dsv.GetAddressOf())))return 39;
        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_NONE;rd.DepthClipEnable=TRUE;rd.FrontCounterClockwise=TRUE;ComPtr<ID3D11RasterizerState> rs;if(FAILED(device->CreateRasterizerState(&rd,rs.GetAddressOf())))return 40;
        D3D11_BLEND_DESC bd{};bd.RenderTarget[0].BlendEnable=TRUE;bd.RenderTarget[0].SrcBlend=D3D11_BLEND_ONE;bd.RenderTarget[0].DestBlend=D3D11_BLEND_INV_SRC_ALPHA;bd.RenderTarget[0].BlendOp=D3D11_BLEND_OP_ADD;bd.RenderTarget[0].SrcBlendAlpha=D3D11_BLEND_ONE;bd.RenderTarget[0].DestBlendAlpha=D3D11_BLEND_INV_SRC_ALPHA;bd.RenderTarget[0].BlendOpAlpha=D3D11_BLEND_OP_ADD;bd.RenderTarget[0].RenderTargetWriteMask=D3D11_COLOR_WRITE_ENABLE_ALL;ComPtr<ID3D11BlendState> blend;if(FAILED(device->CreateBlendState(&bd,blend.GetAddressOf())))return 41;
        const float clear[4]={0,0,0,0};context->OMSetRenderTargets(1,rtv.GetAddressOf(),dsv.Get());context->ClearRenderTargetView(rtv.Get(),clear);context->ClearDepthStencilView(dsv.Get(),D3D11_CLEAR_DEPTH,1,0);
        D3D11_VIEWPORT vp{};vp.Width=(float)width;vp.Height=(float)height;vp.MaxDepth=1;context->RSSetViewports(1,&vp);context->RSSetState(rs.Get());UINT stride=sizeof(Vertex),offset=0;ID3D11Buffer* vb=asset->vertexBuffer.Get();context->IASetVertexBuffers(0,1,&vb,&stride,&offset);context->IASetIndexBuffer(asset->indexBuffer.Get(),DXGI_FORMAT_R32_UINT,0);context->IASetInputLayout(layout.Get());context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);context->VSSetShader(vs.Get(),nullptr,0);context->PSSetShader(ps.Get(),nullptr,0);ID3D11Buffer* cbRaw=cb.Get();context->VSSetConstantBuffers(0,1,&cbRaw);context->PSSetConstantBuffers(0,1,&cbRaw);float bf[4]={0,0,0,0};context->OMSetBlendState(blend.Get(),bf,0xffffffffu);
        const float cx=(asset->minBounds[0]+asset->maxBounds[0])*.5f,cy=(asset->minBounds[1]+asset->maxBounds[1])*.5f,cz=(asset->minBounds[2]+asset->maxBounds[2])*.5f;const float sx=asset->maxBounds[0]-asset->minBounds[0],sy=asset->maxBounds[1]-asset->minBounds[1],sz=asset->maxBounds[2]-asset->minBounds[2];float diameter=std::sqrt(sx*sx+sy*sy+sz*sz);if(diameter<.00001f)diameter=1;
        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(2.45f/diameter,2.45f/diameter,2.45f/diameter)*XMMatrixRotationY(XMConvertToRadians(18.0f));XMMATRIX view=XMMatrixLookAtLH(XMVectorSet(0,.04f,-4.2f,1),XMVectorZero(),XMVectorSet(0,1,0,0));XMMATRIX proj=XMMatrixPerspectiveFovLH(XMConvertToRadians(34.0f),(float)width/(float)height,.01f,100.0f);XMMATRIX wvp=world*view*proj;
        for(const DrawBatch& d:asset->draws)
        {
            Constants c{};XMStoreFloat4x4(&c.worldViewProjection,wvp);XMStoreFloat4x4(&c.world,world);
            if(forceHotPurple)
            {
                c.baseColor=XMFLOAT4(.43f,.14f,.70f,1.0f);
                c.emissive=XMFLOAT4(.43f,.14f,.70f,15.0f);
                c.surface=XMFLOAT4(1.0f,.20f,1.0f,0.0f);
                c.extra=XMFLOAT4(.5f,0.0f,.50f,0.0f);
                c.materialParams=XMFLOAT4(1,1,0,0);
                c.flags=XMINT4(0,0,0,(d.flags&1)?1:0);
                c.maps=XMINT4(0,0,0,(d.flags&1)?1:0);
            }
            else
            {
                c.baseColor=XMFLOAT4(d.baseColor[0],d.baseColor[1],d.baseColor[2],d.baseColor[3]);c.emissive=XMFLOAT4(d.emissiveColor[0],d.emissiveColor[1],d.emissiveColor[2],d.emissiveStrength);c.surface=XMFLOAT4(d.metallic,d.roughness,d.specular,d.clearcoat);c.extra=XMFLOAT4(d.alphaCutoff,0.0f,.50f,0.0f);c.materialParams=XMFLOAT4(d.normalScale,d.occlusionStrength,0,0);c.flags=XMINT4(d.baseImage>=0?1:0,d.emissiveImage>=0?1:0,d.alphaMode,(d.flags&2)?1:0);c.maps=XMINT4(d.metallicRoughnessImage>=0?1:0,d.normalImage>=0?1:0,d.occlusionImage>=0?1:0,(d.flags&1)?1:0);
            }
            D3D11_MAPPED_SUBRESOURCE map{};if(FAILED(context->Map(cb.Get(),0,D3D11_MAP_WRITE_DISCARD,0,&map)))return 42;memcpy(map.pData,&c,sizeof(c));context->Unmap(cb.Get(),0);
            ID3D11ShaderResourceView* srvs[5]={nullptr,nullptr,nullptr,nullptr,nullptr};
            if(!forceHotPurple){if(d.baseImage>=0&&(size_t)d.baseImage<asset->textures.size())srvs[0]=asset->textures[(size_t)d.baseImage].view.Get();if(d.emissiveImage>=0&&(size_t)d.emissiveImage<asset->textures.size())srvs[1]=asset->textures[(size_t)d.emissiveImage].view.Get();if(d.metallicRoughnessImage>=0&&(size_t)d.metallicRoughnessImage<asset->textures.size())srvs[2]=asset->textures[(size_t)d.metallicRoughnessImage].view.Get();if(d.normalImage>=0&&(size_t)d.normalImage<asset->textures.size())srvs[3]=asset->textures[(size_t)d.normalImage].view.Get();if(d.occlusionImage>=0&&(size_t)d.occlusionImage<asset->textures.size())srvs[4]=asset->textures[(size_t)d.occlusionImage].view.Get();}
            context->PSSetShaderResources(0,5,srvs);
            D3D11_SAMPLER_DESC sd{};sd.Filter=D3D11_FILTER_MIN_MAG_MIP_LINEAR;sd.AddressW=D3D11_TEXTURE_ADDRESS_CLAMP;sd.MaxLOD=D3D11_FLOAT32_MAX;ComPtr<ID3D11SamplerState> owned[5];ID3D11SamplerState* samplers[5]={};int wraps[10]={d.baseWrapS,d.baseWrapT,d.emissiveWrapS,d.emissiveWrapT,d.metallicRoughnessWrapS,d.metallicRoughnessWrapT,d.normalWrapS,d.normalWrapT,d.occlusionWrapS,d.occlusionWrapT};for(int si=0;si<5;++si){sd.AddressU=AddressMode(wraps[si*2]);sd.AddressV=AddressMode(wraps[si*2+1]);if(FAILED(device->CreateSamplerState(&sd,owned[si].GetAddressOf())))return 43;samplers[si]=owned[si].Get();}context->PSSetSamplers(0,5,samplers);
            context->DrawIndexed(d.indexCount,d.firstIndex,0);
        }
        context->Flush();D3D11_TEXTURE2D_DESC sd=td;sd.Usage=D3D11_USAGE_STAGING;sd.BindFlags=0;sd.CPUAccessFlags=D3D11_CPU_ACCESS_READ;ComPtr<ID3D11Texture2D> staging;if(FAILED(device->CreateTexture2D(&sd,nullptr,staging.GetAddressOf())))return 44;context->CopyResource(staging.Get(),target.Get());D3D11_MAPPED_SUBRESOURCE mapped{};if(FAILED(context->Map(staging.Get(),0,D3D11_MAP_READ,0,&mapped)))return 45;
        int visible=0,colorful=0,brightColorful=0,semi=0,neutralHot=0;
        for(UINT y=0;y<height;y+=2){const uint8_t* row=(const uint8_t*)mapped.pData+y*mapped.RowPitch;for(UINT x=0;x<width;x+=2){const uint8_t* p=row+x*4;if(p[3]>8){visible++;int mx=std::max(p[0],std::max(p[1],p[2]));int mn=std::min(p[0],std::min(p[1],p[2]));if(mx-mn>24){colorful++;if(mx>105)brightColorful++;}if(mx>225&&mx-mn<18)neutralHot++;if(p[3]<247)semi++;}}}context->Unmap(staging.Get(),0);
        if(visible<80)return 46;if(colorful<20)return forceHotPurple?51:47;if(brightColorful<20)return forceHotPurple?52:49;if(forceHotPurple&&neutralHot>visible/8)return 53;
        bool hasBlend=false;for(const DrawBatch& d:asset->draws)if(d.alphaMode==2){hasBlend=true;break;}if(!forceHotPurple&&!hasBlend&&semi>visible/20)return 48;
        return 1;
    }
}

extern "C" __declspec(dllexport) int __cdecl HC_D3D11CachedAssetSmokeTest(const wchar_t* cachePath)
{
    try
    {
        int normal=RunCachedSmoke(cachePath,false);if(normal!=1)return normal;
        int hotPurple=RunCachedSmoke(cachePath,true);if(hotPurple!=1)return hotPurple;
        return 1;
    }
    catch(...){return 99;}
}
