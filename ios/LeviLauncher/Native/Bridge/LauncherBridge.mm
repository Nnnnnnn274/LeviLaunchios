#import "LauncherBridge.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <Foundation/Foundation.h>

// C++ preloader headers
#include "../Preloader/Preloader.hpp"
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
            g_preloaderInitialized = true;
        }
    }

    return result ? YES : NO;
}

+ (BOOL)injectMod:(NSString *)modPath {
    if (!g_preloaderInitialized) return NO;

    const char *path = [modPath UTF8String];
    return Preloader::loadMod(path) ? YES : NO;
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

@end
