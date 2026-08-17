#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <d3d11.h>
#include <d3d9.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <wrl/client.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <mutex>

#include "HuymaierD3D11ShelfAsset.h"

using Microsoft::WRL::ComPtr;
using HuymaierGpuShelf::HcShelfShaderSource;
using HuymaierGpuShelf::Vertex;

namespace
{
    struct SmokeVertex { float x,y,z; float r,g,b,a; };
    struct ProductionConstants
    {
        float worldViewProjection[16]; float world[16]; float baseColor[4]; float emissive[4];
        float surface[4]; float extra[4]; float materialParams[4]; int flags[4]; int maps[4];
    };
    struct ShelfSurface
    {
        UINT width=0,height=0; ComPtr<IDirect3D9Ex>d3d9; ComPtr<IDirect3DDevice9Ex>device9;
        ComPtr<IDirect3DTexture9>sharedTexture9; ComPtr<IDirect3DSurface9>sharedSurface9; HANDLE sharedHandle=nullptr;
        ComPtr<ID3D11Device>device11; ComPtr<ID3D11DeviceContext>context11; ComPtr<ID3D11Texture2D>sharedTexture11;
        ComPtr<ID3D11RenderTargetView>rtv; ComPtr<ID3D11VertexShader>vertexShader; ComPtr<ID3D11PixelShader>pixelShader;
        ComPtr<ID3D11InputLayout>inputLayout; ComPtr<ID3D11Buffer>smokeVertexBuffer; D3D_FEATURE_LEVEL featureLevel=D3D_FEATURE_LEVEL_10_0; std::mutex lock;
    };

