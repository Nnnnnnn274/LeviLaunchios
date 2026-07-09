#ifndef UIHOOK_H
#define UIHOOK_H

#include <functional>

namespace UIHook {

    // Called when the game view controller's viewDidLoad fires
    using ViewDidLoadCallback = std::function<void(void *viewController, void *view)>;

    // Initialize UI hooks
    bool initialize();

    // Register callback for when game view loads (add your UIKit overlay here)
    void onViewDidLoad(ViewDidLoadCallback callback);

    // Remove all callbacks
    void clearCallbacks();

} // namespace UIHook

#endif
