#include "Preloader.hpp"
#include "Fishhook.hpp"
#include "Hooks.h"
#include "MinecraftAPI.hpp"
#include "Native/Hooks/InlineHook.h"
#include "Native/Hooks/TextureHook.h"
#include "Native/Hooks/RenderHook.h"
#include "Native/Hooks/UIHook.h"
#include "Native/Hooks/ContentRegistry.h"
#include "Native/Hooks/DimensionAPI.h"
#include "Native/Hooks/BlockItemAPI.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <cstring>
#include <map>
#include <mutex>
#include <vector>

namespace Preloader {

    // ── Internal state ──────────────────────────────────────

    static std::mutex s_mutex;
    static bool s_initialized = false;
    static std::string s_gamePath;
    static std::string s_minecraftVersion;
    static int s_majorVersion = 26;

    static std::vector<ModInfo> s_loadedMods;
    static std::map<std::string, void *> s_modHandles;

    // ── Minecraft binary info ────────────────────────────────

    static intptr_t s_baseAddress = 0;
    static const struct mach_header_64 *s_mh = nullptr;

    static void captureBinaryInfo() {
        s_mh = (const struct mach_header_64 *)_dyld_get_image_header(0);
        s_baseAddress = _dyld_get_image_vmaddr_slide(0);
    }

    static std::string detectMinecraftVersion() {
        CFBundleRef mainBundle = CFBundleGetMainBundle();
        if (mainBundle) {
            CFStringRef key = CFSTR("CFBundleShortVersionString");
            CFTypeRef value = CFBundleGetValueForInfoDictionaryKey(mainBundle, key);
            if (value && CFGetTypeID(value) == CFStringGetTypeID()) {
                char buf[64] = {};
                if (CFStringGetCString((CFStringRef)value, buf, sizeof(buf),
                                        kCFStringEncodingUTF8)) {
                    return std::string(buf);
                }
            }
        }
        return "26.32";
    }

    // ── Initialization ──────────────────────────────────────

    bool initialize(const std::string &gamePath) {
        std::lock_guard<std::mutex> lock(s_mutex);
        if (s_initialized) return true;

        s_gamePath = gamePath;
        captureBinaryInfo();

        s_minecraftVersion = detectMinecraftVersion();
        s_majorVersion = MinecraftAPI::detectVersion(s_minecraftVersion);

        Hooks_Initialize();
        RenderHook::initialize();
        UIHook::initialize();
        TextureHook::initialize();
        ContentRegistry::initialize();

        s_initialized = true;
        return true;
    }

    bool isInitialized() {
        return s_initialized;
    }

    // ── Hooking Engine ─────────────────────────────────────

    bool hookCFunction(const std::string &symbolName, void *replacement, void **original) {
        fishhook::rebinding reb = { symbolName.c_str(), replacement, original };
        return fishhook::rebindSymbols(&reb, 1) == 0;
    }

    bool hookObjCMethod(const std::string &className, const std::string &selectorName,
                        void *replacement, void **original) {
        return Hook_ObjCMethod(className.c_str(), selectorName.c_str(),
                               replacement, original);
    }

    bool hookObjCMethodExact(const std::string &className, const std::string &selectorName,
                              void *replacementBlock, void **original) {
        return Hook_ObjCMethodExact(className.c_str(), selectorName.c_str(),
                                    replacementBlock, original);
    }

    void *resolveSymbol(const std::string &mangledName) {
        return dlsym(RTLD_DEFAULT, mangledName.c_str());
    }

    uintptr_t scanPattern(const std::string &pattern) {
        (void)pattern;
        return 0;
    }

    // ── Minecraft-Specific Hooks ───────────────────────────

    bool hookGameFunctions() {
        if (!s_initialized) return false;

        auto cppSyms = MinecraftAPI::cppSymbolsForVersion(s_majorVersion);
        void *mcTick = resolveSymbol(cppSyms.minecraftTick);
        (void)mcTick;

        return true;
    }

