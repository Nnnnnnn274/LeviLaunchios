// LeviLauncher dylib entry point
// Constructor only arms a retry timer – real init happens post-JIT.

#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <objc/message.h>
#import <unistd.h>

#pragma mark - JIT detection

static bool jit_is_available(void) {
    vm_size_t page_size = sysconf(_SC_PAGESIZE);
    vm_address_t addr = 0;
    kern_return_t kr = vm_allocate(mach_task_self(), &addr, page_size,
                                   VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) return false;

    kr = vm_protect(mach_task_self(), addr, page_size, 0,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    vm_deallocate(mach_task_self(), addr, page_size);
    return kr == KERN_SUCCESS;
}

#pragma mark - Initialization

static void try_init(void) {
    if (!jit_is_available()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            try_init();
        });
        return;
    }

    // Register observer and trigger init
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
