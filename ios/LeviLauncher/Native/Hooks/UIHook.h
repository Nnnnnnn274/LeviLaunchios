#ifndef UIHOOK_H
#define UIHOOK_H

#include <functional>

namespace UIHook {

    // Called when the game view controller's viewDidLoad fires
    using ViewDidLoadCallback = std::function<void(void *viewController, void *view)>;

    // Initialize UI hooks (returns false if no game VC class found)
    bool initialize();

    // Register callback for when game view loads (add your UIKit overlay here)
    void onViewDidLoad(ViewDidLoadCallback callback);

    // Remove all callbacks
    void clearCallbacks();

    // Scan the window hierarchy for the game's main view controller.
    // Returns the first UIViewController whose className contains any known
    // Minecraft game-view-controller substring, or nullptr.
    void *findGameViewController();

    // Add the overlay as a subview of a known game VC immediately.
    // Used as a fallback when the viewDidLoad hook doesn't fire.
    void injectOverlayNow(void *viewController, void *view);

} // namespace UIHook

#endif
