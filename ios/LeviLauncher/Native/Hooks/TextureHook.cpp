#include "TextureHook.h"
#include "InlineHook.h"

#include <cstring>
#include <dlfcn.h>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace TextureHook {

    // AppPlatform::loadImage mangled symbol for arm64
    // _ZN11AppPlatform9loadImageER9ImageDataRKNSt3__112basic_stringIcNS3_11char_traitsIcEENS3_9allocatorIcEEEb
    static const char *kLoadImageSymbols[] = {
        // dlsym expects the Itanium C++ name, without Mach-O's additional
        // symbol-table underscore.
        "_ZN11AppPlatform9loadImageER9ImageDataRKNSt3__112basic_stringIcNS3_11char_traitsIcEENS3_9allocatorIcEEEb",
        // Keep the raw Mach-O spelling as a fallback for unusual loaders.
        "__ZN11AppPlatform9loadImageER9ImageDataRKNSt3__112basic_stringIcNS3_11char_traitsIcEENS3_9allocatorIcEEEb",
    };

    // Type signature for AppPlatform::loadImage
    // bool AppPlatform::loadImage(ImageData&, std::string const&, bool preferBgra)
    using LoadImageFunc = bool (*)(void *self, ImageData &data,
                                    const std::string &path, bool preferBgra);

    static LoadImageFunc g_originalLoadImage = nullptr;
    static std::vector<TextureCallback> g_callbacks;
    static std::unordered_map<std::string, std::string> g_overrides;
    static std::mutex g_mutex;
    static bool g_initialized = false;

    static std::string normalizePath(const std::string &value) {
        std::string result;
        result.reserve(value.size());
        for (char c : value) {
            if (c == '\\') c = '/';
            if (c >= 'A' && c <= 'Z') c = (char)(c - 'A' + 'a');
            result.push_back(c);
        }
        while (result.rfind("./", 0) == 0) result.erase(0, 2);
        while (!result.empty() && result.front() == '/') result.erase(0, 1);
        return result;
    }

    static bool findOverride(const std::string &path, std::string &replacement) {
        std::string key = normalizePath(path);
        std::lock_guard<std::mutex> lock(g_mutex);
        auto found = g_overrides.find(key);
        if (found == g_overrides.end()) {
            const size_t slash = key.find_last_of('/');
            const size_t dot = key.find_last_of('.');
            if (dot != std::string::npos && (slash == std::string::npos || dot > slash)) {
                found = g_overrides.find(key.substr(0, dot));
            } else {
                found = g_overrides.find(key + ".png");
            }
        }
        if (found == g_overrides.end()) return false;
        replacement = found->second;
        return true;
    }

    static bool hook_loadImage(void *self, ImageData &data,
                                const std::string &path, bool preferBgra) {
        std::string replacement;
        if (findOverride(path, replacement)) {
            if (g_originalLoadImage(self, data, replacement, preferBgra)) {
                return true;
            }
            // A malformed or removed override must not turn a vanilla texture
            // into a missing-texture tile.
            return g_originalLoadImage(self, data, path, preferBgra);
        }

        std::vector<TextureCallback> callbacks;
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            callbacks = g_callbacks;
        }
        for (auto &cb : callbacks) {
            if (cb(path, preferBgra, data)) {
                return true;
            }
        }
        return g_originalLoadImage(self, data, path, preferBgra);
    }

    bool initialize() {
        if (g_initialized) return true;

        void *funcAddr = nullptr;
        for (const char *symbol : kLoadImageSymbols) {
            funcAddr = dlsym(RTLD_DEFAULT, symbol);
            if (funcAddr) break;
        }
        if (!funcAddr) return false;

        void *orig = nullptr;
        if (!InlineHook::install(funcAddr, (void *)hook_loadImage, &orig)) {
            return false;
        }

        g_originalLoadImage = (LoadImageFunc)orig;
        g_initialized = true;
        return true;
    }

    void onTextureLoad(TextureCallback callback) {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_callbacks.push_back(std::move(callback));
    }

    void clearCallbacks() {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_callbacks.clear();
    }

    void setTextureOverrides(
        const std::vector<std::pair<std::string, std::string>> &overrides) {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_overrides.clear();
        g_overrides.reserve(overrides.size());
        for (const auto &entry : overrides) {
            if (!entry.first.empty() && !entry.second.empty()) {
                g_overrides[normalizePath(entry.first)] = entry.second;
            }
        }
    }

    size_t textureOverrideCount() {
        std::lock_guard<std::mutex> lock(g_mutex);
        return g_overrides.size();
    }

    bool isInitialized() {
        std::lock_guard<std::mutex> lock(g_mutex);
        return g_initialized;
    }

} // namespace TextureHook
