#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <wrl/client.h>
#include <cstdint>
#include <cstring>

using Microsoft::WRL::ComPtr;

namespace
{
    const char* kUvShader = R"HLSL(
Texture2D ProbeTexture : register(t0);
SamplerState RepeatSampler : register(s0);
SamplerState ClampSampler : register(s1);
SamplerState MirrorSampler : register(s2);

float4 VSMain(uint vertexId : SV_VertexID) : SV_POSITION
{
    float2 p;
    if (vertexId == 0) p = float2(-1.0, -1.0);
    else if (vertexId == 1) p = float2(-1.0, 3.0);
    else p = float2(3.0, -1.0);
    return float4(p, 0.0, 1.0);
}

float4 PSMain(float4 position : SV_POSITION) : SV_TARGET
{
    uint column = (uint)position.x;
    if (column == 0)
    {
        // GL_REPEAT: 1.25 wraps to 0.25 -> top-left red texel.
        return ProbeTexture.SampleLevel(RepeatSampler, float2(1.25, 0.25), 0.0);
    }
    if (column == 1)
    {
        // GL_CLAMP_TO_EDGE: 1.25 clamps to right edge -> top-right green texel.
        return ProbeTexture.SampleLevel(ClampSampler, float2(1.25, 0.25), 0.0);
    }
    if (column == 2)
    {
        // GL_MIRRORED_REPEAT: 1.75 mirrors to 0.25 -> top-left red texel.
        return ProbeTexture.SampleLevel(MirrorSampler, float2(1.75, 0.25), 0.0);
    }

    // HC3D v3 stores authored/transformed glTF UVs directly. No hidden V flip
    // exists in either cache or production shader. (0.25,0.75) therefore samples
    // the bottom-left blue texel exactly as authored.
    float2 gltfUv = float2(0.25, 0.75);
    return ProbeTexture.SampleLevel(RepeatSampler, gltfUv, 0.0);
}
)HLSL";

    HRESULT Compile(const char* entry, const char* target, ID3DBlob** blob)
    {
        ComPtr<ID3DBlob> errors;
        return D3DCompile(kUvShader, std::strlen(kUvShader), "HuymaierD3D11UvAddressSmoke",
            nullptr, nullptr, entry, target, D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_OPTIMIZATION_LEVEL3,
            0, blob, errors.GetAddressOf());
    }

    HRESULT MakeSampler(ID3D11Device* device, D3D11_TEXTURE_ADDRESS_MODE addressU, ID3D11SamplerState** state)
    {
        D3D11_SAMPLER_DESC d{};
        d.Filter = D3D11_FILTER_MIN_MAG_MIP_POINT;
        d.AddressU = addressU;
        d.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
        d.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
        d.MinLOD = 0.0f;
        d.MaxLOD = 0.0f;
        return device->CreateSamplerState(&d, state);
    }

    bool PixelEquals(const uint8_t* p, uint8_t r, uint8_t g, uint8_t b)
    {
        return p[0] == r && p[1] == g && p[2] == b && p[3] == 255;
    }

    int RunUvAddressSmoke()
    {
        const D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0 };
        D3D_FEATURE_LEVEL selected{};
        ComPtr<ID3D11Device> device;
        ComPtr<ID3D11DeviceContext> context;
        HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            levels, ARRAYSIZE(levels), D3D11_SDK_VERSION, device.GetAddressOf(), &selected, context.GetAddressOf());
        if (FAILED(hr)) return 10;

        ComPtr<ID3DBlob> vsBlob, psBlob;
        if (FAILED(Compile("VSMain", "vs_4_0", vsBlob.GetAddressOf()))) return 11;
        if (FAILED(Compile("PSMain", "ps_4_0", psBlob.GetAddressOf()))) return 12;
        ComPtr<ID3D11VertexShader> vs;
        ComPtr<ID3D11PixelShader> ps;
        if (FAILED(device->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, vs.GetAddressOf()))) return 13;
        if (FAILED(device->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, ps.GetAddressOf()))) return 14;

        // RGBA texels: top-left red, top-right green, bottom-left blue, bottom-right yellow.
        const uint8_t texels[] = {
            255,0,0,255,   0,255,0,255,
            0,0,255,255,   255,255,0,255
        };
        D3D11_TEXTURE2D_DESC textureDesc{};
        textureDesc.Width = 2;
        textureDesc.Height = 2;
        textureDesc.MipLevels = 1;
        textureDesc.ArraySize = 1;
        textureDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
        textureDesc.SampleDesc.Count = 1;
        textureDesc.Usage = D3D11_USAGE_IMMUTABLE;
        textureDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
        D3D11_SUBRESOURCE_DATA textureData{};
        textureData.pSysMem = texels;
        textureData.SysMemPitch = 8;
        ComPtr<ID3D11Texture2D> texture;
        ComPtr<ID3D11ShaderResourceView> srv;
        if (FAILED(device->CreateTexture2D(&textureDesc, &textureData, texture.GetAddressOf()))) return 15;
        if (FAILED(device->CreateShaderResourceView(texture.Get(), nullptr, srv.GetAddressOf()))) return 16;

        D3D11_TEXTURE2D_DESC targetDesc{};
        targetDesc.Width = 4;
        targetDesc.Height = 1;
        targetDesc.MipLevels = 1;
        targetDesc.ArraySize = 1;
        targetDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
        targetDesc.SampleDesc.Count = 1;
        targetDesc.Usage = D3D11_USAGE_DEFAULT;
        targetDesc.BindFlags = D3D11_BIND_RENDER_TARGET;
        ComPtr<ID3D11Texture2D> target;
        ComPtr<ID3D11RenderTargetView> rtv;
        if (FAILED(device->CreateTexture2D(&targetDesc, nullptr, target.GetAddressOf()))) return 17;
        if (FAILED(device->CreateRenderTargetView(target.Get(), nullptr, rtv.GetAddressOf()))) return 18;

        ComPtr<ID3D11SamplerState> repeatSampler, clampSampler, mirrorSampler;
        if (FAILED(MakeSampler(device.Get(), D3D11_TEXTURE_ADDRESS_WRAP, repeatSampler.GetAddressOf()))) return 19;
        if (FAILED(MakeSampler(device.Get(), D3D11_TEXTURE_ADDRESS_CLAMP, clampSampler.GetAddressOf()))) return 20;
        if (FAILED(MakeSampler(device.Get(), D3D11_TEXTURE_ADDRESS_MIRROR, mirrorSampler.GetAddressOf()))) return 21;

        ID3D11RenderTargetView* targetView = rtv.Get();
        context->OMSetRenderTargets(1, &targetView, nullptr);
        const float clear[4] = {0,0,0,0};
        context->ClearRenderTargetView(rtv.Get(), clear);
        D3D11_VIEWPORT viewport{};
        viewport.Width = 4.0f;
        viewport.Height = 1.0f;
        viewport.MinDepth = 0.0f;
        viewport.MaxDepth = 1.0f;
        context->RSSetViewports(1, &viewport);
        context->IASetInputLayout(nullptr);
        context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        context->VSSetShader(vs.Get(), nullptr, 0);
        context->PSSetShader(ps.Get(), nullptr, 0);
        ID3D11ShaderResourceView* views[1] = {srv.Get()};
        context->PSSetShaderResources(0, 1, views);
        ID3D11SamplerState* samplers[3] = {repeatSampler.Get(), clampSampler.Get(), mirrorSampler.Get()};
        context->PSSetSamplers(0, 3, samplers);
        context->Draw(3, 0);
        context->Flush();

        D3D11_TEXTURE2D_DESC stagingDesc = targetDesc;
        stagingDesc.Usage = D3D11_USAGE_STAGING;
        stagingDesc.BindFlags = 0;
        stagingDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
        ComPtr<ID3D11Texture2D> staging;
        if (FAILED(device->CreateTexture2D(&stagingDesc, nullptr, staging.GetAddressOf()))) return 22;
        context->CopyResource(staging.Get(), target.Get());
        D3D11_MAPPED_SUBRESOURCE mapped{};
        if (FAILED(context->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped))) return 23;
        const uint8_t* row = static_cast<const uint8_t*>(mapped.pData);
        const bool repeatOk = PixelEquals(row + 0, 255, 0, 0);
        const bool clampOk = PixelEquals(row + 4, 0, 255, 0);
        const bool mirrorOk = PixelEquals(row + 8, 255, 0, 0);
        const bool transformOk = PixelEquals(row + 12, 0, 0, 255);
        context->Unmap(staging.Get(), 0);

        if (!repeatOk) return 31;
        if (!clampOk) return 32;
        if (!mirrorOk) return 33;
        if (!transformOk) return 34;
        return 1;
    }
}

extern "C" __declspec(dllexport) int __cdecl HC_D3D11UvAddressSmokeTest()
{
    try { return RunUvAddressSmoke(); }
    catch (...) { return 99; }
}
