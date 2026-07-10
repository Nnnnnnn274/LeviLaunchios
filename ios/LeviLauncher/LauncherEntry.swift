import Foundation
import UIKit

@objc(LauncherEntry) public class LauncherEntry: NSObject {
    @objc public static let shared = LauncherEntry()

    private var isInitialized = false
    private var floatingButton: UIButton?
    private weak var gameViewController: UIViewController?
    private weak var menuViewController: ModMenuViewController?

    private override init() {}

    @objc public func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        DispatchQueue.main.async {
            self.initPreloader()
            BuiltinModManager.shared.loadPersistedState()
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
        // The fallback scanner and the viewDidLoad hook can both arrive.  Keep a
        // single, small control in the game view rather than stacking overlays.
        guard floatingButton == nil else { return }

        let gameView = Unmanaged<UIView>.fromOpaque(viewPtr).takeUnretainedValue()
        let gameVC = Unmanaged<UIViewController>.fromOpaque(vcPtr).takeUnretainedValue()
        self.gameViewController = gameVC

        // A compact floating action button.  Its fixed bounds ensure only this
        // visible button intercepts touches; the rest of Minecraft stays usable.
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Open LeviLauncher menu"
        button.accessibilityHint = "Opens the LeviLauncher mod menu"

        // Stone-like background
        button.backgroundColor = UIColor(red: 0.45, green: 0.45, blue: 0.47, alpha: 0.9)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1).cgColor

        // Inner highlight for 3D effect
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.5
        button.layer.shadowRadius = 0

        // Content: a recognisable compact launcher icon.
        button.tintColor = UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1)
        button.setImage(UIImage(systemName: "hammer.fill"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.contentEdgeInsets = UIEdgeInsets(top: 11, left: 11, bottom: 11, right: 11)

        button.addTarget(self, action: #selector(showMenu), for: .touchUpInside)

        gameView.addSubview(button)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: gameView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            button.topAnchor.constraint(equalTo: gameView.safeAreaLayoutGuide.topAnchor, constant: 8),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])

        self.floatingButton = button
    }

    @objc private func showMenu() {
        NSLog("[LeviLauncher] showMenu called")
        guard menuViewController == nil else {
            NSLog("[LeviLauncher] menu is already visible")
            return
        }
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

        // Present above any Minecraft sheet already on screen. Dismissing an
        // existing controller here can interrupt Minecraft's own UI transition.
        var topVC: UIViewController = gameVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let menuVC = ModMenuViewController()
        menuVC.modalPresentationStyle = .overFullScreen
        menuVC.modalTransitionStyle = .crossDissolve
        menuViewController = menuVC
        NSLog("[LeviLauncher] about to present ModMenuViewController")
        topVC.present(menuVC, animated: true) { [weak self, weak menuVC] in
            // If UIKit refuses the presentation, let the launcher button retry.
            if menuVC?.presentingViewController == nil {
                self?.menuViewController = nil
            }
        }
        NSLog("[LeviLauncher] present returned")
    }

    private func loadAccounts() {
        let accounts = MsftAccountStore.list()
        NSLog("[LeviLauncher] Found \(accounts.count) account(s)")
    }
}
