#include "HuymaierD3D11ShelfAsset.h"

#include <algorithm>
#include <fstream>
#include <limits>
#include <memory>

using Microsoft::WRL::ComPtr;

namespace HuymaierGpuShelf
{
    namespace
    {
        template <typename T>
        bool Read(std::ifstream& stream, T& value)
        {
            stream.read(reinterpret_cast<char*>(&value), sizeof(T));
            return stream.good();
        }

        bool ReadBytes(std::ifstream& stream, void* data, size_t size)
        {
            if (size == 0) return true;
            stream.read(reinterpret_cast<char*>(data), static_cast<std::streamsize>(size));
            return stream.good();
        }

        bool SafeCount(int32_t value, int32_t maximum)
        {
            return value >= 0 && value <= maximum;
        }

        HRESULT CreateTexture(
            ID3D11Device* device,
            ID3D11DeviceContext* context,
            int32_t width,
            int32_t height,
            const std::vector<uint8_t>& pixels,
            Texture& output)
        {
            if (width <= 0 || height <= 0 || pixels.empty()) return S_FALSE;
            const uint64_t expected = static_cast<uint64_t>(width) * static_cast<uint64_t>(height) * 4ull;
            if (expected != pixels.size()) return E_INVALIDARG;

            D3D11_TEXTURE2D_DESC desc{};
            desc.Width = static_cast<UINT>(width);
            desc.Height = static_cast<UINT>(height);
            desc.MipLevels = 0;
            desc.ArraySize = 1;
            desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
            desc.SampleDesc.Count = 1;
            desc.Usage = D3D11_USAGE_DEFAULT;
            desc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_RENDER_TARGET;
            desc.MiscFlags = D3D11_RESOURCE_MISC_GENERATE_MIPS;

            HRESULT hr = device->CreateTexture2D(&desc, nullptr, output.resource.GetAddressOf());
            if (FAILED(hr)) return hr;
            context->UpdateSubresource(output.resource.Get(), 0, nullptr, pixels.data(), static_cast<UINT>(width * 4), 0);

            D3D11_SHADER_RESOURCE_VIEW_DESC srv{};
            srv.Format = desc.Format;
            srv.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
            srv.Texture2D.MostDetailedMip = 0;
            srv.Texture2D.MipLevels = static_cast<UINT>(-1);
            hr = device->CreateShaderResourceView(output.resource.Get(), &srv, output.view.GetAddressOf());
            if (FAILED(hr)) return hr;
            context->GenerateMips(output.view.Get());
            output.width = static_cast<uint32_t>(width);
            output.height = static_cast<uint32_t>(height);
            return S_OK;
        }
    }

    HRESULT LoadAsset(
        ID3D11Device* device,
        ID3D11DeviceContext* context,
        const wchar_t* cachePath,
        Asset** assetOut)
    {
        if (assetOut) *assetOut = nullptr;
        if (!device || !context || !cachePath || !*cachePath || !assetOut) return E_INVALIDARG;

        std::ifstream stream(cachePath, std::ios::binary);
        if (!stream) return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);

