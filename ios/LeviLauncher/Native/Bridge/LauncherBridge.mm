#import "LauncherBridge.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "../Preloader/Preloader.hpp"
#include "../Hooks/UIHook.h"
#include "../InbuiltMods/ZoomMod.hpp"
#include "../InbuiltMods/FpsMod.hpp"
#include "../InbuiltMods/SnaplookMod.hpp"

@implementation LauncherBridge

static bool g_preloaderInitialized = false;

+ (BOOL)initializePreloader:(NSString *)gamePath {
    if (g_preloaderInitialized) return YES;

    const char *path = [gamePath UTF8String];
    bool result = Preloader::initialize(path);

    if (result) {
        result = Preloader::hookGameFunctions();
        if (result) {
            result = Preloader::hookRenderLoop();
        }
        if (result) {
            result = Preloader::hookInput();
        }
        if (result) {
            // Register FPS counter to tick on every frame
            Preloader::onFrame([](double) {
                FpsMod::onFrame();
            });

            g_preloaderInitialized = true;
        }
    }

    return result ? YES : NO;
}

+ (BOOL)injectMod:(NSString *)modPath {
    if (!g_preloaderInitialized) return NO;
    return Preloader::loadMod([modPath UTF8String]) ? YES : NO;
}

+ (BOOL)isModLoaded:(NSString *)modId {
    return Preloader::isModLoaded([modId UTF8String]) ? YES : NO;
}

+ (NSArray<NSString *> *)loadedMods {
    std::vector<std::string> mods = Preloader::getLoadedMods();
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:mods.size()];
    for (const auto &mod : mods) {
        [result addObject:[NSString stringWithUTF8String:mod.c_str()]];
    }
    return result;
}

+ (BOOL)enableZoom:(BOOL)enabled {
    ZoomMod::setEnabled(enabled == YES);
    return YES;
}

+ (BOOL)enableFpsCounter:(BOOL)enabled {
    FpsMod::setEnabled(enabled == YES);
    return YES;
}

+ (BOOL)enableSnaplook:(BOOL)enabled {
    SnaplookMod::setEnabled(enabled == YES);
    return YES;
}

+ (int)modCount {
    return (int)Preloader::getModCount();
}

+ (NSString *)modInfoAtIndex:(int)index {
    auto info = Preloader::getModInfo(index);
    return [NSString stringWithUTF8String:info.c_str()];
}

+ (BOOL)isInGame {
    return Preloader::isInGame() ? YES : NO;
}

+ (NSString *)minecraftVersion {
    return [NSString stringWithUTF8String:Preloader::minecraftVersion()];
}

+ (void)onFrame:(LauncherFrameCallback)callback {
    Preloader::onFrame([callback](double ts) {
        callback(ts);
    });
}

+ (void)onTouch:(LauncherTouchCallback)callback {
    Preloader::onTouch([callback](int phase, double x, double y) {
        callback(phase, x, y);
    });
}

+ (void)onViewDidLoad:(void (^)(void *viewController, void *view))callback {
    UIHook::onViewDidLoad([callback](void *vc, void *v) {
        callback(vc, v);
    });
}

+ (BOOL)injectOverlayNow {
    void *vc = UIHook::findGameViewController();
    if (!vc) return NO;
    id viewController = (__bridge id)vc;
    UIView *view = [viewController view];
    if (!view) return NO;
    UIHook::injectOverlayNow((__bridge void *)viewController, (__bridge void *)view);
    return YES;
}

+ (void *)resolveSymbol:(NSString *)symbolName {
    return Preloader::resolveSymbol([symbolName UTF8String]);
}

@end
