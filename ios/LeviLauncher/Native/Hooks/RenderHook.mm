#include "RenderHook.h"
#include <objc/message.h>
#include <objc/runtime.h>
#include <mach/mach_time.h>
#include <mutex>
#include <vector>

namespace RenderHook {

    static std::vector<DrawCallback> g_beforeDrawCallbacks;
    static std::vector<FrameCallback> g_frameCallbacks;
    static std::mutex g_mutex;
    static bool g_initialized = false;

    static void (*orig_drawFrame)(id self, SEL _cmd) = nullptr;

    static double getTimestamp() {
        static mach_timebase_info_data_t s_tb;
        if (s_tb.denom == 0) mach_timebase_info(&s_tb);
        uint64_t now = mach_absolute_time();
        return (double)now * (double)s_tb.numer / (double)s_tb.denom / 1e9;
    }

    static void hook_drawFrame(id self, SEL _cmd) {
        double timestamp = getTimestamp();
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            for (auto &cb : g_beforeDrawCallbacks) {
                if (cb) cb();
            }
        }
        if (orig_drawFrame) orig_drawFrame(self, _cmd);
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            for (auto &cb : g_frameCallbacks) {
                if (cb) cb(timestamp);
            }
        }
    }

    bool initialize() {
        if (g_initialized) return true;

        Class vcClass = objc_getClass("minecraftpeViewController");
        if (!vcClass) {
            vcClass = objc_getClass("MCGameViewController");
        }
        if (!vcClass) return false;

        SEL drawFrameSel = sel_registerName("drawFrame");
        Method m = class_getInstanceMethod(vcClass, drawFrameSel);
        if (!m) return false;

        orig_drawFrame = (void (*)(id, SEL))method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_drawFrame);

        g_initialized = true;
        return true;
    }

    void onBeforeFrame(DrawCallback callback) {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_beforeDrawCallbacks.push_back(std::move(callback));
    }

    void onFrame(FrameCallback callback) {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_frameCallbacks.push_back(std::move(callback));
    }

    void clearCallbacks() {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_beforeDrawCallbacks.clear();
        g_frameCallbacks.clear();
    }

} // namespace RenderHook
