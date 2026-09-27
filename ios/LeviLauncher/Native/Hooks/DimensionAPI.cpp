#include "DimensionAPI.h"
#include "ContentRegistry.h"
#include "InlineHook.h"

#include <dlfcn.h>
#include <cstdio>
#include <mutex>
#include <vector>

namespace DimensionAPI {

    // ── State ──────────────────────────────────────────────

    static std::mutex s_mutex;
    static bool s_initialized = false;
    static bool s_hooksInstalled = false;

    static std::vector<DimensionProvider> s_providers;
    static std::vector<DimensionPreCreate> s_preCreateHooks;
    static std::vector<DimensionDefinition> s_customDimensions;

    // ── Hook: Dimension registration inline hook ──────────
    // Target: internal Minecraft dimension registration function
    // The actual mangled symbol name depends on the Minecraft version.
    // Common pattern: Level::registerDimension or DimensionManager::registerDimension

    // Try multiple possible symbol patterns
    static const char *kPossibleDimSymbols[] = {
        "_ZN5Level17registerDimensionENSt3__110unique_ptrI9DimensionNS0_14default_deleteIS2_EEEEj",
        "_ZN16DimensionManager17registerDimensionENSt3__110unique_ptrI9DimensionNS0_14default_deleteIS2_EEEEj",
        "__ZN5Level17registerDimensionEN3std15unique_ptrI9DimensionNS0_14default_deleteIS1_EEEEj",
        "__ZN17DimensionManager18registerDimensionESt10unique_ptrI9DimensionSt14default_deleteIS0_EEj",
        nullptr
    };

    using RegisterDimFunc = void (*)(void *self, void *dimension, uint32_t dimId);

    static RegisterDimFunc g_originalRegisterDim = nullptr;

    static void hook_registerDimension(void *self, void *dimension, uint32_t dimId) {
        if (g_originalRegisterDim) g_originalRegisterDim(self, dimension, dimId);
    }

    // ── Public API ────────────────────────────────────────

    bool initialize() {
        std::lock_guard<std::mutex> lock(s_mutex);
        if (s_hooksInstalled) return true;

        if (!s_hooksInstalled) {
            for (int i = 0; kPossibleDimSymbols[i] != nullptr; i++) {
                void *sym = dlsym(RTLD_DEFAULT, kPossibleDimSymbols[i]);
                if (sym) {
                    void *orig = nullptr;
                    if (InlineHook::install(sym, (void *)hook_registerDimension, &orig)) {
                        g_originalRegisterDim = (RegisterDimFunc)orig;
                        s_hooksInstalled = true;
                        break;
                    } else {
                        std::fprintf(stderr, "[LeviLauncher] Dimension hook failed for %s: %s\n",
                                     kPossibleDimSymbols[i], InlineHook::lastError());
                    }
                }
            }
        }

        ContentRegistry::initialize();
        s_initialized = s_hooksInstalled;
        return s_initialized;
    }

    bool isHooked() {
        std::lock_guard<std::mutex> lock(s_mutex);
        return s_hooksInstalled;
    }

    void onRegisterDimensions(DimensionProvider provider) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_providers.push_back(std::move(provider));
        s_providers.back()(s_customDimensions);
        for (auto &dim : s_customDimensions) {
            ContentRegistry::registerContent(
                dim.id, dim.displayName,
                ContentRegistry::RegistryType::Dimension);
        }
    }

    void onPreCreateDimension(DimensionPreCreate hook) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_preCreateHooks.push_back(std::move(hook));
    }

} // namespace DimensionAPI
