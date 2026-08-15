#include <Windows.h>
#include <GameInput.h>
#include <atomic>
#include <mutex>
#include <cstdint>

// Microsoft.GameInput 3.x exposes the current API through a versioned
// namespace. Keep this bridge explicit so future SDK upgrades fail at compile
// time instead of silently binding to the wrong interface layout.
#ifndef GAMEINPUT_API_VERSION
#define GAMEINPUT_API_VERSION 0
#endif

#if GAMEINPUT_API_VERSION == 1
using namespace GameInput::v1;
#elif GAMEINPUT_API_VERSION == 2
using namespace GameInput::v2;
#elif GAMEINPUT_API_VERSION == 3
using namespace GameInput::v3;
#elif GAMEINPUT_API_VERSION != 0
#error Unsupported GAMEINPUT_API_VERSION. Update HuymaierGameInputBridge.cpp for the new GameInput API.
#endif

namespace
{
    std::mutex g_lock;
    IGameInput* g_gameInput = nullptr;
    GameInputCallbackToken g_systemButtonToken{};
    bool g_callbackRegistered = false;
    std::atomic<long> g_guidePresses(0);
    std::atomic<long> g_sharePresses(0);

    // Sony controllers already have a proven WM_INPUT path in HuymaierNativeInput.
    // The shell publishes its continuous axes/buttons here so Web and the isolated
    // streaming cursor helper use the exact same controller backend as navigation.
    static const wchar_t* kPointerMapName = L"Local\\HuymaierConsole.PointerStateV1";
    static const int32_t kPointerMagic = 0x31504348; // HCP1
    HANDLE g_pointerMapping = nullptr;
    const unsigned char* g_pointerBytes = nullptr;

#pragma pack(push, 1)
    struct SharedPointerState
    {
        int32_t magic;
        int32_t version;
        int32_t sequence;
        int32_t productId;
        uint64_t tickCount64;
        float leftX;
        float leftY;
        float rightX;
        float rightY;
        uint32_t buttons;
    };
#pragma pack(pop)

    void CloseSharedPointerState()
    {
        if (g_pointerBytes != nullptr)
        {
            UnmapViewOfFile(g_pointerBytes);
            g_pointerBytes = nullptr;
        }
        if (g_pointerMapping != nullptr)
        {
            CloseHandle(g_pointerMapping);
            g_pointerMapping = nullptr;
        }
    }

    bool EnsureSharedPointerState()
    {
        if (g_pointerBytes != nullptr) return true;
        HANDLE mapping = OpenFileMappingW(FILE_MAP_READ, FALSE, kPointerMapName);
        if (mapping == nullptr) return false;
        const unsigned char* bytes = static_cast<const unsigned char*>(MapViewOfFile(mapping, FILE_MAP_READ, 0, 0, sizeof(SharedPointerState)));
        if (bytes == nullptr)
        {
            CloseHandle(mapping);
            return false;
        }
        g_pointerMapping = mapping;
        g_pointerBytes = bytes;
        return true;
    }

    bool TryReadSharedPointerState(
        float* leftX,
        float* leftY,
        float* rightX,
        float* rightY,
        float* leftTrigger,
        float* rightTrigger,
        uint32_t* buttons)
    {
        if (!EnsureSharedPointerState()) return false;
        const volatile SharedPointerState* shared = reinterpret_cast<const volatile SharedPointerState*>(g_pointerBytes);
        const int32_t seqBefore = shared->sequence;
        MemoryBarrier();
        if ((seqBefore & 1) != 0 || shared->magic != kPointerMagic || shared->version != 1) return false;

        const uint64_t stamp = shared->tickCount64;
        const float lx = shared->leftX;
        const float ly = shared->leftY;
        const float rx = shared->rightX;
        const float ry = shared->rightY;
        const uint32_t pointerButtons = shared->buttons;
        MemoryBarrier();
        const int32_t seqAfter = shared->sequence;
        if (seqBefore != seqAfter || (seqAfter & 1) != 0) return false;

        const uint64_t now = GetTickCount64();
        if (stamp == 0 || now < stamp || now - stamp > 750) return false;
        if (leftX) *leftX = lx;
        if (leftY) *leftY = ly;
        if (rightX) *rightX = rx;
        if (rightY) *rightY = ry;
        if (leftTrigger) *leftTrigger = 0.0f;
        if (rightTrigger) *rightTrigger = 0.0f;
        if (buttons) *buttons = pointerButtons;
        return true;
    }

    void CALLBACK OnSystemButton(
        GameInputCallbackToken,
        void*,
        IGameInputDevice*,
        uint64_t,
        GameInputSystemButtons currentButtons,
        GameInputSystemButtons previousButtons)
    {
        const bool guideNow = (currentButtons & GameInputSystemButtonGuide) != 0;
        const bool guideBefore = (previousButtons & GameInputSystemButtonGuide) != 0;
        if (guideNow && !guideBefore)
            g_guidePresses.fetch_add(1, std::memory_order_release);

        const bool shareNow = (currentButtons & GameInputSystemButtonShare) != 0;
        const bool shareBefore = (previousButtons & GameInputSystemButtonShare) != 0;
        if (shareNow && !shareBefore)
            g_sharePresses.fetch_add(1, std::memory_order_release);
    }

    int ConsumeEdge(std::atomic<long>& counter)
    {
        long value = counter.load(std::memory_order_acquire);
        while (value > 0)
        {
            if (counter.compare_exchange_weak(value, value - 1, std::memory_order_acq_rel))
                return 1;
        }
        return 0;
    }

