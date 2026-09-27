#include "BlockItemAPI.h"
#include "ContentRegistry.h"
#include "InlineHook.h"

#include <dlfcn.h>
#include <cstdio>
#include <mutex>
#include <vector>

namespace BlockItemAPI {

    // ── State ──────────────────────────────────────────────

    static std::mutex s_mutex;
    static bool s_initialized = false;
    static bool s_blockHooksInstalled = false;
    static bool s_itemHooksInstalled = false;

    static std::vector<BlockProvider> s_blockProviders;
    static std::vector<ItemProvider> s_itemProviders;
    static std::vector<BlockRegistrationHook> s_blockRegHooks;
    static std::vector<ItemRegistrationHook> s_itemRegHooks;

    static std::vector<BlockDefinition> s_customBlocks;
    static std::vector<ItemDefinition> s_customItems;

    // ── Hook: Block registration ───────────────────────────
    // Target: Block::initBlocks() or similar block registration function
    // These are static functions called during App::init()

    static const char *kPossibleBlockSymbols[] = {
        "_ZN5Block10initBlocksEv",
        "_ZN5Block19initBlockRegistriesEv",
        "__ZN5Block10initBlocksEv",
        "__ZN5Block19initBlockRegistriesEv",
        nullptr
    };

    using BlockInitFunc = void (*)();
    static BlockInitFunc g_originalBlockInit = nullptr;

    static void hook_blockInit() {
        if (g_originalBlockInit) g_originalBlockInit();
        {
            std::lock_guard<std::mutex> lock(s_mutex);
            s_customBlocks.clear();
            for (auto &provider : s_blockProviders) {
                provider(s_customBlocks);
            }
            for (auto &block : s_customBlocks) {
                ContentRegistry::registerContent(
                    block.id, block.displayName,
                    ContentRegistry::RegistryType::Block);
            }
        }
    }

    // ── Hook: Item registration ────────────────────────────
    static const char *kPossibleItemSymbols[] = {
        "_ZN4Item9initItemsEv",
        "_ZN4Item18initItemRegistriesEv",
        "__ZN4Item9initItemsEv",
        "__ZN4Item18initItemRegistriesEv",
        nullptr
    };

    using ItemInitFunc = void (*)();
    static ItemInitFunc g_originalItemInit = nullptr;

    static void hook_itemInit() {
        if (g_originalItemInit) g_originalItemInit();
        {
            std::lock_guard<std::mutex> lock(s_mutex);
            s_customItems.clear();
            for (auto &provider : s_itemProviders) {
                provider(s_customItems);
            }
            for (auto &item : s_customItems) {
                ContentRegistry::registerContent(
                    item.id, item.displayName,
                    ContentRegistry::RegistryType::Item);
            }
        }
    }

    // ── Public API ────────────────────────────────────────

    bool initialize() {
        std::lock_guard<std::mutex> lock(s_mutex);
        if (s_blockHooksInstalled && s_itemHooksInstalled) return true;

        if (!s_blockHooksInstalled) {
            for (int i = 0; kPossibleBlockSymbols[i] != nullptr; i++) {
                void *sym = dlsym(RTLD_DEFAULT, kPossibleBlockSymbols[i]);
                if (sym) {
                    void *orig = nullptr;
                    if (InlineHook::install(sym, (void *)hook_blockInit, &orig)) {
                        g_originalBlockInit = (BlockInitFunc)orig;
                        s_blockHooksInstalled = true;
                        break;
                    } else {
                        std::fprintf(stderr, "[LeviLauncher] Block hook failed for %s: %s\n",
                                     kPossibleBlockSymbols[i], InlineHook::lastError());
                    }
                }
            }
        }

        if (!s_itemHooksInstalled) {
            for (int i = 0; kPossibleItemSymbols[i] != nullptr; i++) {
                void *sym = dlsym(RTLD_DEFAULT, kPossibleItemSymbols[i]);
                if (sym) {
                    void *orig = nullptr;
                    if (InlineHook::install(sym, (void *)hook_itemInit, &orig)) {
                        g_originalItemInit = (ItemInitFunc)orig;
                        s_itemHooksInstalled = true;
                        break;
                    } else {
                        std::fprintf(stderr, "[LeviLauncher] Item hook failed for %s: %s\n",
                                     kPossibleItemSymbols[i], InlineHook::lastError());
                    }
                }
            }
        }

        s_initialized = s_blockHooksInstalled && s_itemHooksInstalled;
        return s_initialized;
    }

    bool blocksHooked() {
        std::lock_guard<std::mutex> lock(s_mutex);
        return s_blockHooksInstalled;
    }

    bool itemsHooked() {
        std::lock_guard<std::mutex> lock(s_mutex);
        return s_itemHooksInstalled;
    }

    void onRegisterBlocks(BlockProvider provider) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_blockProviders.push_back(std::move(provider));
    }

    void onRegisterItems(ItemProvider provider) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_itemProviders.push_back(std::move(provider));
    }

    void onBlockRegistration(BlockRegistrationHook hook) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_blockRegHooks.push_back(std::move(hook));
    }

    void onItemRegistration(ItemRegistrationHook hook) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_itemRegHooks.push_back(std::move(hook));
    }

} // namespace BlockItemAPI
