#ifndef LauncherBridge_h
#define LauncherBridge_h

#import <Foundation/Foundation.h>

// Swift-C++ bridge for native preloader and mod injection

NS_ASSUME_NONNULL_BEGIN

@interface LauncherBridge : NSObject

+ (BOOL)initializePreloader:(NSString *)gamePath;
+ (BOOL)injectMod:(NSString *)modPath;
+ (BOOL)isModLoaded:(NSString *)modId;
+ (NSArray<NSString *> *)loadedMods;

+ (BOOL)enableZoom:(BOOL)enabled;
+ (BOOL)enableFpsCounter:(BOOL)enabled;
+ (BOOL)enableSnaplook:(BOOL)enabled;

+ (int)modCount;
+ (NSString *)modInfoAtIndex:(int)index;

@end

NS_ASSUME_NONNULL_END

#endif /* LauncherBridge_h */
