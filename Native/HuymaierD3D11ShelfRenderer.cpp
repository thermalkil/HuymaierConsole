#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <d3d11.h>
#include <d3d9.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <wrl/client.h>
#include <cmath>
#include <cstdint>
#include <mutex>

using Microsoft::WRL::ComPtr;

namespace
{
    struct SmokeVertex
    {
        float x, y, z;
        float r, g, b, a;
    };

    struct ShelfSurface
    {
        UINT width = 0;
        UINT height = 0;
        ComPtr<IDirect3D9Ex> d3d9;
        ComPtr<IDirect3DDevice9Ex> device9;
        ComPtr<IDirect3DTexture9> sharedTexture9;
        ComPtr<IDirect3DSurface9> sharedSurface9;
        HANDLE sharedHandle = nullptr;
        ComPtr<ID3D11Device> device11;
        ComPtr<ID3D11DeviceContext> context11;
        ComPtr<ID3D11Texture2D> sharedTexture11;
        ComPtr<ID3D11RenderTargetView> rtv;
        ComPtr<ID3D11VertexShader> vertexShader;
        ComPtr<ID3D11PixelShader> pixelShader;
        ComPtr<ID3D11InputLayout> inputLayout;
        ComPtr<ID3D11Buffer> smokeVertexBuffer;
        D3D_FEATURE_LEVEL featureLevel = D3D_FEATURE_LEVEL_10_0;
        std::mutex lock;
    };

