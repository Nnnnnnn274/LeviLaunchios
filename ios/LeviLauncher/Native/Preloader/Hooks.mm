#import "Hooks.h"

#import <objc/message.h>
#import <objc/runtime.h>
#import <QuartzCore/CADisplayLink.h>
#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import <mutex>
#import <vector>

// ── Callback state ──────────────────────────────────────────

static std::vector<Preloader::FrameCallback> g_frameCallbacks;
static std::vector<Preloader::TouchCallback> g_touchCallbacks;
static std::mutex g_callbackMutex;

static CADisplayLink *g_displayLink = nil;
static bool g_hooksInitialized = false;
static bool g_isInGame = false;
static bool g_isPauseMenu = false;

// ── Swizzle state ───────────────────────────────────────────

// Using standard pattern: swap implementations of original selector
// with a unique swizzled selector so we can still call original.

static SEL g_origViewDidAppearSel = nil;
static SEL g_origViewDidDisappearSel = nil;

// ── CADisplayLink target ────────────────────────────────────

@interface HookHelper : NSObject
+ (instancetype)shared;
- (void)frameCallback:(CADisplayLink *)sender;
@end

@implementation HookHelper

+ (instancetype)shared {
    static HookHelper *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)frameCallback:(__unused CADisplayLink *)sender {
    std::lock_guard<std::mutex> lock(g_callbackMutex);
    double timestamp = CACurrentMediaTime();
    for (auto &cb : g_frameCallbacks) {
        if (cb) cb(timestamp);
    }
}

@end

// ── Swizzled hook implementations ───────────────────────────

// sendEvent: is swizzled by directly replacing IMP
static void (*orig_sendEvent)(id self, SEL _cmd, UIEvent *event) = nullptr;

static void hook_sendEvent(id self, SEL _cmd, UIEvent *event) {
    if (orig_sendEvent) {
        orig_sendEvent(self, _cmd, event);
    }

    if (event.type == UIEventTypeTouches) {
        NSSet *touches = [event allTouches];
        for (UITouch *touch in touches) {
            UITouchPhase phase = touch.phase;
            if (phase == UITouchPhaseBegan || phase == UITouchPhaseMoved || phase == UITouchPhaseEnded) {
                CGPoint loc = [touch locationInView:nil];
                std::lock_guard<std::mutex> lock(g_callbackMutex);
                for (auto &cb : g_touchCallbacks) {
                    if (cb) cb((int)phase, loc.x, loc.y);
                }
            }
        }
    }
}

// viewDidAppear: and viewDidDisappear: are swizzled via selector swap.
// The original selector now points to our hook; the original IMP was
// moved to a unique selector so hooks can call through.

static void hook_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    // Call original by using the swizzled selector
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, g_origViewDidAppearSel, animated);

    g_isInGame = true;
    g_isPauseMenu = false;

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        g_displayLink = [CADisplayLink displayLinkWithTarget:HookHelper.shared
                                                    selector:@selector(frameCallback:)];
        [g_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}

static void hook_viewDidDisappear(id self, SEL _cmd, BOOL animated) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(self, g_origViewDidDisappearSel, animated);
    g_isInGame = false;
}

// ── Swizzle: exchange original selector with a unique swizzled one ─

static bool swizzleViewSelector(Class cls, SEL originalSel, IMP hookIMP, SEL *origOutSel) {
    Method m = class_getInstanceMethod(cls, originalSel);
    if (!m) return false;

    // Create a unique selector for the original implementation
    NSString *origName = NSStringFromSelector(originalSel);
    NSString *swizzledName = [NSString stringWithFormat:@"__pl_%@", origName];
    SEL swizzledSel = sel_registerName([swizzledName UTF8String]);

    // If the swizzled selector already exists, this class was already processed
    if (class_getInstanceMethod(cls, swizzledSel)) {
        if (origOutSel) *origOutSel = swizzledSel;
        return true;
    }

    // Add the hook implementation under the swizzled selector,
    // then swap implementations so originalSel → hookIMP
    IMP origIMP = method_getImplementation(m);
    const char *typeEncoding = method_getTypeEncoding(m);

    if (class_addMethod(cls, swizzledSel, origIMP, typeEncoding)) {
        // Swizzle: originalSel now points to hookIMP
        method_setImplementation(m, hookIMP);
        if (origOutSel) *origOutSel = swizzledSel;
        return true;
    }

    return false;
}

// ── Public API ──────────────────────────────────────────────

void Hooks_Initialize() {
    if (g_hooksInitialized) return;

    @autoreleasepool {
        // 1. Hook UIApplication sendEvent: for touch interception
        Method sendEventMethod = class_getInstanceMethod(
            objc_getClass("UIApplication"), @selector(sendEvent:));
        if (sendEventMethod) {
            orig_sendEvent = (void (*)(id, SEL, UIEvent *))
                method_getImplementation(sendEventMethod);
            method_setImplementation(sendEventMethod, (IMP)hook_sendEvent);
        }

        // 2. Hook Minecraft view controller lifecycle
        const char *classNames[] = {
            "MCGameViewController", "MinecraftViewController",
            "GameViewController", "MCMainViewController",
            "ViewController", nil
        };
        Class vcClass = nil;
        for (int i = 0; classNames[i] != nil; i++) {
            vcClass = objc_getClass(classNames[i]);
            if (vcClass) break;
        }

        if (vcClass) {
            swizzleViewSelector(vcClass, @selector(viewDidAppear:),
                               (IMP)hook_viewDidAppear, &g_origViewDidAppearSel);
            swizzleViewSelector(vcClass, @selector(viewDidDisappear:),
                               (IMP)hook_viewDidDisappear, &g_origViewDidDisappearSel);
        }

        g_hooksInitialized = true;
    }
}

// ── C API ───────────────────────────────────────────────────

bool Hook_ObjCMethod(const char *className, const char *selectorName,
                     void *replacement, void **original) {
    Class cls = objc_getClass(className);
    if (!cls) return false;

    SEL sel = sel_registerName(selectorName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return false;

    if (original) *original = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)replacement);
    return true;
}

bool Hook_ObjCMethodExact(const char *className, const char *selectorName,
                          void *replacementBlock, void **original) {
    Class cls = objc_getClass(className);
    if (!cls) return false;

    SEL sel = sel_registerName(selectorName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return false;

    IMP replacementIMP = imp_implementationWithBlock((__bridge id)replacementBlock);
    if (original) *original = (void *)method_getImplementation(m);
    method_setImplementation(m, replacementIMP);
    return true;
}

void Hooks_AddFrameCallback_C(void (*callback)(double)) {
    Hooks_AddFrameCallback(Preloader::FrameCallback(callback));
}

void Hooks_AddTouchCallback_C(void (*callback)(int, double, double)) {
    Hooks_AddTouchCallback(Preloader::TouchCallback(callback));
}

// ── C++ API ─────────────────────────────────────────────────

void Hooks_AddFrameCallback(Preloader::FrameCallback callback) {
    std::lock_guard<std::mutex> lock(g_callbackMutex);
    g_frameCallbacks.push_back(std::move(callback));
}

void Hooks_AddTouchCallback(Preloader::TouchCallback callback) {
    std::lock_guard<std::mutex> lock(g_callbackMutex);
    g_touchCallbacks.push_back(std::move(callback));
}

bool Hooks_IsInGame() {
    return g_isInGame;
}

bool Hooks_IsPauseMenu() {
    return g_isPauseMenu;
}
