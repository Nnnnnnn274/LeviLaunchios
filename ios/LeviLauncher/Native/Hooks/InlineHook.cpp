#include "InlineHook.h"
#include <cstring>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <sys/mman.h>
#include <libkern/OSCacheControl.h>

namespace InlineHook {

    static const size_t kPageSize = 4096;
    static const size_t kInstSize = 4;

    static bool makeMemoryWritable(void *addr, size_t size) {
        uintptr_t pageStart = (uintptr_t)addr & ~(kPageSize - 1);
        size_t regionSize = ((uintptr_t)addr + size - pageStart + kPageSize - 1) & ~(kPageSize - 1);
        return vm_protect(mach_task_self(), (vm_address_t)pageStart, regionSize, false,
                          VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE) == KERN_SUCCESS;
    }

    static void *allocateTrampolinePage() {
        void *page = mmap(NULL, kPageSize, PROT_READ | PROT_WRITE | PROT_EXEC,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        return (page == MAP_FAILED) ? nullptr : page;
    }

    bool install(void *target, void *hook, void **original) {
        if (!target || !hook || !original) return false;

        uint32_t originalInst = *(uint32_t *)target;

        uint32_t branch = branchInst((uintptr_t)target, (uintptr_t)hook);
        if (branch == 0) return false;

        void *trampolinePage = allocateTrampolinePage();
        if (!trampolinePage) return false;

        uint32_t *trampoline = (uint32_t *)trampolinePage;

        trampoline[0] = originalInst;
        uint32_t retBranch = branchInst((uintptr_t)(trampoline + 1),
                                         (uintptr_t)target + kInstSize);
        if (retBranch == 0) {
            munmap(trampolinePage, kPageSize);
            return false;
        }
        trampoline[1] = retBranch;

        sys_icache_invalidate(trampolinePage, kInstSize * 2);

        if (!makeMemoryWritable(target, kInstSize)) {
            munmap(trampolinePage, kPageSize);
            return false;
        }

        *(uint32_t *)target = branch;

        sys_icache_invalidate(target, kInstSize);

        *original = trampoline;

        return true;
    }

} // namespace InlineHook