    const char* kSmokeShader=R"HLSL(
struct VSInput{float3 position:POSITION;float4 color:COLOR0;};
struct VSOutput{float4 position:SV_POSITION;float4 color:COLOR0;};
VSOutput VSMain(VSInput input){VSOutput o;o.position=float4(input.position,1.0);o.color=input.color;return o;}
float4 PSMain(VSOutput input):SV_TARGET{return float4(input.color.rgb*input.color.a,input.color.a);}
)HLSL";

    HRESULT CompileShader(const char* entry,const char* target,ID3DBlob** blob)
    {
        UINT flags=D3DCOMPILE_ENABLE_STRICTNESS;
#if defined(_DEBUG)
        flags|=D3DCOMPILE_DEBUG|D3DCOMPILE_SKIP_OPTIMIZATION;
#else
        flags|=D3DCOMPILE_OPTIMIZATION_LEVEL3;
#endif
        ComPtr<ID3DBlob>errors;HRESULT hr=D3DCompile(kSmokeShader,strlen(kSmokeShader),"HuymaierD3D11ShelfRenderer",nullptr,nullptr,entry,target,flags,0,blob,errors.GetAddressOf());
        if(FAILED(hr)&&errors)OutputDebugStringA(static_cast<const char*>(errors->GetBufferPointer()));return hr;
    }

    HRESULT CreateD3D11Device(bool allowWarp,ID3D11Device** device,ID3D11DeviceContext** context,D3D_FEATURE_LEVEL* level)
    {
        const D3D_FEATURE_LEVEL levels[]={D3D_FEATURE_LEVEL_11_1,D3D_FEATURE_LEVEL_11_0,D3D_FEATURE_LEVEL_10_1,D3D_FEATURE_LEVEL_10_0};UINT flags=D3D11_CREATE_DEVICE_BGRA_SUPPORT;
        HRESULT hr=D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_HARDWARE,nullptr,flags,levels,ARRAYSIZE(levels),D3D11_SDK_VERSION,device,level,context);
        if(FAILED(hr)&&allowWarp)hr=D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_WARP,nullptr,flags,levels,ARRAYSIZE(levels),D3D11_SDK_VERSION,device,level,context);return hr;
    }

    HRESULT CreateShaders(ShelfSurface& s)
    {
        ComPtr<ID3DBlob>vsb,psb;HRESULT hr=CompileShader("VSMain","vs_4_0",vsb.GetAddressOf());if(FAILED(hr))return hr;hr=CompileShader("PSMain","ps_4_0",psb.GetAddressOf());if(FAILED(hr))return hr;
        hr=s.device11->CreateVertexShader(vsb->GetBufferPointer(),vsb->GetBufferSize(),nullptr,s.vertexShader.GetAddressOf());if(FAILED(hr))return hr;
        hr=s.device11->CreatePixelShader(psb->GetBufferPointer(),psb->GetBufferSize(),nullptr,s.pixelShader.GetAddressOf());if(FAILED(hr))return hr;
        const D3D11_INPUT_ELEMENT_DESC layout[]={{"POSITION",0,DXGI_FORMAT_R32G32B32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},{"COLOR",0,DXGI_FORMAT_R32G32B32A32_FLOAT,0,12,D3D11_INPUT_PER_VERTEX_DATA,0}};
        return s.device11->CreateInputLayout(layout,ARRAYSIZE(layout),vsb->GetBufferPointer(),vsb->GetBufferSize(),s.inputLayout.GetAddressOf());
    }

    HRESULT CreateSmokeGeometry(ShelfSurface& s)
    {
        const SmokeVertex v[]={{-.72f,-.68f,0,.10f,.75f,1,.96f},{0,.74f,0,1,.82f,.18f,.96f},{.72f,-.68f,0,.92f,.20f,.36f,.96f}};
        D3D11_BUFFER_DESC d{};d.ByteWidth=sizeof(v);d.Usage=D3D11_USAGE_IMMUTABLE;d.BindFlags=D3D11_BIND_VERTEX_BUFFER;D3D11_SUBRESOURCE_DATA data{};data.pSysMem=v;return s.device11->CreateBuffer(&d,&data,s.smokeVertexBuffer.GetAddressOf());
    }

    HRESULT CreateOffscreenTarget(ShelfSurface& s,UINT width,UINT height)
    {
        D3D11_TEXTURE2D_DESC t{};t.Width=width;t.Height=height;t.MipLevels=1;t.ArraySize=1;t.Format=DXGI_FORMAT_B8G8R8A8_UNORM;t.SampleDesc.Count=1;t.Usage=D3D11_USAGE_DEFAULT;t.BindFlags=D3D11_BIND_RENDER_TARGET;
        HRESULT hr=s.device11->CreateTexture2D(&t,nullptr,s.sharedTexture11.GetAddressOf());if(FAILED(hr))return hr;return s.device11->CreateRenderTargetView(s.sharedTexture11.Get(),nullptr,s.rtv.GetAddressOf());
    }

    HRESULT CreateWpfSharedTarget(ShelfSurface& s,UINT width,UINT height)
    {
        HRESULT hr=Direct3DCreate9Ex(D3D_SDK_VERSION,s.d3d9.GetAddressOf());if(FAILED(hr))return hr;D3DPRESENT_PARAMETERS pp{};pp.Windowed=TRUE;pp.SwapEffect=D3DSWAPEFFECT_DISCARD;pp.hDeviceWindow=GetDesktopWindow();pp.BackBufferWidth=1;pp.BackBufferHeight=1;pp.BackBufferFormat=D3DFMT_A8R8G8B8;pp.PresentationInterval=D3DPRESENT_INTERVAL_IMMEDIATE;
        hr=s.d3d9->CreateDeviceEx(D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,GetDesktopWindow(),D3DCREATE_HARDWARE_VERTEXPROCESSING|D3DCREATE_MULTITHREADED|D3DCREATE_FPU_PRESERVE,&pp,nullptr,s.device9.GetAddressOf());if(FAILED(hr))return hr;
        s.sharedHandle=nullptr;hr=s.device9->CreateTexture(width,height,1,D3DUSAGE_RENDERTARGET,D3DFMT_A8R8G8B8,D3DPOOL_DEFAULT,s.sharedTexture9.GetAddressOf(),&s.sharedHandle);if(FAILED(hr)||!s.sharedHandle)return FAILED(hr)?hr:E_FAIL;
        if(FAILED(hr=s.sharedTexture9->GetSurfaceLevel(0,s.sharedSurface9.GetAddressOf())))return hr;if(FAILED(hr=CreateD3D11Device(false,s.device11.GetAddressOf(),s.context11.GetAddressOf(),&s.featureLevel)))return hr;
        if(FAILED(hr=s.device11->OpenSharedResource(s.sharedHandle,__uuidof(ID3D11Texture2D),reinterpret_cast<void**>(s.sharedTexture11.GetAddressOf()))))return hr;
        if(FAILED(hr=s.device11->CreateRenderTargetView(s.sharedTexture11.Get(),nullptr,s.rtv.GetAddressOf())))return hr;if(FAILED(hr=CreateShaders(s)))return hr;if(FAILED(hr=CreateSmokeGeometry(s)))return hr;s.width=width;s.height=height;return S_OK;
    }

    HRESULT RenderSmokeInternal(ShelfSurface& s,float phase)
    {
        if(!s.context11||!s.rtv||!s.vertexShader||!s.pixelShader||!s.inputLayout||!s.smokeVertexBuffer)return E_UNEXPECTED;const float clear[4]={0,0,0,0};s.context11->OMSetRenderTargets(1,s.rtv.GetAddressOf(),nullptr);s.context11->ClearRenderTargetView(s.rtv.Get(),clear);
        D3D11_VIEWPORT vp{};vp.Width=(float)s.width;vp.Height=(float)s.height;vp.MaxDepth=1;s.context11->RSSetViewports(1,&vp);UINT stride=sizeof(SmokeVertex),offset=0;ID3D11Buffer*vb=s.smokeVertexBuffer.Get();s.context11->IASetVertexBuffers(0,1,&vb,&stride,&offset);s.context11->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);s.context11->IASetInputLayout(s.inputLayout.Get());s.context11->VSSetShader(s.vertexShader.Get(),nullptr,0);s.context11->PSSetShader(s.pixelShader.Get(),nullptr,0);
        const float shift=std::sin(phase)*.02f;vp.TopLeftX=shift>0?shift*s.width:0;vp.Width=(float)s.width-std::fabs(shift*s.width);s.context11->RSSetViewports(1,&vp);s.context11->Draw(3,0);s.context11->Flush();return S_OK;
    }

    int RunOffscreenSmokeTest()
    {
        ShelfSurface s;HRESULT hr=CreateD3D11Device(true,s.device11.GetAddressOf(),s.context11.GetAddressOf(),&s.featureLevel);if(FAILED(hr))return 10;s.width=128;s.height=96;if(FAILED(hr=CreateOffscreenTarget(s,s.width,s.height)))return 11;if(FAILED(hr=CreateShaders(s)))return 12;if(FAILED(hr=CreateSmokeGeometry(s)))return 13;if(FAILED(hr=RenderSmokeInternal(s,.35f)))return 14;
        D3D11_TEXTURE2D_DESC d{};s.sharedTexture11->GetDesc(&d);d.Usage=D3D11_USAGE_STAGING;d.BindFlags=0;d.CPUAccessFlags=D3D11_CPU_ACCESS_READ;d.MiscFlags=0;ComPtr<ID3D11Texture2D>stage;if(FAILED(s.device11->CreateTexture2D(&d,nullptr,stage.GetAddressOf())))return 15;s.context11->CopyResource(stage.Get(),s.sharedTexture11.Get());D3D11_MAPPED_SUBRESOURCE m{};if(FAILED(s.context11->Map(stage.Get(),0,D3D11_MAP_READ,0,&m)))return 16;
        int colored=0;for(UINT y=0;y<d.Height;y+=4){const uint8_t*row=(const uint8_t*)m.pData+y*m.RowPitch;for(UINT x=0;x<d.Width;x+=4){const uint8_t*p=row+x*4;if(p[3]>32&&(p[0]>24||p[1]>24||p[2]>24))colored++;}}s.context11->Unmap(stage.Get(),0);return colored>=40?1:17;
    }

    int RunProductionHuePreservationSmokeTest()
    {
        // HUYMAIER_D3D11_PACKAGED_HUE_SMOKE_V2_CULL_SAFE
        const D3D_FEATURE_LEVEL levels[]={D3D_FEATURE_LEVEL_11_0,D3D_FEATURE_LEVEL_10_1,D3D_FEATURE_LEVEL_10_0};D3D_FEATURE_LEVEL level{};ComPtr<ID3D11Device>device;ComPtr<ID3D11DeviceContext>context;
        HRESULT hr=D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_WARP,nullptr,D3D11_CREATE_DEVICE_BGRA_SUPPORT,levels,ARRAYSIZE(levels),D3D11_SDK_VERSION,device.GetAddressOf(),&level,context.GetAddressOf());if(FAILED(hr))return 18;
        ComPtr<ID3DBlob>vsb,psb,errors;hr=D3DCompile(HcShelfShaderSource,strlen(HcShelfShaderSource),"HuymaierPackagedHueSmoke",nullptr,nullptr,"VSMain","vs_4_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,vsb.GetAddressOf(),errors.GetAddressOf());if(FAILED(hr))return 19;errors.Reset();hr=D3DCompile(HcShelfShaderSource,strlen(HcShelfShaderSource),"HuymaierPackagedHueSmoke",nullptr,nullptr,"PSMain","ps_4_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,psb.GetAddressOf(),errors.GetAddressOf());if(FAILED(hr))return 20;
        ComPtr<ID3D11VertexShader>vs;ComPtr<ID3D11PixelShader>ps;ComPtr<ID3D11InputLayout>layout;if(FAILED(device->CreateVertexShader(vsb->GetBufferPointer(),vsb->GetBufferSize(),nullptr,vs.GetAddressOf())))return 21;if(FAILED(device->CreatePixelShader(psb->GetBufferPointer(),psb->GetBufferSize(),nullptr,ps.GetAddressOf())))return 22;
        const D3D11_INPUT_ELEMENT_DESC elements[]={{"POSITION",0,DXGI_FORMAT_R32G32B32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},{"NORMAL",0,DXGI_FORMAT_R32G32B32_FLOAT,0,12,D3D11_INPUT_PER_VERTEX_DATA,0},{"TANGENT",0,DXGI_FORMAT_R32G32B32A32_FLOAT,0,24,D3D11_INPUT_PER_VERTEX_DATA,0},{"TEXCOORD",0,DXGI_FORMAT_R32G32_FLOAT,0,40,D3D11_INPUT_PER_VERTEX_DATA,0},{"TEXCOORD",1,DXGI_FORMAT_R32G32_FLOAT,0,48,D3D11_INPUT_PER_VERTEX_DATA,0},{"TEXCOORD",2,DXGI_FORMAT_R32G32_FLOAT,0,56,D3D11_INPUT_PER_VERTEX_DATA,0},{"TEXCOORD",3,DXGI_FORMAT_R32G32_FLOAT,0,64,D3D11_INPUT_PER_VERTEX_DATA,0},{"TEXCOORD",4,DXGI_FORMAT_R32G32_FLOAT,0,72,D3D11_INPUT_PER_VERTEX_DATA,0}};if(FAILED(device->CreateInputLayout(elements,ARRAYSIZE(elements),vsb->GetBufferPointer(),vsb->GetBufferSize(),layout.GetAddressOf())))return 23;
        Vertex verts[3]{};const float pos[9]={-.82f,-.72f,0,.82f,-.72f,0,0,.82f,0};for(int i=0;i<3;i++){verts[i].px=pos[i*3];verts[i].py=pos[i*3+1];verts[i].pz=pos[i*3+2];verts[i].nz=-1;verts[i].tx=1;verts[i].tw=1;}D3D11_BUFFER_DESC vbd{};vbd.ByteWidth=sizeof(verts);vbd.Usage=D3D11_USAGE_IMMUTABLE;vbd.BindFlags=D3D11_BIND_VERTEX_BUFFER;D3D11_SUBRESOURCE_DATA vdata{};vdata.pSysMem=verts;ComPtr<ID3D11Buffer>vb;if(FAILED(device->CreateBuffer(&vbd,&vdata,vb.GetAddressOf())))return 24;
        ProductionConstants c{};for(int i=0;i<16;i++){c.worldViewProjection[i]=(i%5)==0?1.f:0.f;c.world[i]=(i%5)==0?1.f:0.f;}c.baseColor[0]=.43f;c.baseColor[1]=.14f;c.baseColor[2]=.70f;c.baseColor[3]=1;c.emissive[0]=.43f;c.emissive[1]=.14f;c.emissive[2]=.70f;c.emissive[3]=15;c.surface[0]=1;c.surface[1]=.2f;c.surface[2]=1;c.extra[0]=.5f;c.extra[2]=.5f;c.materialParams[0]=1;c.materialParams[1]=1;D3D11_BUFFER_DESC cbd{};cbd.ByteWidth=sizeof(c);cbd.Usage=D3D11_USAGE_IMMUTABLE;cbd.BindFlags=D3D11_BIND_CONSTANT_BUFFER;D3D11_SUBRESOURCE_DATA cd{};cd.pSysMem=&c;ComPtr<ID3D11Buffer>cb;if(FAILED(device->CreateBuffer(&cbd,&cd,cb.GetAddressOf())))return 25;
        D3D11_TEXTURE2D_DESC td{};td.Width=128;td.Height=96;td.MipLevels=1;td.ArraySize=1;td.Format=DXGI_FORMAT_B8G8R8A8_UNORM;td.SampleDesc.Count=1;td.Usage=D3D11_USAGE_DEFAULT;td.BindFlags=D3D11_BIND_RENDER_TARGET;ComPtr<ID3D11Texture2D>target;ComPtr<ID3D11RenderTargetView>rtv;if(FAILED(device->CreateTexture2D(&td,nullptr,target.GetAddressOf()))||FAILED(device->CreateRenderTargetView(target.Get(),nullptr,rtv.GetAddressOf())))return 26;
        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_NONE;rd.DepthClipEnable=TRUE;ComPtr<ID3D11RasterizerState>rs;if(FAILED(device->CreateRasterizerState(&rd,rs.GetAddressOf())))return 27;
        const float clear[4]={0,0,0,0};context->OMSetRenderTargets(1,rtv.GetAddressOf(),nullptr);context->ClearRenderTargetView(rtv.Get(),clear);D3D11_VIEWPORT vp{};vp.Width=128;vp.Height=96;vp.MaxDepth=1;context->RSSetViewports(1,&vp);context->RSSetState(rs.Get());UINT stride=sizeof(Vertex),offset=0;ID3D11Buffer*vbRaw=vb.Get();context->IASetVertexBuffers(0,1,&vbRaw,&stride,&offset);context->IASetInputLayout(layout.Get());context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);context->VSSetShader(vs.Get(),nullptr,0);context->PSSetShader(ps.Get(),nullptr,0);ID3D11Buffer*cbRaw=cb.Get();context->VSSetConstantBuffers(0,1,&cbRaw);context->PSSetConstantBuffers(0,1,&cbRaw);context->Draw(3,0);context->Flush();
        D3D11_TEXTURE2D_DESC sd=td;sd.Usage=D3D11_USAGE_STAGING;sd.BindFlags=0;sd.CPUAccessFlags=D3D11_CPU_ACCESS_READ;ComPtr<ID3D11Texture2D>stage;if(FAILED(device->CreateTexture2D(&sd,nullptr,stage.GetAddressOf())))return 28;context->CopyResource(stage.Get(),target.Get());D3D11_MAPPED_SUBRESOURCE m{};if(FAILED(context->Map(stage.Get(),0,D3D11_MAP_READ,0,&m)))return 29;
        int visible=0,purple=0,neutralHot=0;for(UINT y=0;y<96;y+=2){const uint8_t*row=(const uint8_t*)m.pData+y*m.RowPitch;for(UINT x=0;x<128;x+=2){const uint8_t*p=row+x*4;if(p[3]<200)continue;visible++;int b=p[0],g=p[1],r=p[2],mx=std::max(r,std::max(g,b)),mn=std::min(r,std::min(g,b));if(b>g+30&&r>g+20&&mx-mn>35)purple++;if(mx>225&&mx-mn<18)neutralHot++;}}context->Unmap(stage.Get(),0);
        if(visible<120)return 30;if(purple<visible/2)return 31;if(neutralHot>visible/20)return 32;return 1;
    }
}

