import Foundation

@objc(LauncherEntry) public class LauncherEntry: NSObject {
    @objc public static let shared = LauncherEntry()

    private var isInitialized = false

    private override init() {}

    @objc public func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        DispatchQueue.main.async {
            self.initPreloader()
            let modFailures = NativeModManager.shared.loadEnabledMods()
            if !modFailures.isEmpty {
                NSLog("[LeviLauncher] Native mod load failures: \(modFailures.joined(separator: ", "))")
            }
            ResourcePackManager.shared.applyTextureOverrides()
            self.startNativeUIFallbackScan(attempts: 0)
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

    private func startNativeUIFallbackScan(attempts: Int) {
        if attempts >= 15 { return }

        if LauncherBridge.injectOverlayNow() {
            NSLog("[LeviLauncher] Native C++ UI injection succeeded (attempt \(attempts))")
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startNativeUIFallbackScan(attempts: attempts + 1)
            }
        }
    }

    private func loadAccounts() {
        let accounts = MsftAccountStore.list()
        NSLog("[LeviLauncher] Found \(accounts.count) account(s)")
    }
}
