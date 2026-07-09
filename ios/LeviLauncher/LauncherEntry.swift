import Foundation
import UIKit

@objc public class LauncherEntry: NSObject {
    @objc public static let shared = LauncherEntry()

    private var isInitialized = false
    private var overlayWindow: UIWindow?

    private override init() {}

    @objc public func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        DispatchQueue.main.async {
            self.initPreloader()
            self.setupOverlay()
            self.loadAccounts()
        }
    }

    private func initPreloader() {
        let bundlePath = Bundle.main.bundlePath
        let result = LauncherBridge.initializePreloader(bundlePath)
        if result {
            NSLog("[LeviLauncher] Preloader initialized for Minecraft \(LauncherBridge.minecraftVersion())")
            MinecraftHook.install()
        } else {
            NSLog("[LeviLauncher] Preloader initialization failed")
        }
    }

    private func setupOverlay() {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }

        let overlayVC = ModMenuViewController()
        overlayVC.modalPresentationStyle = .overFullScreen

        overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow?.rootViewController = overlayVC
        overlayWindow?.windowLevel = .alert + 100
        overlayWindow?.isHidden = false
    }

    private func loadAccounts() {
        let accounts = MsftAccountStore.list()
        NSLog("[LeviLauncher] Found \(accounts.count) account(s)")
    }
}
