#include "UIHook.h"
#include <objc/message.h>
#include <objc/runtime.h>
#include <UIKit/UIKit.h>
#include <mutex>
#include <vector>

namespace UIHook {

    static std::vector<ViewDidLoadCallback> g_viewDidLoadCallbacks;
    static std::mutex g_mutex;
    static bool g_initialized = false;

    static void (*orig_viewDidLoad)(id self, SEL _cmd) = nullptr;

    // Known Minecraft game view controller class names (ordered by likelihood)
    static const char *kGameVCClassNames[] = {
        "minecraftpeViewController",
        "MCGameViewController",
        "GameViewController",
        "MinecraftViewController",
        "ScreenViewController",
        "minecraft::MinecraftGameViewController",
        nullptr
    };

    static Class findGameVCClass() {
        for (const char **name = kGameVCClassNames; *name != nullptr; name++) {
            Class cls = objc_getClass(*name);
            if (cls) return cls;
        }
        return nil;
    }

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

        Class vcClass = findGameVCClass();
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

    static BOOL isGameVC(UIViewController *vc) {
        NSString *name = NSStringFromClass([vc class]);
        for (const char **kn = kGameVCClassNames; *kn != nullptr; kn++) {
            NSString *candidate = [NSString stringWithUTF8String:*kn];
            if ([name containsString:candidate]) return YES;
        }
        // Also check if it's the key window's root VC and has a GL/Metal view
        if ([name containsString:@"ViewController"] &&
            [[vc view] isKindOfClass:NSClassFromString(@"EAGLView")]) {
            return YES;
        }
        return NO;
    }

    static UIViewController *scanVC(UIViewController *root) {
        if (!root) return nil;
        if (isGameVC(root)) return root;

        UIViewController *presented = root.presentedViewController;
        if (presented && isGameVC(presented)) return presented;

        for (UIViewController *child in root.childViewControllers) {
            UIViewController *found = scanVC(child);
            if (found) return found;
        }
        return nil;
    }

    void *findGameViewController() {
        // Try scene-based windows (iOS 13+)
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *window in ws.windows) {
                UIViewController *found = scanVC(window.rootViewController);
                if (found) return (__bridge void *)found;
            }
        }
        // Fallback to classic windows
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            UIViewController *found = scanVC(window.rootViewController);
            if (found) return (__bridge void *)found;
        }
        return nullptr;
    }

    void injectOverlayNow(void *viewController, void *view) {
        std::lock_guard<std::mutex> lock(g_mutex);
        for (auto &cb : g_viewDidLoadCallbacks) {
            if (cb) cb(viewController, view);
        }
    }

} // namespace UIHook
