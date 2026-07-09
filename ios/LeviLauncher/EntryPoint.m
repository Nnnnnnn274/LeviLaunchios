// LeviLauncher dylib entry point
// Called automatically when injected into Minecraft via dlopen
// This runs BEFORE Swift initialization - use it for minimal setup

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

__attribute__((constructor))
static void levi_launcher_init() {
    @autoreleasepool {
        NSLog(@"[LeviLauncher] dylib loaded at %s", __FILE__);

        // Signal the Swift side to initialize
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"LeviLauncherInitializationNotification"
             object:nil];
        });
    }
}

__attribute__((destructor))
static void levi_launcher_fini() {
    NSLog(@"[LeviLauncher] dylib unloaded");
}
