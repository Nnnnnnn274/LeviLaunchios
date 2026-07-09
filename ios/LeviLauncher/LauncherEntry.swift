import Foundation
import UIKit

@objc(LauncherEntry) public class LauncherEntry: NSObject {
    @objc public static let shared = LauncherEntry()

    private var isInitialized = false
    private var floatingButton: UIButton?
    private weak var gameViewController: UIViewController?

    private override init() {}

    @objc public func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        DispatchQueue.main.async {
            self.initPreloader()
            self.registerUIHook()
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

    private func registerUIHook() {
        // Register the viewDidLoad hook callback
        LauncherBridge.onViewDidLoad { [weak self] (vcPtr, viewPtr) in
            guard let self = self else { return }
            self.addFloatingButton(vcPtr: vcPtr, viewPtr: viewPtr)
        }

        // Periodic fallback scan: try to find the game VC every 2s for 30s
        scanForGameVC(attempts: 0)
    }

    private func scanForGameVC(attempts: Int) {
        guard floatingButton == nil else { return }
        if attempts >= 15 { return } // stop after ~30s

        if LauncherBridge.injectOverlayNow() {
            NSLog("[LeviLauncher] Fallback overlay injection succeeded (attempt \(attempts))")
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.scanForGameVC(attempts: attempts + 1)
            }
        }
    }

    private func addFloatingButton(vcPtr: UnsafeMutableRawPointer, viewPtr: UnsafeMutableRawPointer) {
        let gameView = Unmanaged<UIView>.fromOpaque(viewPtr).takeUnretainedValue()
        let gameVC = Unmanaged<UIViewController>.fromOpaque(vcPtr).takeUnretainedValue()
        self.gameViewController = gameVC

        // Minecraft-style button
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Stone-like background
        button.backgroundColor = UIColor(red: 0.45, green: 0.45, blue: 0.47, alpha: 0.9)
        button.layer.cornerRadius = 4
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1).cgColor

        // Inner highlight for 3D effect
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.5
        button.layer.shadowRadius = 0

        // Content: pickaxe + "M" text
        var config = UIButton.Configuration.plain()
        config.title = "Levi"
        config.image = UIImage(systemName: "hammer.fill")
        config.imagePadding = 6
        config.baseForegroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        button.configuration = config
        button.titleLabel?.font = .boldSystemFont(ofSize: 13)

        button.addTarget(self, action: #selector(showMenu), for: .touchUpInside)

        gameView.addSubview(button)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: gameView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            button.topAnchor.constraint(equalTo: gameView.safeAreaLayoutGuide.topAnchor, constant: 8),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            button.heightAnchor.constraint(equalToConstant: 36),
        ])

        self.floatingButton = button
    }

    @objc private func showMenu() {
        NSLog("[LeviLauncher] showMenu called")
        guard let gameVC = gameViewController else {
            NSLog("[LeviLauncher] gameVC is nil, trying fallback")
            if LauncherBridge.injectOverlayNow() {
                NSLog("[LeviLauncher] fallback injection succeeded, re-trying showMenu in 0.5s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showMenu()
                }
            }
            return
        }
        // Dismiss any already-presented VC first
        if gameVC.presentedViewController != nil {
            NSLog("[LeviLauncher] dismissing existing presented VC")
            gameVC.dismiss(animated: false)
        }
        // Find the topmost presented VC to present from
        var topVC: UIViewController = gameVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        if topVC != gameVC {
            NSLog("[LeviLauncher] presenting from topmost VC instead of gameVC")
        }
        let menuVC = ModMenuViewController()
        menuVC.modalPresentationStyle = .overFullScreen
        NSLog("[LeviLauncher] about to present ModMenuViewController")
        topVC.present(menuVC, animated: true)
        NSLog("[LeviLauncher] present returned")
    }

    private func loadAccounts() {
        let accounts = MsftAccountStore.list()
        NSLog("[LeviLauncher] Found \(accounts.count) account(s)")
    }
}
