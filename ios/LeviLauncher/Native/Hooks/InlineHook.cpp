#include "InlineHook.h"
#include <cstring>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>

namespace InlineHook {

    static const size_t kInstSize = 4;
    static const uintptr_t kBranchRange = 128ULL * 1024ULL * 1024ULL;
    static thread_local const char *g_lastError = "none";

    const char *lastError() {
        return g_lastError;
    }

    static bool hasProtection(void *address, vm_prot_t required) {
        vm_address_t regionAddress = (vm_address_t)address;
        vm_size_t regionSize = 0;
        vm_region_basic_info_data_64_t info = {};
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t objectName = MACH_PORT_NULL;
        kern_return_t result = vm_region(mach_task_self(), &regionAddress, &regionSize,
                                         VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info,
                                         &count, &objectName);
        if (objectName != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), objectName);
        return result == KERN_SUCCESS && regionAddress <= (vm_address_t)address &&
               (info.protection & required) == required;
    }

    static bool canAllocateExecutableTrampoline() {
        vm_address_t probe = 0;
        const vm_size_t pageSize = vm_page_size;
        if (vm_allocate(mach_task_self(), &probe, pageSize, VM_FLAGS_ANYWHERE) != KERN_SUCCESS) {
            return false;
        }
        const vm_prot_t needed = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE;
        bool available = vm_protect(mach_task_self(), probe, pageSize, false, needed) == KERN_SUCCESS &&
                         hasProtection((void *)probe, needed);
        vm_deallocate(mach_task_self(), probe, pageSize);
        return available;
    }

    static bool isPcRelative(uint32_t instruction) {
        // A one-instruction trampoline may copy ordinary prologue operations,
        // but relocating any of these changes its target or literal address.
        if ((instruction & 0x7C000000U) == 0x14000000U) return true; // B / BL
        if ((instruction & 0x1F000000U) == 0x10000000U) return true; // ADR / ADRP
        if ((instruction & 0xFF000010U) == 0x54000000U) return true; // B.cond
        if ((instruction & 0x7E000000U) == 0x34000000U) return true; // CBZ / CBNZ
        if ((instruction & 0x7E000000U) == 0x36000000U) return true; // TBZ / TBNZ
        if ((instruction & 0x3B000000U) == 0x18000000U) return true; // literal load
        return false;
    }

    static bool makeMemoryWritable(void *addr, size_t size) {
        const size_t pageSize = (size_t)vm_page_size;
        uintptr_t pageStart = (uintptr_t)addr & ~(pageSize - 1);
        size_t regionSize = ((uintptr_t)addr + size - pageStart + pageSize - 1) & ~(pageSize - 1);
        const vm_prot_t needed = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE;
        if (vm_protect(mach_task_self(), (vm_address_t)pageStart, regionSize, false,
                       needed) != KERN_SUCCESS) return false;
        if (hasProtection(addr, needed)) return true;
        vm_protect(mach_task_self(), (vm_address_t)pageStart, regionSize, false,
                   VM_PROT_READ | VM_PROT_EXECUTE);
        return false;
    }

    static void restoreMemoryExecutable(void *addr, size_t size) {
        const size_t pageSize = (size_t)vm_page_size;
        uintptr_t pageStart = (uintptr_t)addr & ~(pageSize - 1);
        size_t regionSize = ((uintptr_t)addr + size - pageStart + pageSize - 1) & ~(pageSize - 1);
        vm_protect(mach_task_self(), (vm_address_t)pageStart, regionSize, false,
                   VM_PROT_READ | VM_PROT_EXECUTE);
    }

    static void *tryAllocateAt(vm_address_t address, size_t pageSize) {
        vm_address_t candidate = address;
        kern_return_t result = vm_allocate(mach_task_self(), &candidate,
                                           (vm_size_t)pageSize, VM_FLAGS_FIXED);
        if (result != KERN_SUCCESS) return nullptr;
        result = vm_protect(mach_task_self(), (vm_address_t)candidate, pageSize, false,
                            VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (result != KERN_SUCCESS) {
            vm_deallocate(mach_task_self(), candidate, (vm_size_t)pageSize);
            return nullptr;
        }
        return (void *)(uintptr_t)candidate;
    }

    static void *allocateNear(void *target) {
        const size_t pageSize = (size_t)vm_page_size;
        const uintptr_t targetPage = (uintptr_t)target & ~(pageSize - 1);
        const uintptr_t maxDistance = kBranchRange - pageSize;

        for (uintptr_t distance = pageSize; distance <= maxDistance; distance += pageSize) {
            if (targetPage >= distance) {
                if (void *page = tryAllocateAt(targetPage - distance, pageSize)) return page;
            }
            if (targetPage <= UINTPTR_MAX - distance) {
                if (void *page = tryAllocateAt(targetPage + distance, pageSize)) return page;
            }
        }
        return nullptr;
    }

    static void writeAbsoluteBranch(uint32_t *destination, void *target) {
        // ldr x17, #8; br x17; .quad target
        destination[0] = 0x58000051U;
        destination[1] = 0xD61F0220U;
        uint64_t address = (uint64_t)(uintptr_t)target;
        std::memcpy(destination + 2, &address, sizeof(address));
    }

    bool install(void *target, void *hook, void **original) {
        g_lastError = "none";
        if (!target || !hook || !original) {
            g_lastError = "invalid hook argument";
            return false;
        }
        if (((uintptr_t)target & (kInstSize - 1)) != 0) {
            g_lastError = "target is not ARM64 instruction-aligned";
            return false;
        }
        if (!canAllocateExecutableTrampoline()) {
            g_lastError = "executable trampoline permission unavailable";
            return false;
        }

        uint32_t originalInst = *(uint32_t *)target;
        if (isPcRelative(originalInst)) {
            g_lastError = "first instruction requires ARM64 relocation";
            return false;
        }

        void *trampolinePage = allocateNear(target);
        if (!trampolinePage) {
            g_lastError = "no executable page available within ARM64 branch range";
            return false;
        }

        uint32_t *trampoline = (uint32_t *)trampolinePage;
        uint32_t *originalThunk = trampoline + 4;

        writeAbsoluteBranch(trampoline, hook);
        originalThunk[0] = originalInst;
        originalThunk[1] = branchInst((uintptr_t)(originalThunk + 1),
                                      (uintptr_t)target + kInstSize);
        if (originalThunk[1] == 0) {
            vm_deallocate(mach_task_self(), (vm_address_t)trampolinePage,
                          (vm_size_t)vm_page_size);
            g_lastError = "original trampoline is outside ARM64 branch range";
            return false;
        }

        uint32_t islandBranch = branchInst((uintptr_t)target, (uintptr_t)trampoline);
        if (islandBranch == 0) {
            vm_deallocate(mach_task_self(), (vm_address_t)trampolinePage,
                          (vm_size_t)vm_page_size);
            g_lastError = "branch island is outside ARM64 branch range";
            return false;
        }

        sys_icache_invalidate(trampolinePage, kInstSize * 6);
        if (vm_protect(mach_task_self(), (vm_address_t)trampolinePage, vm_page_size, false,
                       VM_PROT_READ | VM_PROT_EXECUTE) != KERN_SUCCESS) {
            vm_deallocate(mach_task_self(), (vm_address_t)trampolinePage,
                          (vm_size_t)vm_page_size);
            g_lastError = "could not seal trampoline as executable";
            return false;
        }

        if (!makeMemoryWritable(target, kInstSize)) {
            vm_deallocate(mach_task_self(), (vm_address_t)trampolinePage,
                          (vm_size_t)vm_page_size);
            g_lastError = "JIT could not make target text writable";
            return false;
        }

        *(uint32_t *)target = islandBranch;

        sys_icache_invalidate(target, kInstSize);
        restoreMemoryExecutable(target, kInstSize);

        *original = originalThunk;

        return true;
    }

} // namespace InlineHook