    const char* kSmokeShader = R"HLSL(
struct VSInput
{
    float3 position : POSITION;
    float4 color : COLOR0;
};
struct VSOutput
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};
VSOutput VSMain(VSInput input)
{
    VSOutput o;
    o.position = float4(input.position, 1.0);
    o.color = input.color;
    return o;
}
float4 PSMain(VSOutput input) : SV_TARGET
{
    // Premultiply so the surface is ready for WPF/D3DImage composition.
    return float4(input.color.rgb * input.color.a, input.color.a);
}
)HLSL";

    HRESULT CompileShader(const char* entry, const char* target, ID3DBlob** blob)
    {
        UINT flags = D3DCOMPILE_ENABLE_STRICTNESS;
#if defined(_DEBUG)
        flags |= D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
#else
        flags |= D3DCOMPILE_OPTIMIZATION_LEVEL3;
#endif
        ComPtr<ID3DBlob> errors;
        HRESULT hr = D3DCompile(
            kSmokeShader,
            strlen(kSmokeShader),
            "HuymaierD3D11ShelfRenderer",
            nullptr,
            nullptr,
            entry,
            target,
            flags,
            0,
            blob,
            errors.GetAddressOf());
        if (FAILED(hr) && errors)
            OutputDebugStringA(static_cast<const char*>(errors->GetBufferPointer()));
        return hr;
    }

    HRESULT CreateD3D11Device(bool allowWarp, ID3D11Device** device, ID3D11DeviceContext** context, D3D_FEATURE_LEVEL* level)
    {
        const D3D_FEATURE_LEVEL levels[] =
        {
            D3D_FEATURE_LEVEL_11_1,
            D3D_FEATURE_LEVEL_11_0,
            D3D_FEATURE_LEVEL_10_1,
            D3D_FEATURE_LEVEL_10_0
        };
        UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
        HRESULT hr = D3D11CreateDevice(
            nullptr,
            D3D_DRIVER_TYPE_HARDWARE,
            nullptr,
            flags,
            levels,
            ARRAYSIZE(levels),
            D3D11_SDK_VERSION,
            device,
            level,
            context);
        if (FAILED(hr) && allowWarp)
        {
            hr = D3D11CreateDevice(
                nullptr,
                D3D_DRIVER_TYPE_WARP,
                nullptr,
                flags,
                levels,
                ARRAYSIZE(levels),
                D3D11_SDK_VERSION,
                device,
                level,
                context);
        }
        return hr;
    }

    HRESULT CreateShaders(ShelfSurface& surface)
    {
        ComPtr<ID3DBlob> vsBlob;
        ComPtr<ID3DBlob> psBlob;
        HRESULT hr = CompileShader("VSMain", "vs_4_0", vsBlob.GetAddressOf());
        if (FAILED(hr)) return hr;
        hr = CompileShader("PSMain", "ps_4_0", psBlob.GetAddressOf());
        if (FAILED(hr)) return hr;
        hr = surface.device11->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, surface.vertexShader.GetAddressOf());
        if (FAILED(hr)) return hr;
        hr = surface.device11->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, surface.pixelShader.GetAddressOf());
        if (FAILED(hr)) return hr;

        const D3D11_INPUT_ELEMENT_DESC layout[] =
        {
            { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
            { "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 }
        };
        hr = surface.device11->CreateInputLayout(
            layout,
            ARRAYSIZE(layout),
            vsBlob->GetBufferPointer(),
            vsBlob->GetBufferSize(),
            surface.inputLayout.GetAddressOf());
        return hr;
    }

    HRESULT CreateSmokeGeometry(ShelfSurface& surface)
    {
        const SmokeVertex vertices[] =
        {
            { -0.72f, -0.68f, 0.0f, 0.10f, 0.75f, 1.00f, 0.96f },
            {  0.00f,  0.74f, 0.0f, 1.00f, 0.82f, 0.18f, 0.96f },
            {  0.72f, -0.68f, 0.0f, 0.92f, 0.20f, 0.36f, 0.96f }
        };
        D3D11_BUFFER_DESC desc{};
        desc.ByteWidth = sizeof(vertices);
        desc.Usage = D3D11_USAGE_IMMUTABLE;
        desc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
        D3D11_SUBRESOURCE_DATA data{};
        data.pSysMem = vertices;
        return surface.device11->CreateBuffer(&desc, &data, surface.smokeVertexBuffer.GetAddressOf());
    }

    HRESULT CreateOffscreenTarget(ShelfSurface& surface, UINT width, UINT height)
    {
        D3D11_TEXTURE2D_DESC tex{};
        tex.Width = width;
        tex.Height = height;
        tex.MipLevels = 1;
        tex.ArraySize = 1;
        tex.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        tex.SampleDesc.Count = 1;
        tex.Usage = D3D11_USAGE_DEFAULT;
        tex.BindFlags = D3D11_BIND_RENDER_TARGET;
        HRESULT hr = surface.device11->CreateTexture2D(&tex, nullptr, surface.sharedTexture11.GetAddressOf());
        if (FAILED(hr)) return hr;
        return surface.device11->CreateRenderTargetView(surface.sharedTexture11.Get(), nullptr, surface.rtv.GetAddressOf());
    }

    HRESULT CreateWpfSharedTarget(ShelfSurface& surface, UINT width, UINT height)
    {
        HRESULT hr = Direct3DCreate9Ex(D3D_SDK_VERSION, surface.d3d9.GetAddressOf());
        if (FAILED(hr)) return hr;

        D3DPRESENT_PARAMETERS pp{};
        pp.Windowed = TRUE;
        pp.SwapEffect = D3DSWAPEFFECT_DISCARD;
        pp.hDeviceWindow = GetDesktopWindow();
        pp.BackBufferWidth = 1;
        pp.BackBufferHeight = 1;
        pp.BackBufferFormat = D3DFMT_A8R8G8B8;
        pp.PresentationInterval = D3DPRESENT_INTERVAL_IMMEDIATE;
        hr = surface.d3d9->CreateDeviceEx(
            D3DADAPTER_DEFAULT,
            D3DDEVTYPE_HAL,
            GetDesktopWindow(),
            D3DCREATE_HARDWARE_VERTEXPROCESSING | D3DCREATE_MULTITHREADED | D3DCREATE_FPU_PRESERVE,
            &pp,
            nullptr,
            surface.device9.GetAddressOf());
        if (FAILED(hr)) return hr;

        surface.sharedHandle = nullptr;
        hr = surface.device9->CreateTexture(
            width,
            height,
            1,
            D3DUSAGE_RENDERTARGET,
            D3DFMT_A8R8G8B8,
            D3DPOOL_DEFAULT,
            surface.sharedTexture9.GetAddressOf(),
            &surface.sharedHandle);
        if (FAILED(hr) || surface.sharedHandle == nullptr) return FAILED(hr) ? hr : E_FAIL;
        hr = surface.sharedTexture9->GetSurfaceLevel(0, surface.sharedSurface9.GetAddressOf());
        if (FAILED(hr)) return hr;

        hr = CreateD3D11Device(false, surface.device11.GetAddressOf(), surface.context11.GetAddressOf(), &surface.featureLevel);
        if (FAILED(hr)) return hr;
        hr = surface.device11->OpenSharedResource(surface.sharedHandle, __uuidof(ID3D11Texture2D), reinterpret_cast<void**>(surface.sharedTexture11.GetAddressOf()));
        if (FAILED(hr)) return hr;
        hr = surface.device11->CreateRenderTargetView(surface.sharedTexture11.Get(), nullptr, surface.rtv.GetAddressOf());
        if (FAILED(hr)) return hr;
        hr = CreateShaders(surface);
        if (FAILED(hr)) return hr;
        hr = CreateSmokeGeometry(surface);
        if (FAILED(hr)) return hr;
        surface.width = width;
        surface.height = height;
        return S_OK;
    }

    HRESULT RenderSmokeInternal(ShelfSurface& surface, float phase)
    {
        if (!surface.context11 || !surface.rtv || !surface.vertexShader || !surface.pixelShader || !surface.inputLayout || !surface.smokeVertexBuffer)
            return E_UNEXPECTED;

        const float clear[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
        surface.context11->OMSetRenderTargets(1, surface.rtv.GetAddressOf(), nullptr);
        surface.context11->ClearRenderTargetView(surface.rtv.Get(), clear);
        D3D11_VIEWPORT vp{};
        vp.Width = static_cast<float>(surface.width);
        vp.Height = static_cast<float>(surface.height);
        vp.MaxDepth = 1.0f;
        surface.context11->RSSetViewports(1, &vp);
        UINT stride = sizeof(SmokeVertex);
        UINT offset = 0;
        ID3D11Buffer* vb = surface.smokeVertexBuffer.Get();
        surface.context11->IASetVertexBuffers(0, 1, &vb, &stride, &offset);
        surface.context11->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        surface.context11->IASetInputLayout(surface.inputLayout.Get());
        surface.context11->VSSetShader(surface.vertexShader.Get(), nullptr, 0);
        surface.context11->PSSetShader(surface.pixelShader.Get(), nullptr, 0);

        // A tiny viewport translation exercises changing GPU state without
        // rebuilding geometry. Production shelf animation will update model
        // matrices through this same per-frame path.
        const float shift = std::sin(phase) * 0.02f;
        vp.TopLeftX = shift > 0.0f ? shift * surface.width : 0.0f;
        vp.Width = static_cast<float>(surface.width) - std::fabs(shift * surface.width);
        surface.context11->RSSetViewports(1, &vp);
        surface.context11->Draw(3, 0);
        surface.context11->Flush();
        return S_OK;
    }

    int RunOffscreenSmokeTest()
    {
        ShelfSurface surface;
        HRESULT hr = CreateD3D11Device(true, surface.device11.GetAddressOf(), surface.context11.GetAddressOf(), &surface.featureLevel);
        if (FAILED(hr)) return 10;
        surface.width = 128;
        surface.height = 96;
        hr = CreateOffscreenTarget(surface, surface.width, surface.height);
        if (FAILED(hr)) return 11;
        hr = CreateShaders(surface);
        if (FAILED(hr)) return 12;
        hr = CreateSmokeGeometry(surface);
        if (FAILED(hr)) return 13;
        hr = RenderSmokeInternal(surface, 0.35f);
        if (FAILED(hr)) return 14;

        D3D11_TEXTURE2D_DESC desc{};
        surface.sharedTexture11->GetDesc(&desc);
        desc.Usage = D3D11_USAGE_STAGING;
        desc.BindFlags = 0;
        desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
        desc.MiscFlags = 0;
        ComPtr<ID3D11Texture2D> staging;
        hr = surface.device11->CreateTexture2D(&desc, nullptr, staging.GetAddressOf());
        if (FAILED(hr)) return 15;
        surface.context11->CopyResource(staging.Get(), surface.sharedTexture11.Get());
        D3D11_MAPPED_SUBRESOURCE mapped{};
        hr = surface.context11->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped);
        if (FAILED(hr)) return 16;
        int colored = 0;
        for (UINT y = 0; y < desc.Height; y += 4)
        {
            const uint8_t* row = static_cast<const uint8_t*>(mapped.pData) + y * mapped.RowPitch;
            for (UINT x = 0; x < desc.Width; x += 4)
            {
                const uint8_t* px = row + x * 4;
                if (px[3] > 32 && (px[0] > 24 || px[1] > 24 || px[2] > 24)) colored++;
            }
        }
        surface.context11->Unmap(staging.Get(), 0);
        return colored >= 40 ? 1 : 17;
    }
}

