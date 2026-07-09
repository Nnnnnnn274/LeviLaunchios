#ifndef FISHHOOK_HPP
#define FISHHOOK_HPP

#include <cstddef>
#include <cstdint>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include <vector>

namespace fishhook {

    // ── Mach-O parsing helpers ───────────────────────────────

    struct rebinding {
        const char *name;
        void *replacement;
        void **replaced;
    };

    static intptr_t slide() {
        static intptr_t sSlide = -1;
        if (sSlide == -1) {
            sSlide = _dyld_get_image_vmaddr_slide(0);
        }
        return sSlide;
    }

    static const segment_command_64 *findSegment(const struct mach_header_64 *mh,
                                                   const char *segName,
                                                   uint64_t &vmaddr,
                                                   uint64_t &vmsize,
                                                   uint64_t &fileoff) {
        const auto *lc = (const load_command *)((uintptr_t)mh + sizeof(mach_header_64));
        for (uint32_t i = 0; i < mh->ncmds; i++) {
            if (lc->cmd == LC_SEGMENT_64) {
                const auto *seg = (const segment_command_64 *)lc;
                if (strcmp(seg->segname, segName) == 0) {
                    vmaddr  = seg->vmaddr;
                    vmsize  = seg->vmsize;
                    fileoff = seg->fileoff;
                    return seg;
                }
            }
            lc = (const load_command *)((uintptr_t)lc + lc->cmdsize);
        }
        return nullptr;
    }

    static void performRebinding(const struct mach_header_64 *mh,
                                 intptr_t slide,
                                 const rebinding &rebind) {
        uint64_t linkedit_vmaddr = 0, linkedit_vmsize = 0, linkedit_fileoff = 0;
        if (!findSegment(mh, "__LINKEDIT", linkedit_vmaddr, linkedit_vmsize, linkedit_fileoff))
            return;

        uint64_t text_vmaddr = 0, text_vmsize = 0, text_fileoff = 0;
        if (!findSegment(mh, "__TEXT", text_vmaddr, text_vmsize, text_fileoff))
            return;

        uint64_t data_vmaddr = 0, data_vmsize = 0, data_fileoff = 0;
        if (!findSegment(mh, "__DATA_CONST", data_vmaddr, data_vmsize, data_fileoff))
            if (!findSegment(mh, "__DATA", data_vmaddr, data_vmsize, data_fileoff))
                return;

        const auto *lc = (const load_command *)((uintptr_t)mh + sizeof(mach_header_64));
        const dysymtab_command *dysymtab = nullptr;
        const symtab_command *symtab = nullptr;
        const linkedit_data_command *codeSig = nullptr;
        uint32_t filetype = 0;

        for (uint32_t i = 0; i < mh->ncmds; i++) {
            switch (lc->cmd) {
                case LC_DYSYMTAB:
                    dysymtab = (const dysymtab_command *)lc;
                    break;
                case LC_SYMTAB:
                    symtab = (const symtab_command *)lc;
                    break;
                case LC_CODE_SIGNATURE:
                    codeSig = (const linkedit_data_command *)lc;
                    break;
            }
            filetype = mh->filetype;
            lc = (const load_command *)((uintptr_t)lc + lc->cmdsize);
        }

        if (!dysymtab || !symtab) return;

        // Compute base addresses
        auto linkeditBase = (uintptr_t)slide + linkedit_vmaddr;
        auto textBase = (uintptr_t)slide + text_vmaddr;
        auto dataBase = (uintptr_t)slide + data_vmaddr;

        // Linkedit data offsets
        auto symoff = symtab->symoff;
        auto stroff = symtab->stroff;
        auto strsize = symtab->strsize;

        auto indirectSymoff = dysymtab->indirectsymoff;

        // Compute the delta from file offset to vm address for __LINKEDIT
        auto linkeditDelta = linkeditBase - linkedit_fileoff;

        auto syms = (const nlist_64 *)(linkeditDelta + symoff);
        auto strTab = (const char *)(linkeditDelta + stroff);
        auto indirectSym = (const uint32_t *)(linkeditDelta + indirectSymoff);

        // Iterate all sections looking for lazy and non-lazy symbol pointers
        lc = (const load_command *)((uintptr_t)mh + sizeof(mach_header_64));
        for (uint32_t i = 0; i < mh->ncmds; i++) {
            if (lc->cmd == LC_SEGMENT_64) {
                const auto *seg = (const segment_command_64 *)lc;
                auto section = (const section_64 *)((uintptr_t)seg + sizeof(segment_command_64));
                for (uint32_t j = 0; j < seg->nsects; j++) {
                    if ((section[j].flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS ||
                        (section[j].flags & SECTION_TYPE) == S_NON_LAZY_SYMBOL_POINTERS) {
                        auto *ptr = (uintptr_t *)(dataBase + (section[j].addr - data_vmaddr));
                        auto count = section[j].size / sizeof(void *);
                        auto indirectIndex = section[j].reserved1;

                        for (uint32_t k = 0; k < count; k++) {
                            auto symIndex = indirectSym[indirectIndex + k];
                            if (symIndex == INDIRECT_SYMBOL_ABS || symIndex == INDIRECT_SYMBOL_LOCAL)
                                continue;
                            auto strPtr = strTab + syms[symIndex].n_un.n_strx;
                            if (strcmp(strPtr, rebind.name) == 0) {
                                // Rebind
                                kern_return_t kr = vm_protect(mach_task_self(),
                                    (vm_address_t)&ptr[k], sizeof(void *), 0,
                                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                                if (kr == KERN_SUCCESS) {
                                    if (rebind.replaced && *rebind.replaced == nullptr)
                                        *rebind.replaced = (void *)ptr[k];
                                    ptr[k] = (uintptr_t)rebind.replacement;
                                    vm_protect(mach_task_self(),
                                        (vm_address_t)&ptr[k], sizeof(void *), 0,
                                        VM_PROT_READ | VM_PROT_EXECUTE);
                                }
                            }
                        }
                    }
                }
            }
            lc = (const load_command *)((uintptr_t)lc + lc->cmdsize);
        }
    }

    static int rebindSymbols(struct rebinding rebindings[], size_t count) {
        auto slide = _dyld_get_image_vmaddr_slide(0);
        auto mh = (const struct mach_header_64 *)_dyld_get_image_header(0);

        for (size_t i = 0; i < count; i++) {
            performRebinding(mh, slide, rebindings[i]);
        }
        return 0;
    }

} // namespace fishhook

#endif // FISHHOOK_HPP
