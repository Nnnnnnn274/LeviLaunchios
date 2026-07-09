#include "FpsMod.hpp"
#include <mach/mach_time.h>

namespace FpsMod {

    static bool g_enabled = false;
    static int g_currentFps = 0;
    static uint64_t g_lastFrameTime = 0;
    static int g_frameCount = 0;
    static double g_lastSecond = 0;

    void setEnabled(bool enabled) {
        g_enabled = enabled;
        if (enabled) {
            g_lastFrameTime = mach_absolute_time();
        }
    }

    bool isEnabled() {
        return g_enabled;
    }

    void onFrame() {
        if (!g_enabled) return;

        g_frameCount++;
        uint64_t now = mach_absolute_time();

        static mach_timebase_info_data_t s_timebase;
        if (s_timebase.denom == 0) {
            mach_timebase_info(&s_timebase);
        }

        uint64_t nanos = now - g_lastFrameTime;
        double seconds = (double)nanos * (double)s_timebase.numer / (double)s_timebase.denom / 1e9;

        if (seconds >= 1.0) {
            g_currentFps = g_frameCount;
            g_frameCount = 0;
            g_lastFrameTime = now;
        }
    }

    int getFps() {
        return g_currentFps;
    }

} // namespace FpsMod
