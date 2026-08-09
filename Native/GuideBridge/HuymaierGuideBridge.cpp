// Huymaier Console v0.26.0 - native GameInput system-button bridge.
// Guide is intentionally distinct from Share/Create/View/Back.

#include <windows.h>
#include <GameInput.h>
#include <atomic>

static IGameInput* g_gameInput = nullptr;
static GameInputCallbackToken g_callbackToken = 0;
static std::atomic<unsigned long> g_guidePresses(0);
static std::atomic<bool> g_started(false);

static void CALLBACK OnSystemButton(
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
}

extern "C" __declspec(dllexport) int __stdcall HCGuideInitialize()
{
    if (g_started.load(std::memory_order_acquire))
        return 1;

    IGameInput* input = nullptr;
    HRESULT hr = GameInputCreate(&input);
    if (FAILED(hr) || input == nullptr)
        return 0;

    GameInputCallbackToken token = 0;
    hr = input->RegisterSystemButtonCallback(
        nullptr,
        GameInputSystemButtonGuide,
        nullptr,
        OnSystemButton,
        &token);

    if (FAILED(hr))
    {
        input->Release();
        return 0;
    }

    g_gameInput = input;
    g_callbackToken = token;
    g_guidePresses.store(0, std::memory_order_release);
    g_started.store(true, std::memory_order_release);
    return 1;
}

extern "C" __declspec(dllexport) unsigned long __stdcall HCGuideConsumePresses()
{
    return g_guidePresses.exchange(0, std::memory_order_acq_rel);
}

extern "C" __declspec(dllexport) int __stdcall HCGuideIsAvailable()
{
    return g_started.load(std::memory_order_acquire) ? 1 : 0;
}

extern "C" __declspec(dllexport) void __stdcall HCGuideShutdown()
{
    if (!g_started.exchange(false, std::memory_order_acq_rel))
        return;

    if (g_gameInput != nullptr)
    {
        if (g_callbackToken != 0)
        {
            g_gameInput->UnregisterCallback(g_callbackToken, 5000000);
            g_callbackToken = 0;
        }
        g_gameInput->Release();
        g_gameInput = nullptr;
    }
    g_guidePresses.store(0, std::memory_order_release);
}