extern "C" __declspec(dllexport) int __cdecl HC_D3D11SmokeTest()
{
    try { return RunOffscreenSmokeTest(); }
    catch (...) { return 99; }
}

extern "C" __declspec(dllexport) void* __cdecl HC_D3D11CreateWpfSurface(int width, int height, void** surface9)
{
    if (surface9) *surface9 = nullptr;
    if (width < 1 || height < 1 || !surface9) return nullptr;
    ShelfSurface* surface = new (std::nothrow) ShelfSurface();
    if (!surface) return nullptr;
    HRESULT hr = CreateWpfSharedTarget(*surface, static_cast<UINT>(width), static_cast<UINT>(height));
    if (FAILED(hr))
    {
        delete surface;
        return nullptr;
    }
    *surface9 = surface->sharedSurface9.Get();
    if (*surface9) static_cast<IUnknown*>(*surface9)->AddRef();
    return surface;
}

extern "C" __declspec(dllexport) int __cdecl HC_D3D11RenderWpfSurface(void* handle, float phase)
{
    if (!handle) return 0;
    ShelfSurface* surface = static_cast<ShelfSurface*>(handle);
    std::lock_guard<std::mutex> guard(surface->lock);
    return SUCCEEDED(RenderSmokeInternal(*surface, phase)) ? 1 : 0;
}

extern "C" __declspec(dllexport) void __cdecl HC_D3D11ReleaseSurfacePointer(void* surface9)
{
    if (surface9) static_cast<IUnknown*>(surface9)->Release();
}

extern "C" __declspec(dllexport) void __cdecl HC_D3D11DestroyWpfSurface(void* handle)
{
    if (!handle) return;
    ShelfSurface* surface = static_cast<ShelfSurface*>(handle);
    delete surface;
}
