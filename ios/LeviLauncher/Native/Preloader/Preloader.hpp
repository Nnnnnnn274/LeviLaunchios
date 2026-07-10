#ifndef PRELOADER_HPP
#define PRELOADER_HPP

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

// Source-compatible metadata layout for LeviLaunchroid-style C lifecycle
// mods rebuilt for iOS. JavaVM is represented as an opaque pointer on iOS.
extern "C" {
    struct PLModInfo {
        uint32_t size;
        const char *mod_id;
        const char *display_name;
        const char *author;
        const char *version;
        const char *entry_path;
        const char *entry_file_name;
        const char *library_path;
        const char *icon_path;
        const char *manifest_path;
        const char *mod_root_path;
    };

    typedef bool (*PLModLoadFunc)(void *javaVm, const PLModInfo *modInfo);
    typedef bool (*PLModLifecycleFunc)();
}

namespace Preloader {

    // ── API struct passed to mods (C-compatible!) ───────────

    struct PreloaderAPI {
        void *(*resolveSymbol)(const char *symbolName);
        bool (*hookCFunction)(const char *symbolName, void *replacement, void **original);
        bool (*hookObjCMethod)(const char *className, const char *selectorName,
                               void *replacement, void **original);
        bool (*hookInline)(void *target, void *hook, void **original);
        bool (*isInGame)();
        void (*onFrame)(void (*callback)(double));
        void (*onTouch)(void (*callback)(int, double, double));
        const char *(*minecraftVersion)();
        bool (*textureInitialize)();
        void (*textureOnLoad)(bool (*callback)(const char *path, bool preferBgra, void *imageData));
        void (*renderOnBeforeFrame)(void (*callback)());
        void (*renderOnFrame)(void (*callback)(double));
        void (*uiOnViewDidLoad)(void (*callback)(void *viewController, void *view));
        // ── Content Registry ──────────────────────────────
        bool (*registryInit)();
        void (*registryRegister)(const char *id, const char *name, int type, void *nativePtr);
        void (*registryHook)(int type, void (*hook)(int, void *));
        // ── Dimension API ─────────────────────────────────
        bool (*dimensionInit)();
        void (*dimensionRegister)(void (*provider)(void *));
        void (*dimensionPreCreate)(void (*hook)(const char *, void *));
        // ── Block/Item API ────────────────────────────────
        bool (*blockItemInit)();
        void (*blockRegister)(void (*provider)(void *));
        void (*itemRegister)(void (*provider)(void *));
    };

    // ── Mod info ────────────────────────────────────────────

    struct ModInfo {
        std::string id;
        std::string name;
        std::string version;
        std::string author;
        bool enabled;
    };

    // ── Lifecycle ────────────────────────────────────────────

    bool initialize(const std::string &gamePath);
    bool isInitialized();

    // ── Hooking Engine ───────────────────────────────────────

    bool hookCFunction(const std::string &symbolName, void *replacement, void **original);
    bool hookObjCMethod(const std::string &className, const std::string &selectorName,
                        void *replacement, void **original);
    bool hookObjCMethodExact(const std::string &className, const std::string &selectorName,
                              void *replacementBlock, void **original);
    void *resolveSymbol(const std::string &mangledName);
    uintptr_t scanPattern(const std::string &pattern);

    // ── Minecraft-Specific Hooks ────────────────────────────

    bool hookGameFunctions();
    bool hookRenderLoop();
    bool hookInput();

    // ── Render / Frame Callbacks ────────────────────────────

    using FrameCallback = std::function<void(double timestamp)>;
    using TouchCallback = std::function<void(int phase, double x, double y)>;

    void onFrame(FrameCallback callback);
    void onTouch(TouchCallback callback);

    // ── Mod Loading ─────────────────────────────────────────

    bool loadMod(const std::string &modPath);
    bool isModLoaded(const std::string &modId);
    std::vector<std::string> getLoadedMods();
    size_t getModCount();
    std::string getModInfo(size_t index);

    // ── In-Game State ──────────────────────────────────────

    bool isInGame();
    bool isPauseMenuOpen();

    // ── Utility ─────────────────────────────────────────────

    const char *minecraftVersion();

} // namespace Preloader

#endif // PRELOADER_HPP
