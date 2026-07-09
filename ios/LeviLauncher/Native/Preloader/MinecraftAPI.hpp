#ifndef MINECRAFT_API_HPP
#define MINECRAFT_API_HPP

#include <cstdint>
#include <string>
#include <unordered_map>

// ── Version-specific definitions for Minecraft iOS ──────────
// Minecraft Bedrock 26.32 (newest), also 26.20, etc.

namespace MinecraftAPI {

    // ── ObjC class names (version-specific) ──────────────────

    struct ObjCClasses {
        // Primary game controller
        const char *gameViewController;
        // Screen / UI manager
        const char *screenManager;
        // Game instance
        const char *gameInstance;
        // Level instance
        const char *level;
        // Player instance
        const char *localPlayer;
        // Input handler
        const char *inputHandler;
        // Renderer / Metal view
        const char *renderView;
        // Options / settings
        const char *options;
    };

    // ── ObjC selector names (generally stable) ───────────────

    struct ObjCSelectors {
        const char *viewDidAppear;
        const char *viewDidDisappear;
        const char *viewDidLoad;
        const char *drawInMTKView;
        const char *mtkViewDrawableSizeWillChange;
        const char *touchesBegan;
        const char *touchesMoved;
        const char *touchesEnded;
        const char *sendEvent;
        const char *applicationDidFinishLaunching;
    };

    // ── C function symbols (via dlsym) ───────────────────────

    struct CSymbols {
        const char *uiApplicationMain;
        const char *machAbsoluteTime;
        const char *objcMsgSend;
    };

    // ── C++ mangled symbols (via dlsym, version-specific) ───

    struct CppSymbols {
        const char *minecraftTick;     // Minecraft::tick
        const char *levelTick;         // Level::tick
        const char *gameModeTick;      // GameMode::tick
        const char *playerTick;        // Player::tick
        const char *renderFrame;       // ScreenRenderer::render or similar
        const char *fovUpdate;         // FOV modifier function
        const char *getServer;         // Minecraft::getServer()
    };

    // ── 26.32 defaults ──────────────────────────────────────
    // These MUST be verified with class-dump / nm on the actual binary

    inline ObjCClasses classesFor26_32() {
        return {
            .gameViewController   = "MCGameViewController",
            .screenManager        = "MCScreenManager",
            .gameInstance         = "MCGame",
            .level                = "MCLevel",
            .localPlayer          = "MCLocalPlayer",
            .inputHandler         = "MCInputHandler",
            .renderView           = "MCRenderView",
            .options              = "MCOptions",
        };
    }

    inline ObjCSelectors selectors() {
        return {
            .viewDidAppear                  = "viewDidAppear:",
            .viewDidDisappear               = "viewDidDisappear:",
            .viewDidLoad                    = "viewDidLoad",
            .drawInMTKView                  = "drawInMTKView:",
            .mtkViewDrawableSizeWillChange  = "mtkView:drawableSizeWillChange:",
            .touchesBegan                   = "touchesBegan:withEvent:",
            .touchesMoved                   = "touchesMoved:withEvent:",
            .touchesEnded                   = "touchesEnded:withEvent:",
            .sendEvent                      = "sendEvent:",
            .applicationDidFinishLaunching  = "applicationDidFinishLaunching:",
        };
    }

    inline CSymbols cSymbols() {
        return {
            .uiApplicationMain  = "UIApplicationMain",
            .machAbsoluteTime   = "mach_absolute_time",
            .objcMsgSend        = "objc_msgSend",
        };
    }

    // C++ mangled names for 26.32 (Itanium ABI, arm64)
    // These need verification against the actual binary
    inline CppSymbols cppSymbolsFor26_32() {
        return {
            .minecraftTick    = "_ZN6Minecraft4tickEv",
            .levelTick        = "_ZN5Level4tickEv",
            .gameModeTick     = "_ZN8GameMode4tickEv",
            .playerTick       = "_ZN6Player4tickEv",
            .renderFrame      = "_ZN14ScreenRenderer6renderERK7Ticking",
            .fovUpdate        = "_ZN12FovModifier6updateEv",
            .getServer        = "_ZN6Minecraft9getServerEv",
        };
    }

    // ── Version detection ────────────────────────────────────

    // Map CFBundleShortVersionString → version number
    inline int detectVersion(const std::string &versionStr) {
        // e.g. "26.32" → major=26
        auto dot = versionStr.find('.');
        if (dot != std::string::npos) {
            return std::stoi(versionStr.substr(0, dot));
        }
        return std::stoi(versionStr);
    }

    inline ObjCClasses classesForVersion(int ver) {
        switch (ver) {
            default: return classesFor26_32();
        }
    }

    inline CppSymbols cppSymbolsForVersion(int ver) {
        switch (ver) {
            default: return cppSymbolsFor26_32();
        }
    }

} // namespace MinecraftAPI

#endif // MINECRAFT_API_HPP
