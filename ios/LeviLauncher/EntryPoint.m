// LeviLauncher dylib entry point
// Constructor polls for Swift runtime availability, then initializes.
// ObjC hooking (method_setImplementation) and fishhook work WITHOUT JIT;
// only InlineHook (ARM64 branch patching) needs vm_protect(PROT_EXEC).

#import <Foundation/Foundation.h>
#import <objc/message.h>

#pragma mark - Initialization

static void try_init(void) {
    // Poll until the Swift runtime has loaded LauncherEntry
    Class entryClass = objc_getClass("LauncherEntry");
    if (!entryClass) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            try_init();
        });
        return;
    }

    id (*msgSend)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id entry = msgSend((id)entryClass, sel_registerName("shared"));
    if (entry) {
        ((void (*)(id, SEL))objc_msgSend)(entry, sel_registerName("initialize"));
    }
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"LeviLauncherInitializationNotification"
     object:nil];
}

// Public symbol for injectors that want direct activation
__attribute__((visibility("default")))
void LeviLauncherInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class entryClass = objc_getClass("LauncherEntry");
        if (entryClass) {
            id (*msgSend)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
            id entry = msgSend((id)entryClass, sel_registerName("shared"));
            if (entry) {
                ((void (*)(id, SEL))objc_msgSend)(entry, sel_registerName("initialize"));
            }
        }
        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"LeviLauncherInitializationNotification"
         object:nil];
    });
}

__attribute__((constructor))
static void levi_launcher_init(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            try_init();
        });
    }
}

__attribute__((destructor))
static void levi_launcher_fini(void) {
    NSLog(@"[LeviLauncher] dylib unloaded");
}
