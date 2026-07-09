# AGENTS.md — LeviLaunchios

## Goal
- Port LeviLauncher (Android Minecraft Bedrock launcher) to iOS as a fully-featured modloader dylib injected into Minecraft.app, supporting texture packs, custom UI, dimensions, blocks, and items

## Constraints & Preferences
- Must work with Minecraft iOS **26.32** (SDK 26.5 on CI)
- Full modloader (not just a launcher) with content registration (dimensions, blocks, items, entities, etc.)
- C++ for native hook engine + Swift for business logic and UI
- In-game UIKit overlay, no standalone app process
- Build `.dylib` only — injection is done externally by user via Azule + SideStore
- Release must contain the dylib zip, not source code
- SideStore / non-jailbroken workflow (TrollStore optional)
- ObjC hooking (`method_setImplementation`) and fishhook work **without JIT** — only InlineHook (ARM64 branch-patching) needs `vm_protect(PROT_EXEC)`

## Progress
### Done
- Complete rewrite of iOS preloader hooking engine (Fishhook.hpp, Hooks.h/mm, MinecraftAPI.hpp, Preloader.cpp)
- **All Swift compilation errors fixed** (down from hundreds to zero): iOS 15.0 deployment, SWIFT_VERSION 5.0, fixed URLSession tuples, SecKey, NBT nil handling, exclusivity violations, missing imports (Combine, ImageIO), etc.
- **All C++ compilation errors fixed**: `#include <mach-o/nlist.h>` in Fishhook.hpp, removed duplicate `PreloaderAPI`
- **ARM64 inline hook engine** (`InlineHook.h/cpp`): `vm_protect` + branch-patching
- **TextureHook**: hooks `AppPlatform::loadImage` via inline hook + dlsym
- **RenderHook**: hooks `minecraftpeViewController drawFrame` via IMP replace — per-frame before/after callbacks
- **UIHook**: hooks `minecraftpeViewController viewDidLoad` via IMP replace — inject UIKit views into game VC (ARC `__bridge` cast fixed)
- **ContentRegistry**: generic content registration for blocks, items, dimensions, entities, biomes
- **DimensionAPI**: hooks `Level::registerDimension` (estimated symbol)
- **BlockItemAPI**: hooks `Block::initBlocks` / `Item::initItems` (estimated symbols)
- **PreloaderAPI** extended: 20+ functions — `hookInline`, `textureOnLoad`, `renderOnBeforeFrame`, `renderOnFrame`, `uiOnViewDidLoad`, `registryRegister`, `dimensionRegister`, `blockRegister`, `itemRegister`, etc.
- **CI** (`buildipa.yml`): `macos-latest`, auto-detects Xcode, `BUILD_DIR` deterministic, `gh release create` with auto-tags, uploads dylib zip
- **CI passes compile** for all Swift, C++, ObjC files — **last run: BUILD SUCCEEDED** (commit `bdba95e`)
- **Fixed include paths** in `Preloader.cpp`: `"../Hooks/..."` instead of `"Native/Hooks/..."`
- **Removed JIT guard** in `EntryPoint.m`: polls for `LauncherEntry` class (Swift runtime ready) instead of `vm_protect(PROT_EXEC)` — ObjC hooks and fishhook work without JIT
- **Replaced separate UIWindow overlay** with UIHook viewDidLoad callback + subview injection into game VC
- **Added `LauncherBridge.onViewDidLoad`** bridging C++ UIHook → Swift
- **Added VC class name fallbacks** (6 names) and view hierarchy scanning (`findGameViewController`) in UIHook
- **Added periodic fallback scan** in Swift (2s × 15 attempts) if viewDidLoad hook doesn't fire
- **Replaced `dispatch_async`** with `CFRunLoopPerformBlock` + `CFRunLoopWakeUp` for reliable scheduling at load time
- **Added file-based diagnostic logging** (`Documents/levilauncher.log`) to `EntryPoint.m`
- **Added `injectOverlayNow`** method to UIHook for post-hoc overlay injection via window hierarchy scan
- **Fixed `LauncherBridge.mm`** — added `#import <UIKit/UIKit.h>` for `UIView` type used by `injectOverlayNow`
- All changes committed and pushed to `main`

