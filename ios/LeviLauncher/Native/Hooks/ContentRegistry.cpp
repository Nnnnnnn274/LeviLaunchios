#include "ContentRegistry.h"
#include "InlineHook.h"

#include <algorithm>
#include <cstring>
#include <dlfcn.h>
#include <map>
#include <mutex>
#include <unordered_map>

namespace ContentRegistry {

    // ── State ──────────────────────────────────────────────

    static std::mutex s_mutex;
    static bool s_initialized = false;
    static bool s_hooksInstalled = false;

    // Per-registry entries
    static std::unordered_map<RegistryType, std::vector<ContentEntry>> s_registries;

    // Callbacks
    static std::vector<RegistryHook> s_registryHooks[(size_t)RegistryType::_Count];
    static std::vector<DimensionInjectCallback> s_dimensionInjectCallbacks;
    static std::vector<BlockRegistryCallback> s_blockRegistryCallbacks;
    static std::vector<ItemRegistryCallback> s_itemRegistryCallbacks;

    // ── Hook state for App::init ───────────────────────────

    // Mangled: _ZN3App4initEv
    static const char *kAppInitSymbol = "__ZN3App4initEv";
    using AppInitFunc = void (*)(void *self);
    static AppInitFunc g_originalAppInit = nullptr;

    static void hook_AppInit(void *self) {
        if (g_originalAppInit) g_originalAppInit(self);
        // Fires after App::init completes — safe to register content
    }

    // ── Internal ──────────────────────────────────────────

    static void fireRegistryCallbacks(RegistryType type) {
        auto &hooks = s_registryHooks[(size_t)type];
        if (hooks.empty()) return;
        auto &entries = s_registries[type];
        for (auto &hook : hooks) {
            if (hook) hook(type, entries);
        }
    }

    // ── Public API ────────────────────────────────────────

    bool initialize() {
        std::lock_guard<std::mutex> lock(s_mutex);
        if (s_initialized) return true;

        bool regInit = true;
        for (int i = 0; i < (int)RegistryType::_Count; i++) {
            s_registries[(RegistryType)i] = {};
        }

        s_initialized = true;
        return true;
    }

    void onRegistryPopulate(RegistryType type, RegistryHook hook) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_registryHooks[(size_t)type].push_back(std::move(hook));
    }

    void onDimensionInject(DimensionInjectCallback callback) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_dimensionInjectCallbacks.push_back(std::move(callback));
    }

    void onBlockRegister(BlockRegistryCallback callback) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_blockRegistryCallbacks.push_back(std::move(callback));
    }

    void onItemRegister(ItemRegistryCallback callback) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_itemRegistryCallbacks.push_back(std::move(callback));
    }

    bool registerContent(const std::string &id, const std::string &name,
                          RegistryType type, void *nativePtr) {
        std::lock_guard<std::mutex> lock(s_mutex);
        auto &entries = s_registries[type];

        // Check for duplicates
        for (auto &e : entries) {
            if (e.id == id) {
                e.nativePtr = nativePtr;
                return true; // already registered, update ptr
            }
        }

        ContentEntry entry;
        entry.id = id;
        entry.name = name;
        entry.type = type;
        entry.numericId = (int)entries.size();
        entry.nativePtr = nativePtr;
        entries.push_back(std::move(entry));
        return true;
    }

    const ContentEntry *getEntry(RegistryType type, const std::string &id) {
        std::lock_guard<std::mutex> lock(s_mutex);
        auto it = s_registries.find(type);
        if (it == s_registries.end()) return nullptr;
        for (auto &e : it->second) {
            if (e.id == id) return &e;
        }
        return nullptr;
    }

    std::vector<ContentEntry> getEntries(RegistryType type) {
        std::lock_guard<std::mutex> lock(s_mutex);
        auto it = s_registries.find(type);
        if (it == s_registries.end()) return {};
        return it->second;
    }

    void reset() {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_registries.clear();
        for (int i = 0; i < (int)RegistryType::_Count; i++) {
            s_registryHooks[i].clear();
        }
        s_dimensionInjectCallbacks.clear();
        s_blockRegistryCallbacks.clear();
        s_itemRegistryCallbacks.clear();
    }

} // namespace ContentRegistry
