#ifndef RENDERHOOK_H
#define RENDERHOOK_H

#include <functional>

namespace RenderHook {

    // Callback types for render pipeline
    using FrameCallback = std::function<void(double timestamp)>;
    using DrawCallback = std::function<void()>;

    // Initialize hooks on minecraftpeViewController drawFrame
    bool initialize();

    // Register callbacks called from drawFrame before game renders
    // Useful for overlay rendering
    void onBeforeFrame(DrawCallback callback);

    // Register per-frame update callbacks
    void onFrame(FrameCallback callback);

    // Remove all callbacks
    void clearCallbacks();

} // namespace RenderHook

#endif