### Blocked
- All C++ symbol names for registration hooks are guessed from patterns — need fresh class-dump of Minecraft iOS 26.32 to verify real mangled symbols
- No device testing yet with injected dylib against actual Minecraft 26.32 binary

## Key Decisions
- **InlineHook** uses `vm_protect` + single-instruction patch + 2-instruction trampoline — simpler/faster than full MSHookFunction disassembly, but may fail on functions starting with PC-relative instructions (ADRP/ADR)
- **Content registration hooks use estimated symbols** — `Block::initBlocks`, `Item::initItems`, `Level::registerDimension` are educated guesses; will need updating once real 26.32 symbols are confirmed
- **ObjC hooks via `method_setImplementation`** (not swizzle) — RenderHook and UIHook directly replace IMP, simpler than swizzling, preserves original selector
- **Removed JIT guard**: `EntryPoint.m` no longer polls for `vm_protect(PROT_EXEC)` — only InlineHook (ARM64 patching) needs JIT; ObjC hooks work on non-jailbroken devices
- **UI overlay via subview, not separate window**: `ModMenuViewController` is presented modally from the game VC via UIHook callback, not via a separate `UIWindow` with `windowLevel = .alert + 100`
- **Release contains dylib zip, not source code**
- **All new files in `Native/Hooks/`** — separate from Preloader layer, initialized in `Preloader::initialize()`

## Next Steps
1. Get fresh class-dump of Minecraft iOS 26.32 binary to verify all C++ symbol names for ContentRegistry/DimensionAPI/BlockItemAPI hooks
2. Add packet hooking (RakNet) for network-level modding
3. Test on device with injected dylib against actual Minecraft 26.32

## Critical Context
- Build 26.32 = Minecraft Bedrock **26**; CI SDK is **iphoneos26.5**
- Current ObjC class names from MCPE iOS dump: `minecraftpeViewController`, `minecraftpeAppDelegate`, `EAGLView`
- C++ symbols (`AppPlatform::loadImage`, `App::draw`, etc.) are from an older MCPE dump — may differ in 26.32
- On load, `EntryPoint.m` constructor runs `CFRunLoopPerformBlock` → `try_init()` polls `objc_getClass("LauncherEntry")` every 0.5s → when found, calls `[LauncherEntry.shared initialize]` → preloader + all hooks go live
- Diagnostic log written to `Documents/levilauncher.log` at each key step
- UIHook callback fires when game VC's `viewDidLoad` runs; fallback scanning every 2s for 30s if hook misses
- **CI is green** — all Swift, C++, ObjC files compile without errors

## Relevant Files
- `ios/LeviLauncher/Native/Bridge/LauncherBridge.mm`: bridges C++ hooks → Swift; now includes UIKit for UIView
- `ios/LeviLauncher/Native/Hooks/UIHook.h/mm`: 6 VC class name fallbacks, `findGameViewController`, `injectOverlayNow`, view hierarchy scanner (scene + classic windows)
- `ios/LeviLauncher/EntryPoint.m`: JIT-safe entry point — polls for `LauncherEntry` class (not JIT), writes `Documents/levilauncher.log`, uses `CFRunLoopPerformBlock`
- `ios/LeviLauncher/LauncherEntry.swift`: registers UIHook viewDidLoad callback + periodic scanning fallback (2s × 15 attempts)
- `ios/LeviLauncher/Native/Bridge/LauncherBridge.h`: added `onViewDidLoad:` and `injectOverlayNow`
- `ios/project.yml`: XcodeGen spec — iOS 15.0, SWIFT_VERSION 5.0, sources auto-pick up `Native/Hooks/`
- `ios/LeviLauncher/Native/Preloader/Preloader.cpp`: initializes all hooks; relative include paths `"../Hooks/..."`
- `ios/LeviLauncher/UI/ModMenuViewController.swift`: simplified for modal presentation (no self-contained floating button)
- `ios/LeviLauncher/Native/Preloader/Preloader.hpp` + `MinecraftAPI.hpp`: version-specific class names and C++ mangled symbol guesses
- `ios/LeviLauncher/Native/Preloader/Hooks.h/mm`: ObjC swizzles — sendEvent, lifecycle, CADisplayLink frame callbacks
- `.github/workflows/buildipa.yml`: BUILD_DIR deterministic, `gh release create` with auto-tag, uploads dylib zip
