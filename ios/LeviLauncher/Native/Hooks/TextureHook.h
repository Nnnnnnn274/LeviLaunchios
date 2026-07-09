#ifndef TEXTUREHOOK_H
#define TEXTUREHOOK_H

#include <cstdint>
#include <functional>
#include <string>

namespace TextureHook {

    // ImageData layout (approximate from MCPE iOS dump)
    struct ImageData {
        int width;
        int height;
        int stride;
        void *pixels;
        bool isExternal;
        uint32_t format;
    };

    // Texture path callback: return true to replace, fill out imageData
    using TextureCallback = std::function<bool(const std::string &path,
                                                bool preferBgra,
                                                ImageData &imageData)>;

    // Initialize the texture hook (install inline hook on AppPlatform::loadImage)
    bool initialize();

    // Register a callback for texture replacement
    void onTextureLoad(TextureCallback callback);

    // Remove all callbacks
    void clearCallbacks();

} // namespace TextureHook

#endif
