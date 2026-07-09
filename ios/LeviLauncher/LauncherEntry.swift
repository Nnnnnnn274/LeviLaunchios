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

        NSLog("[LeviLauncher] Swift initialization started")

        // Listen for the ObjC constructor notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInitialization),
            name: NSNotification.Name("LeviLauncherInitializationNotification"),
            object: nil
        )
    }

    @objc private func handleInitialization() {
        NSLog("[LeviLauncher] Initializing LeviLauncher inside Minecraft...")

        DispatchQueue.main.async {
            self.setupOverlay()
            self.loadAccounts()
            self.setupMinecraftHooks()
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
        overlayWindow?.makeKeyAndVisible()
    }

    private func loadAccounts() {
        let accounts = MsftAccountStore.list()
        NSLog("[LeviLauncher] Found \(accounts.count) account(s)")
    }

    private func setupMinecraftHooks() {
        // Hook into Minecraft rendering to display overlay
        // This uses C++ preloader hooks via LauncherBridge
    }
}

// Called from ObjC constructor
extension NSObject {
    @objc static func leviLauncherModuleInit() {
        LauncherEntry.shared.initialize()
    }
}
