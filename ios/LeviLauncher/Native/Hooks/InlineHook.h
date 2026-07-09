#ifndef INLINEHOOK_H
#define INLINEHOOK_H

#include <cstddef>
#include <cstdint>

namespace InlineHook {

    // Instruction encoding helpers
    static inline uint32_t branchInst(uintptr_t from, uintptr_t to) {
        int64_t offset = (int64_t)(to - from);
        if (offset < -134217728 || offset > 134217727) return 0;
        return 0x14000000 | ((uint32_t)((offset >> 2) & 0x03FFFFFF));
    }

    static inline uint32_t branchLinkInst(uintptr_t from, uintptr_t to) {
        int64_t offset = (int64_t)(to - from);
        if (offset < -134217728 || offset > 134217727) return 0;
        return 0x94000000 | ((uint32_t)((offset >> 2) & 0x03FFFFFF));
    }

    static inline uint32_t nopInst() { return 0xD503201F; }

    // Install an inline hook at `target` that redirects to `hook`.
    // On success, writes the original function pointer to `original` and returns true.
    // The original function pointer points to a trampoline the same length as target.
    bool install(void *target, void *hook, void **original);

} // namespace InlineHook

#endif