    bool hookRenderLoop() {
        return s_initialized;
    }

    bool hookInput() {
        return s_initialized;
    }

    // ── Render / Frame Callbacks ───────────────────────────

    void onFrame(FrameCallback callback) {
        std::lock_guard<std::mutex> lock(s_mutex);
        Hooks_AddFrameCallback(std::move(callback));
    }

    void onTouch(TouchCallback callback) {
        std::lock_guard<std::mutex> lock(s_mutex);
        Hooks_AddTouchCallback(std::move(callback));
    }

    // ── Mod Loading ─────────────────────────────────────────

    static PreloaderAPI g_modAPI = {};

    static PreloaderAPI *getModAPI() {
        if (!g_modAPI.resolveSymbol) {
            g_modAPI.resolveSymbol = [](const char *name) -> void * {
                return dlsym(RTLD_DEFAULT, name);
            };
            g_modAPI.hookCFunction = [](const char *name, void *repl, void **orig) -> bool {
                return hookCFunction(name, repl, orig);
            };
            g_modAPI.hookObjCMethod = [](const char *clsName, const char *selName,
                                          void *repl, void **orig) -> bool {
                return hookObjCMethod(clsName, selName, repl, orig);
            };
            g_modAPI.hookInline = [](void *target, void *hook, void **original) -> bool {
                return InlineHook::install(target, hook, original);
            };
            g_modAPI.isInGame = Hooks_IsInGame;
            g_modAPI.minecraftVersion = []() -> const char * {
                return s_minecraftVersion.c_str();
            };
            g_modAPI.onFrame = [](void (*cb)(double)) {
                Hooks_AddFrameCallback(FrameCallback(cb));
            };
            g_modAPI.onTouch = [](void (*cb)(int, double, double)) {
                Hooks_AddTouchCallback(TouchCallback(cb));
            };
            g_modAPI.textureInitialize = []() -> bool {
                return TextureHook::initialize();
            };
            g_modAPI.textureOnLoad = [](bool (*cb)(const char *, bool, void *)) {
                TextureHook::onTextureLoad(
                    [cb](const std::string &path, bool bg, TextureHook::ImageData &img) -> bool {
                        return cb(path.c_str(), bg, (void *)&img);
                    }
                );
            };
            g_modAPI.renderOnBeforeFrame = [](void (*cb)()) {
                RenderHook::onBeforeFrame(RenderHook::DrawCallback(cb));
            };
            g_modAPI.renderOnFrame = [](void (*cb)(double)) {
                RenderHook::onFrame(RenderHook::FrameCallback(cb));
            };
            g_modAPI.uiOnViewDidLoad = [](void (*cb)(void *, void *)) {
                UIHook::onViewDidLoad(UIHook::ViewDidLoadCallback(cb));
            };
            // ── Content Registry ──────────────────────────
            g_modAPI.registryInit = []() -> bool {
                return ContentRegistry::initialize();
            };
            g_modAPI.registryRegister = [](const char *id, const char *name,
                                            int type, void *nativePtr) {
                ContentRegistry::registerContent(
                    id ? id : "", name ? name : "",
                    (ContentRegistry::RegistryType)type, nativePtr);
            };
            g_modAPI.registryHook = [](int type, void (*hook)(int, void *)) {
                ContentRegistry::onRegistryPopulate(
                    (ContentRegistry::RegistryType)type,
                    [hook](ContentRegistry::RegistryType t,
                           std::vector<ContentRegistry::ContentEntry> &) {
                        if (hook) hook((int)t, nullptr);
                    }
                );
            };
            // ── Dimension API ─────────────────────────────
            g_modAPI.dimensionInit = []() -> bool {
                return DimensionAPI::initialize();
            };
            g_modAPI.dimensionRegister = [](void (*provider)(void *)) {
                DimensionAPI::onRegisterDimensions(
                    [provider](std::vector<DimensionAPI::DimensionDefinition> &) {
                        if (provider) provider(nullptr);
                    }
                );
            };
            g_modAPI.dimensionPreCreate = [](void (*hook)(const char *, void *)) {
                if (hook) {
                    DimensionAPI::onPreCreateDimension(
                        [hook](const std::string &dimId,
                               DimensionAPI::DimensionDefinition &settings) {
                            hook(dimId.c_str(), (void *)&settings);
                        }
                    );
                }
            };
            // ── Block/Item API ────────────────────────────
            g_modAPI.blockItemInit = []() -> bool {
                return BlockItemAPI::initialize();
            };
            g_modAPI.blockRegister = [](void (*provider)(void *)) {
                BlockItemAPI::onRegisterBlocks(
                    [provider](std::vector<BlockItemAPI::BlockDefinition> &) {
                        if (provider) provider(nullptr);
                    }
                );
            };
            g_modAPI.itemRegister = [](void (*provider)(void *)) {
                BlockItemAPI::onRegisterItems(
                    [provider](std::vector<BlockItemAPI::ItemDefinition> &) {
                        if (provider) provider(nullptr);
                    }
                );
            };
        }
        return &g_modAPI;
    }

