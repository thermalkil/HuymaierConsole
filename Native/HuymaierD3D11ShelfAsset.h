#pragma once

#include <Windows.h>
#include <d3d11.h>
#include <wrl/client.h>
#include <cstdint>
#include <string>
#include <vector>

namespace HuymaierGpuShelf
{
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
