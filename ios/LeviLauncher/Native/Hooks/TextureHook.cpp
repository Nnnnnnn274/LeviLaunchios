#include "TextureHook.h"
#include "InlineHook.h"

#include <cstring>
#include <dlfcn.h>
#include <mutex>
#include <vector>

namespace TextureHook {

    // AppPlatform::loadImage mangled symbol for arm64
    // _ZN11AppPlatform9loadImageER9ImageDataRKNSt3__112basic_stringIcNS3_11char_traitsIcEENS3_9allocatorIcEEEb
    static const char *kLoadImageSymbol =
        "__ZN11AppPlatform9loadImageER9ImageDataRKNSt3__112basic_stringIcNS3_11char_traitsIcEENS3_9allocatorIcEEEb";

    // Type signature for AppPlatform::loadImage
    // bool AppPlatform::loadImage(ImageData&, std::string const&, bool preferBgra)
    using LoadImageFunc = bool (*)(void *self, ImageData &data,
                                    const std::string &path, bool preferBgra);

    static LoadImageFunc g_originalLoadImage = nullptr;
    static std::vector<TextureCallback> g_callbacks;
    static std::mutex g_mutex;
    static bool g_initialized = false;

    static bool hook_loadImage(void *self, ImageData &data,
                                const std::string &path, bool preferBgra) {
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            for (auto &cb : g_callbacks) {
                if (cb(path, preferBgra, data)) {
                    return true;
                }
            }
        }
        return g_originalLoadImage(self, data, path, preferBgra);
    }

    bool initialize() {
        if (g_initialized) return true;

        void *funcAddr = dlsym(RTLD_DEFAULT, kLoadImageSymbol);
        if (!funcAddr) {
            funcAddr = dlsym(RTLD_DEFAULT, kLoadImageSymbol + 2);
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

} // namespace TextureHook
