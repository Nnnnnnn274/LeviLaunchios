import Foundation
import UIKit

@objc public class LauncherEntry: NSObject {
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
        LauncherBridge.onViewDidLoad { [weak self] (vcPtr, viewPtr) in
            guard let self = self else { return }
            let gameView = Unmanaged<UIView>.fromOpaque(viewPtr).takeUnretainedValue()
            let gameVC = Unmanaged<UIViewController>.fromOpaque(vcPtr).takeUnretainedValue()
            self.gameViewController = gameVC

            let button = UIButton(type: .custom)
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
            button.setImage(UIImage(systemName: "leaf.fill", withConfiguration: config), for: .normal)
            button.tintColor = .systemGreen
            button.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
            button.layer.cornerRadius = 28
            button.layer.masksToBounds = true
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.systemGreen.cgColor
            button.translatesAutoresizingMaskIntoConstraints = false

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleButtonPan(_:)))
            button.addGestureRecognizer(pan)
            button.addTarget(self, action: #selector(showMenu), for: .touchUpInside)

            gameView.addSubview(button)

            NSLayoutConstraint.activate([
                button.trailingAnchor.constraint(equalTo: gameView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                button.topAnchor.constraint(equalTo: gameView.safeAreaLayoutGuide.topAnchor, constant: 60),
                button.widthAnchor.constraint(equalToConstant: 56),
                button.heightAnchor.constraint(equalToConstant: 56)
            ])

            self.floatingButton = button
        }
    }

    @objc private func showMenu() {
        guard let gameVC = gameViewController else { return }
        let menuVC = ModMenuViewController()
        menuVC.modalPresentationStyle = .overFullScreen
        gameVC.present(menuVC, animated: true)
    }

    @objc private func handleButtonPan(_ gesture: UIPanGestureRecognizer) {
        guard let button = floatingButton else { return }
        let translation = gesture.translation(in: button.superview)
        button.center = CGPoint(
            x: button.center.x + translation.x,
            y: button.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: button.superview)
    }

    private func loadAccounts() {
        let accounts = MsftAccountStore.list()
        NSLog("[LeviLauncher] Found \(accounts.count) account(s)")
    }
}
