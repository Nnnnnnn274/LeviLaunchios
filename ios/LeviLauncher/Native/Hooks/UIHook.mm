#include "UIHook.h"
#include <objc/message.h>
#include <objc/runtime.h>
#include <mutex>
#include <vector>

namespace UIHook {

    static std::vector<ViewDidLoadCallback> g_viewDidLoadCallbacks;
    static std::mutex g_mutex;
    static bool g_initialized = false;

    static void (*orig_viewDidLoad)(id self, SEL _cmd) = nullptr;

    static void hook_viewDidLoad(id self, SEL _cmd) {
        if (orig_viewDidLoad) orig_viewDidLoad(self, _cmd);
        {
            std::lock_guard<std::mutex> lock(g_mutex);
            for (auto &cb : g_viewDidLoadCallbacks) {
                if (cb) {
                    void *view = (__bridge void *)((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("view"));
                    cb((__bridge void *)self, view);
                }
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

        SEL viewDidLoadSel = sel_registerName("viewDidLoad");
        Method m = class_getInstanceMethod(vcClass, viewDidLoadSel);
        if (!m) return false;

        orig_viewDidLoad = (void (*)(id, SEL))method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_viewDidLoad);

        g_initialized = true;
        return true;
    }

    void onViewDidLoad(ViewDidLoadCallback callback) {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_viewDidLoadCallbacks.push_back(std::move(callback));
    }

    void clearCallbacks() {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_viewDidLoadCallbacks.clear();
    }

} // namespace UIHook