    bool loadMod(const std::string &modPath) {
        std::lock_guard<std::mutex> lock(s_mutex);
        if (!s_initialized) return false;

        for (const auto &mod : s_loadedMods) {
            if (mod.id == modPath) return true;
        }

        void *handle = dlopen(modPath.c_str(), RTLD_NOW | RTLD_LOCAL);
        if (!handle) return false;

        ModInfo info;
        info.id = modPath;
        info.enabled = true;

        auto nameFunc = reinterpret_cast<const char *(*)()>(dlsym(handle, "mod_name"));
        info.name = nameFunc ? nameFunc() : modPath.substr(modPath.find_last_of('/') + 1);

        auto versionFunc = reinterpret_cast<const char *(*)()>(dlsym(handle, "mod_version"));
        if (versionFunc) info.version = versionFunc();

        auto authorFunc = reinterpret_cast<const char *(*)()>(dlsym(handle, "mod_author"));
        if (authorFunc) info.author = authorFunc();

        auto initFunc = reinterpret_cast<void (*)(PreloaderAPI *)>(dlsym(handle, "mod_init"));
        if (initFunc) {
            initFunc(getModAPI());
        }

        s_loadedMods.push_back(info);
        s_modHandles[modPath] = handle;

        return true;
    }

    bool isModLoaded(const std::string &modId) {
        std::lock_guard<std::mutex> lock(s_mutex);
        for (const auto &mod : s_loadedMods) {
            if (mod.id == modId) return true;
        }
        return false;
    }

    std::vector<std::string> getLoadedMods() {
        std::lock_guard<std::mutex> lock(s_mutex);
        std::vector<std::string> result;
        result.reserve(s_loadedMods.size());
        for (const auto &mod : s_loadedMods) {
            result.push_back(mod.id);
        }
        return result;
    }

    size_t getModCount() {
        std::lock_guard<std::mutex> lock(s_mutex);
        return s_loadedMods.size();
    }

    std::string getModInfo(size_t index) {
        std::lock_guard<std::mutex> lock(s_mutex);
        if (index >= s_loadedMods.size()) return {};
        const auto &mod = s_loadedMods[index];
        return mod.id + "|" + mod.name + "|" + mod.version + "|" + mod.author;
    }

    // ── In-Game State ──────────────────────────────────────

    bool isInGame() {
        return Hooks_IsInGame();
    }

    bool isPauseMenuOpen() {
        return Hooks_IsPauseMenu();
    }

    // ── Utility ─────────────────────────────────────────────

    const char *minecraftVersion() {
        return s_minecraftVersion.c_str();
    }

} // namespace Preloader