    uint32_t NormalizePointerButtons(GameInputGamepadButtons buttons)
    {
        uint32_t mask = 0;
        if ((buttons & GameInputGamepadA) != 0) mask |= 0x0001;              // confirm / left click
        if ((buttons & GameInputGamepadB) != 0) mask |= 0x0002;              // back / escape
        if ((buttons & GameInputGamepadX) != 0) mask |= 0x0004;              // keyboard
        if ((buttons & GameInputGamepadY) != 0) mask |= 0x0008;
        if ((buttons & GameInputGamepadLeftShoulder) != 0) mask |= 0x0010;
        if ((buttons & GameInputGamepadRightShoulder) != 0) mask |= 0x0020;
        if ((buttons & GameInputGamepadMenu) != 0) mask |= 0x0040;
        if ((buttons & GameInputGamepadView) != 0) mask |= 0x0080;
        return mask;
    }
}

extern "C" __declspec(dllexport) int __cdecl HC_GameInputInitialize()
{
    std::lock_guard<std::mutex> guard(g_lock);
    if (g_gameInput != nullptr && g_callbackRegistered)
        return 1;

    IGameInput* input = nullptr;
    HRESULT result = GameInputCreate(&input);
    if (FAILED(result) || input == nullptr)
    {
        // The Sony HID shared-state path can still service pointer reads even if
        // GameInput itself is unavailable for the controller.
        return EnsureSharedPointerState() ? 1 : 0;
    }

    input->SetFocusPolicy(static_cast<GameInputFocusPolicy>(
        GameInputEnableBackgroundInput |
        GameInputEnableBackgroundGuideButton |
        GameInputEnableBackgroundShareButton));

    GameInputCallbackToken token{};
    result = input->RegisterSystemButtonCallback(
        nullptr,
        static_cast<GameInputSystemButtons>(GameInputSystemButtonGuide | GameInputSystemButtonShare),
        nullptr,
        OnSystemButton,
        &token);

    if (FAILED(result))
    {
        input->Release();
        return EnsureSharedPointerState() ? 1 : 0;
    }

    g_gameInput = input;
    g_systemButtonToken = token;
    g_callbackRegistered = true;
    g_guidePresses.store(0, std::memory_order_release);
    g_sharePresses.store(0, std::memory_order_release);
    return 1;
}

extern "C" __declspec(dllexport) int __cdecl HC_ConsumeGuidePress()
{
    return ConsumeEdge(g_guidePresses);
}

extern "C" __declspec(dllexport) int __cdecl HC_ConsumeSharePress()
{
    return ConsumeEdge(g_sharePresses);
}

// Continuous normalized state used only for controller-pointer surfaces. The
// shell keeps its existing edge/navigation stack; this API does not alter
// controller assignment or emulator behavior.
extern "C" __declspec(dllexport) int __cdecl HC_ReadGamepadPointerState(
    float* leftX,
    float* leftY,
    float* rightX,
    float* rightY,
    float* leftTrigger,
    float* rightTrigger,
    uint32_t* buttons)
{
    if (leftX) *leftX = 0.0f;
    if (leftY) *leftY = 0.0f;
    if (rightX) *rightX = 0.0f;
    if (rightY) *rightY = 0.0f;
    if (leftTrigger) *leftTrigger = 0.0f;
    if (rightTrigger) *rightTrigger = 0.0f;
    if (buttons) *buttons = 0;

    // Prefer the shell's proven Sony Raw HID state whenever it is fresh. This is
    // what makes DualSense/DualShock pointer motion identical in Web and native
    // streaming apps, including while Huymaier is backgrounded.
    if (TryReadSharedPointerState(leftX, leftY, rightX, rightY, leftTrigger, rightTrigger, buttons))
        return 1;

    std::lock_guard<std::mutex> guard(g_lock);
    if (g_gameInput == nullptr)
        return 0;

    IGameInputReading* reading = nullptr;
    HRESULT result = g_gameInput->GetCurrentReading(GameInputKindGamepad, nullptr, &reading);
    if (FAILED(result) || reading == nullptr)
        return 0;

    GameInputGamepadState state{};
    bool valid = reading->GetGamepadState(&state);
    reading->Release();
    if (!valid)
        return 0;

    if (leftX) *leftX = state.leftThumbstickX;
    if (leftY) *leftY = state.leftThumbstickY;
    if (rightX) *rightX = state.rightThumbstickX;
    if (rightY) *rightY = state.rightThumbstickY;
    if (leftTrigger) *leftTrigger = state.leftTrigger;
    if (rightTrigger) *rightTrigger = state.rightTrigger;
    if (buttons) *buttons = NormalizePointerButtons(state.buttons);
    return 1;
}

extern "C" __declspec(dllexport) void __cdecl HC_GameInputShutdown()
{
    std::lock_guard<std::mutex> guard(g_lock);
    if (g_gameInput != nullptr)
    {
        if (g_callbackRegistered)
        {
            try { g_gameInput->UnregisterCallback(g_systemButtonToken); }
            catch (...) { }
        }
        g_gameInput->Release();
    }
    g_gameInput = nullptr;
    g_callbackRegistered = false;
    CloseSharedPointerState();
    g_guidePresses.store(0, std::memory_order_release);
    g_sharePresses.store(0, std::memory_order_release);
}
