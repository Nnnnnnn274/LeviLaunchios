import Foundation
import UIKit

// Hooks into Minecraft's ObjC runtime to intercept rendering
@objc class MinecraftHook: NSObject {
    static func swizzle() {
        // Hook Minecraft's main render loop to inject overlay
        // This uses ObjC runtime method swizzling
        guard let originalClass = NSClassFromString("MinecraftViewController") else {
            NSLog("[LeviLauncher] MinecraftViewController not found - swizzle deferred")
            return
        }

        // Swizzle viewDidAppear to inject our overlay
        let originalSelector = NSSelectorFromString("viewDidAppear:")
        let swizzledSelector = #selector(swizzled_viewDidAppear(_:))

        guard let originalMethod = class_getInstanceMethod(originalClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(MinecraftHook.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        NSLog("[LeviLauncher] Swizzled MinecraftViewController.viewDidAppear:")
    }

    @objc func swizzled_viewDidAppear(_ animated: Bool) {
        // Call original (now our swizzled method)
        _ = self.perform(#selector(swizzled_viewDidAppear(_:)), with: animated)

        // Present LeviLauncher overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            LauncherEntry.shared.initialize()
        }
    }
}
