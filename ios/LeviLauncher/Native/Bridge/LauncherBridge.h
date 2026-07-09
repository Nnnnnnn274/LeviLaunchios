#ifndef LauncherBridge_h
#define LauncherBridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^LauncherFrameCallback)(double timestamp);
typedef void (^LauncherTouchCallback)(int phase, double x, double y);

@interface LauncherBridge : NSObject

// Preloader lifecycle
+ (BOOL)initializePreloader:(NSString *)gamePath;

// Mod management
+ (BOOL)injectMod:(NSString *)modPath;
+ (BOOL)isModLoaded:(NSString *)modId;
+ (NSArray<NSString *> *)loadedMods;
+ (int)modCount;
+ (NSString *)modInfoAtIndex:(int)index;

// Inbuilt mods
+ (BOOL)enableZoom:(BOOL)enabled;
+ (BOOL)enableFpsCounter:(BOOL)enabled;
+ (BOOL)enableSnaplook:(BOOL)enabled;

// Game state
+ (BOOL)isInGame;
+ (NSString *)minecraftVersion;

// Callbacks
+ (void)onFrame:(LauncherFrameCallback)callback;
+ (void)onTouch:(LauncherTouchCallback)callback;
+ (void)onViewDidLoad:(void (^)(void *viewController, void *view))callback;

// Fallback: walk the window hierarchy looking for the game VC
+ (BOOL)injectOverlayNow; // returns YES if a game VC was found

// Symbol resolution (for advanced usage)
+ (void * _Nullable)resolveSymbol:(NSString *)symbolName;

@end

NS_ASSUME_NONNULL_END

#endif /* LauncherBridge_h */
