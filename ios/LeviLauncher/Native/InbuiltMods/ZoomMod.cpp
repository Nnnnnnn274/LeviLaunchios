#include "ZoomMod.hpp"

namespace ZoomMod {

    static bool g_enabled = false;
    static float g_zoomLevel = 3.0f;
    static bool g_animated = true;

    void setEnabled(bool enabled) {
        g_enabled = enabled;
        // TODO: Hook FOV calculation to apply zoom
    }

    bool isEnabled() {
        return g_enabled;
    }

    void setZoomLevel(float level) {
        g_zoomLevel = level;
    }

    float getZoomLevel() {
        return g_zoomLevel;
    }

    void setAnimated(bool animated) {
        g_animated = animated;
    }

    bool isAnimated() {
        return g_animated;
    }

} // namespace ZoomMod
