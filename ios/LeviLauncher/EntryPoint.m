// LeviLauncher dylib entry point
// Constructor polls for Swift runtime availability, then initializes.
// ObjC hooking (method_setImplementation) and fishhook work WITHOUT JIT;
// only InlineHook (ARM64 branch patching) needs vm_protect(PROT_EXEC).

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>

#pragma mark - Diagnostics (write to app's Documents dir)

static void levi_log(NSString *msg) {
    NSLog(@"[LeviLauncher] %@", msg);
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                              NSUserDomainMask, YES);
        if ([paths count] > 0) {
            NSString *logPath = [paths[0] stringByAppendingPathComponent:@"levilauncher.log"];
            NSString *line = [NSString stringWithFormat:@"%@: %@\n",
                              [NSISO8601DateFormatter new], msg];
            NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath];
            if (!fh) {
                [line writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            } else {
                [fh seekToEndOfFile];
                [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
                [fh closeFile];
            }
        }
    } @catch (NSException *) {}
}

#pragma mark - Initialization

static void try_init(void) {
    // Poll until the Swift runtime has loaded LauncherEntry
    Class entryClass = objc_getClass("LauncherEntry");
    if (!entryClass) {
        levi_log(@"LauncherEntry not found yet, polling...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            try_init();
        });
        return;
    }

    levi_log(@"LauncherEntry found, calling initialize...");
    id (*msgSend)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id entry = msgSend((id)entryClass, sel_registerName("shared"));
    if (entry) {
        ((void (*)(id, SEL))objc_msgSend)(entry, sel_registerName("initialize"));
        levi_log(@"initialize returned");
    } else {
        levi_log(@"LauncherEntry.shared returned nil");
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
        levi_log(@"Constructor running");
        // Schedule on main run loop (more reliable at load time than dispatch_async)
        CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
            try_init();
        });
        CFRunLoopWakeUp(CFRunLoopGetMain());
    }
}

__attribute__((destructor))
static void levi_launcher_fini(void) {
    NSLog(@"[LeviLauncher] dylib unloaded");
}
