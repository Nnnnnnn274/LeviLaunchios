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
#import <sys/fcntl.h>
#import <stdio.h>

// Precomputed path to Documents/levilamina.ips (filled at init)
static char g_ips_path[4096];
static size_t g_ips_path_len;

static void levi_ensure_ips_path(void) {
    if (g_ips_path_len > 0) return;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                          NSUserDomainMask, YES);
    if ([paths count] == 0) return;
    NSString *p = [paths[0] stringByAppendingPathComponent:@"levilamina.ips"];
    g_ips_path_len = [p getCString:g_ips_path maxLength:sizeof(g_ips_path)
                          encoding:NSUTF8StringEncoding];
}

static void levi_write_ips_async(const char *msg, size_t len) {
    if (g_ips_path_len == 0) return;
    int fd = open(g_ips_path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    write(fd, msg, len);
    close(fd);
    write(STDERR_FILENO, msg, len);
}

static void levi_signal_handler(int sig) {
    const char *name = "?";
    switch (sig) {
        case SIGABRT: name = "SIGABRT"; break;
        case SIGSEGV: name = "SIGSEGV"; break;
        case SIGBUS:  name = "SIGBUS";  break;
        case SIGILL:  name = "SIGILL";  break;
    }
    char buf[256];
    int n = snprintf(buf, sizeof(buf),
                     "CRASH: signal %s\nSignal: %d\n\n", name, sig);
    if (n > 0) levi_write_ips_async(buf, (size_t)n);
    // Restore default and re-raise so ReportCrash generates a .ips
    signal(sig, SIG_DFL);
    raise(sig);
}

static void levi_exception_handler(NSException *exception) {
    levi_ensure_ips_path();
    if (g_ips_path_len > 0) {
        NSString *crash = [NSString stringWithFormat:
            @"CRASH: uncaught ObjC exception\nReason: %@\nStack:\n%@\n\n",
            exception.reason, exception.callStackSymbols];
        [crash writeToFile:[NSString stringWithUTF8String:g_ips_path]
                atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }
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
        // Precompute crash log path while Foundation is safe
        levi_ensure_ips_path();
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
