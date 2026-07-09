#ifndef HOOKS_H
#define HOOKS_H

#include <stdbool.h>

#ifdef __cplusplus
#include <functional>
namespace Preloader {
    using FrameCallback = std::function<void(double timestamp)>;
    using TouchCallback = std::function<void(int phase, double x, double y)>;
}
extern "C" {
#endif

// Initialize all ObjC runtime hooks
void Hooks_Initialize(void);

// ObjC method hooking (C-compatible wrappers)
bool Hook_ObjCMethod(const char *className, const char *selectorName,
                     void *replacement, void **original);
bool Hook_ObjCMethodExact(const char *className, const char *selectorName,
                          void *replacementBlock, void **original);

// Register frame callback (called from CADisplayLink)
void Hooks_AddFrameCallback_C(void (*callback)(double timestamp));

// Register touch callback (called from UIApplication sendEvent:)
void Hooks_AddTouchCallback_C(void (*callback)(int phase, double x, double y));

// Query game state
bool Hooks_IsInGame(void);
bool Hooks_IsPauseMenu(void);

#ifdef __cplusplus
}

// C++ overloads for std::function callbacks
void Hooks_AddFrameCallback(Preloader::FrameCallback callback);
void Hooks_AddTouchCallback(Preloader::TouchCallback callback);

#endif

#endif // HOOKS_H