extern "C" __declspec(dllexport) int __cdecl HC_D3D11SmokeTest(){try{int basic=RunOffscreenSmokeTest();if(basic!=1)return basic;return RunProductionHuePreservationSmokeTest();}catch(...){return 99;}}
extern "C" __declspec(dllexport) void* __cdecl HC_D3D11CreateWpfSurface(int width,int height,void**surface9){if(surface9)*surface9=nullptr;if(width<1||height<1||!surface9)return nullptr;ShelfSurface*s=new(std::nothrow)ShelfSurface();if(!s)return nullptr;HRESULT hr=CreateWpfSharedTarget(*s,(UINT)width,(UINT)height);if(FAILED(hr)){delete s;return nullptr;}*surface9=s->sharedSurface9.Get();if(*surface9)static_cast<IUnknown*>(*surface9)->AddRef();return s;}
extern "C" __declspec(dllexport) int __cdecl HC_D3D11RenderWpfSurface(void*handle,float phase){if(!handle)return 0;ShelfSurface*s=static_cast<ShelfSurface*>(handle);std::lock_guard<std::mutex>guard(s->lock);return SUCCEEDED(RenderSmokeInternal(*s,phase))?1:0;}
extern "C" __declspec(dllexport) void __cdecl HC_D3D11ReleaseSurfacePointer(void*surface9){if(surface9)static_cast<IUnknown*>(surface9)->Release();}
extern "C" __declspec(dllexport) void __cdecl HC_D3D11DestroyWpfSurface(void*handle){if(!handle)return;delete static_cast<ShelfSurface*>(handle);}
