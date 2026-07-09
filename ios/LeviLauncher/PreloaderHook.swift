import Foundation
import UIKit

/// Hooks into Minecraft's ObjC runtime via the C++ preloader engine.
/// Called from LauncherEntry after initialization.
@objc class MinecraftHook: NSObject {
    static func install() {
        // Register frame callback for overlay updates
        LauncherBridge.onFrame { timestamp in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LeviLauncherFrameNotification"),
                    object: nil,
                    userInfo: ["timestamp": timestamp]
                )
            }
        }

        // Register touch callback for mod menu gesture detection
        LauncherBridge.onTouch { phase, x, y in
            if phase == 3 { // UITouchPhaseEnded
                NotificationCenter.default.post(
                    name: NSNotification.Name("LeviLauncherTouchNotification"),
                    object: nil,
                    userInfo: ["x": x, "y": y]
                )
            }
        }

        NSLog("[LeviLauncher] ObjC hooks installed via preloader engine")
    }

    /// Find the Minecraft game view controller by scanning the view hierarchy
    @objc static func findGameViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return nil }

        for window in windowScene.windows {
            if let rootVC = window.rootViewController {
                if let vc = findInChildVC(rootVC) {
                    return vc
                }
            }
        }
        return nil
    }

    private static func findInChildVC(_ vc: UIViewController) -> UIViewController? {
        let className = NSStringFromClass(type(of: vc))
        if className.contains("GameView") || className.contains("Minecraft") {
            return vc
        }
        for child in vc.children {
            if let found = findInChildVC(child) {
                return found
            }
        }
        return nil
    }
}
