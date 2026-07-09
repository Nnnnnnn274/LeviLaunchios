// LeviLauncher dylib entry point
// Constructor polls for Swift runtime availability, then initializes.
// ObjC hooking (method_setImplementation) and fishhook work WITHOUT JIT;
// only InlineHook (ARM64 branch patching) needs vm_protect(PROT_EXEC).

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>

#pragma mark - Diagnostics (write to app's Documents dir)

static void levi_log(NSString *msg, ...) {
    va_list args;
    va_start(args, msg);
    NSString *formatted = [[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);
    NSLog(@"[LeviLauncher] %@", formatted);
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                               NSUserDomainMask, YES);
        if ([paths count] > 0) {
            NSString *logPath = [paths[0] stringByAppendingPathComponent:@"levilauncher.log"];
            NSString *dateStr = [[NSISO8601DateFormatter new] stringFromDate:[NSDate now]];
            NSString *line = [NSString stringWithFormat:@"%@: %@\n", dateStr, formatted];
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

#pragma mark - Crash handlers

#import <signal.h>
#import <unistd.h>

static void levi_signal_handler(int sig) {
    const char *name = "?";
    switch (sig) {
        case SIGABRT: name = "SIGABRT"; break;
        case SIGSEGV: name = "SIGSEGV"; break;
        case SIGBUS:  name = "SIGBUS";  break;
        case SIGILL:  name = "SIGILL";  break;
    }
    write(STDERR_FILENO, "[LeviLauncher] CRASH: signal ", 28);
    write(STDERR_FILENO, name, 10);
    write(STDERR_FILENO, "\n", 1);
    // Restore default and re-raise so ReportCrash generates a .ips
    signal(sig, SIG_DFL);
    raise(sig);
}

static void levi_exception_handler(NSException *exception) {
    levi_log(@"CRASH: uncaught ObjC exception: %@\n%@",
           exception.reason, exception.callStackSymbols);
    // abort() triggers SIGABRT → levi_signal_handler → re-raise → .ips
    abort();
}

#pragma mark - Initialization

static void try_init(int retry) {
    // Primary: exact name with explicit @objc(LauncherEntry)
    Class entryClass = objc_getClass("LauncherEntry");
    // Fallback: if we exhausted retries, try mangled Swift names
    if (!entryClass && retry >= 60) {
        levi_log(@"Gave up after 60 retries. Trying mangled names...");
        entryClass = objc_getClass("_TtC12LeviLauncher14LauncherEntry");
        if (!entryClass) entryClass = objc_getClass("LeviLauncher.LauncherEntry");
        if (!entryClass) {
            levi_log(@"Swift class never registered on ObjC runtime");
            return;
        }
        levi_log(@"Found via mangled name");
    }
    if (!entryClass) {
        levi_log(@"LauncherEntry not found yet (retry %d/60)...", retry);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            try_init(retry + 1);
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
    // Install crash handlers immediately (before any other code)
    NSSetUncaughtExceptionHandler(&levi_exception_handler);
    signal(SIGABRT, levi_signal_handler);
    signal(SIGSEGV, levi_signal_handler);
    signal(SIGBUS, levi_signal_handler);
    signal(SIGILL, levi_signal_handler);

    @autoreleasepool {
        levi_log(@"Constructor running");
        // Schedule on main run loop (more reliable at load time than dispatch_async)
        CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
            try_init(0);
        });
        CFRunLoopWakeUp(CFRunLoopGetMain());
    }
}

__attribute__((destructor))
static void levi_launcher_fini(void) {
    NSLog(@"[LeviLauncher] dylib unloaded");
}