        char magic[4]{};
        if (!ReadBytes(stream, magic, sizeof(magic)) ||
            magic[0] != 'H' || magic[1] != 'C' || magic[2] != '3' || magic[3] != 'D')
            return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);

        int32_t version = 0;
        int64_t sourceLength = 0;
        int64_t sourceTicks = 0;
        int32_t quality = 0;
        int32_t vertexCount = 0;
        int32_t indexCount = 0;
        int32_t drawCount = 0;
        int32_t imageCount = 0;
        if (!Read(stream, version) || !Read(stream, sourceLength) || !Read(stream, sourceTicks) ||
            !Read(stream, quality) || !Read(stream, vertexCount) || !Read(stream, indexCount) ||
            !Read(stream, drawCount) || !Read(stream, imageCount)) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
        if (version != 2 || quality < 128 || quality > 2048 ||
            !SafeCount(vertexCount, 10000000) || !SafeCount(indexCount, 30000000) ||
            !SafeCount(drawCount, 100000) || !SafeCount(imageCount, 4096) ||
            vertexCount == 0 || indexCount == 0 || drawCount == 0)
            return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);

        std::unique_ptr<Asset> asset(new (std::nothrow) Asset());
        if (!asset) return E_OUTOFMEMORY;
        asset->cachePath = cachePath;
        asset->quality = static_cast<uint32_t>(quality);
        asset->vertexCount = static_cast<uint32_t>(vertexCount);
        asset->indexCount = static_cast<uint32_t>(indexCount);
        for (int i = 0; i < 3; ++i) if (!Read(stream, asset->minBounds[i])) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
        for (int i = 0; i < 3; ++i) if (!Read(stream, asset->maxBounds[i])) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);

        std::vector<Vertex> vertices(static_cast<size_t>(vertexCount));
        if (!ReadBytes(stream, vertices.data(), vertices.size() * sizeof(Vertex))) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
        std::vector<uint32_t> indices(static_cast<size_t>(indexCount));
        if (!ReadBytes(stream, indices.data(), indices.size() * sizeof(uint32_t))) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);

        asset->draws.resize(static_cast<size_t>(drawCount));
        for (int32_t i = 0; i < drawCount; ++i)
        {
            DrawBatch& d = asset->draws[static_cast<size_t>(i)];
            int32_t firstIndex = 0;
            int32_t count = 0;
            if (!Read(stream, firstIndex) || !Read(stream, count) || !Read(stream, d.baseImage) || !Read(stream, d.emissiveImage)) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
            if (firstIndex < 0 || count < 0 || static_cast<uint64_t>(firstIndex) + static_cast<uint64_t>(count) > static_cast<uint64_t>(indexCount)) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
            d.firstIndex = static_cast<uint32_t>(firstIndex);
            d.indexCount = static_cast<uint32_t>(count);
            for (int c = 0; c < 4; ++c) if (!Read(stream, d.baseColor[c])) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
            for (int c = 0; c < 3; ++c) if (!Read(stream, d.emissiveColor[c])) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
            if (!Read(stream, d.emissiveStrength) || !Read(stream, d.metallic) || !Read(stream, d.roughness) || !Read(stream, d.specular) || !Read(stream, d.clearcoat) ||
                !Read(stream, d.baseWrapS) || !Read(stream, d.baseWrapT) || !Read(stream, d.emissiveWrapS) || !Read(stream, d.emissiveWrapT) ||
                !Read(stream, d.alphaMode) || !Read(stream, d.alphaCutoff) || !Read(stream, d.flags)) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
        }

        asset->textures.resize(static_cast<size_t>(imageCount));
        for (int32_t i = 0; i < imageCount; ++i)
        {
            int32_t width = 0, height = 0, byteCount = 0;
            if (!Read(stream, width) || !Read(stream, height) || !Read(stream, byteCount)) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
            if (width == 0 && height == 0 && byteCount == 0) continue;
            if (width <= 0 || height <= 0 || width > 4096 || height > 4096) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
            const uint64_t expected = static_cast<uint64_t>(width) * static_cast<uint64_t>(height) * 4ull;
            if (byteCount <= 0 || static_cast<uint64_t>(byteCount) != expected || expected > 256ull * 1024ull * 1024ull) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
            std::vector<uint8_t> pixels(static_cast<size_t>(byteCount));
            if (!ReadBytes(stream, pixels.data(), pixels.size())) return HRESULT_FROM_WIN32(ERROR_BAD_FORMAT);
            HRESULT hr = CreateTexture(device, context, width, height, pixels, asset->textures[static_cast<size_t>(i)]);
            if (FAILED(hr)) return hr;
        }

        D3D11_BUFFER_DESC vb{};
        vb.ByteWidth = static_cast<UINT>(vertices.size() * sizeof(Vertex));
        vb.Usage = D3D11_USAGE_IMMUTABLE;
        vb.BindFlags = D3D11_BIND_VERTEX_BUFFER;
        D3D11_SUBRESOURCE_DATA vbData{};
        vbData.pSysMem = vertices.data();
        HRESULT hr = device->CreateBuffer(&vb, &vbData, asset->vertexBuffer.GetAddressOf());
        if (FAILED(hr)) return hr;

        D3D11_BUFFER_DESC ib{};
        ib.ByteWidth = static_cast<UINT>(indices.size() * sizeof(uint32_t));
        ib.Usage = D3D11_USAGE_IMMUTABLE;
        ib.BindFlags = D3D11_BIND_INDEX_BUFFER;
        D3D11_SUBRESOURCE_DATA ibData{};
        ibData.pSysMem = indices.data();
        hr = device->CreateBuffer(&ib, &ibData, asset->indexBuffer.GetAddressOf());
        if (FAILED(hr)) return hr;

        *assetOut = asset.release();
        return S_OK;
    }

    void DestroyAsset(Asset* asset)
    {
        delete asset;
    }
}
