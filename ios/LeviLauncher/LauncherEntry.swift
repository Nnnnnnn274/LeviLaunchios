import Foundation
import UIKit

@objc(LauncherEntry) public class LauncherEntry: NSObject, UIDocumentPickerDelegate {
    @objc public static let shared = LauncherEntry()

    private var isInitialized = false
    private var floatingButton: UIButton?
    private var floatingContainer: UIView?
    private var minusButton: UIButton?
    private var plusButton: UIButton?
    private var isMinimized = false
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

        let size: CGFloat = 56
        let subSize: CGFloat = 22

        // Container to hold all buttons (clips for minimize animation)
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = false
        gameView.addSubview(container)

        // Leaf button (opens menu)
        let leaf = UIButton(type: .custom)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        leaf.setImage(UIImage(systemName: "leaf.fill", withConfiguration: config), for: .normal)
        leaf.tintColor = .systemGreen
        leaf.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        leaf.layer.cornerRadius = size / 2
        leaf.layer.borderWidth = 2
        leaf.layer.borderColor = UIColor.systemGreen.cgColor
        leaf.translatesAutoresizingMaskIntoConstraints = false
        leaf.addTarget(self, action: #selector(showMenu), for: .touchUpInside)
        container.addSubview(leaf)

        // Minus button (minimize)
        let minus = UIButton(type: .system)
        minus.setTitle("−", for: .normal)
        minus.titleLabel?.font = .boldSystemFont(ofSize: 14)
        minus.tintColor = .white
        minus.backgroundColor = .systemRed
        minus.layer.cornerRadius = subSize / 2
        minus.translatesAutoresizingMaskIntoConstraints = false
        minus.addTarget(self, action: #selector(toggleMinimize), for: .touchUpInside)
        container.addSubview(minus)

        // Plus button (add mod)
        let plus = UIButton(type: .system)
        plus.setTitle("+", for: .normal)
        plus.titleLabel?.font = .boldSystemFont(ofSize: 16)
        plus.tintColor = .white
        plus.backgroundColor = .systemBlue
        plus.layer.cornerRadius = subSize / 2
        plus.translatesAutoresizingMaskIntoConstraints = false
        plus.addTarget(self, action: #selector(addMod), for: .touchUpInside)
        container.addSubview(plus)

        // Pan gesture on container
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleContainerPan(_:)))
        container.addGestureRecognizer(pan)

        NSLayoutConstraint.activate([
            container.trailingAnchor.constraint(equalTo: gameView.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            container.topAnchor.constraint(equalTo: gameView.safeAreaLayoutGuide.topAnchor, constant: 60),
            container.widthAnchor.constraint(equalToConstant: size + subSize),
            container.heightAnchor.constraint(equalToConstant: size + subSize),

            leaf.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: subSize / 2),
            leaf.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: subSize / 2),
            leaf.widthAnchor.constraint(equalToConstant: size),
            leaf.heightAnchor.constraint(equalToConstant: size),

            minus.centerXAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            minus.centerYAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            minus.widthAnchor.constraint(equalToConstant: subSize),
            minus.heightAnchor.constraint(equalToConstant: subSize),

            plus.centerXAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            plus.centerYAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            plus.widthAnchor.constraint(equalToConstant: subSize),
            plus.heightAnchor.constraint(equalToConstant: subSize),
        ])

        self.floatingContainer = container
        self.floatingButton = leaf
        self.minusButton = minus
        self.plusButton = plus
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

    @objc private func toggleMinimize() {
        guard let container = floatingContainer else { return }
        isMinimized.toggle()

        if isMinimized {
            minusButton?.isHidden = true
            plusButton?.isHidden = true
            UIView.animate(withDuration: 0.2) {
                container.transform = CGAffineTransform(scaleX: 0.35, y: 0.35)
                container.alpha = 0.6
            }
        } else {
            UIView.animate(withDuration: 0.2) {
                container.transform = .identity
                container.alpha = 1
            } completion: { _ in
                self.minusButton?.isHidden = false
                self.plusButton?.isHidden = false
            }
        }
    }

    @objc private func addMod() {
        guard let gameVC = gameViewController else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        gameVC.topMostPresented.present(picker, animated: true)
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let modsDir = LauncherStorage.minecraftRoot.appendingPathComponent("mods")
        try? FileManager.default.createDirectory(at: modsDir, withIntermediateDirectories: true)
        for url in urls {
            let dest = modsDir.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dest)
            NSLog("[LeviLauncher] Copied mod: \(url.lastPathComponent)")
        }
    }

    @objc private func handleContainerPan(_ gesture: UIPanGestureRecognizer) {
        guard let container = floatingContainer else { return }
        let translation = gesture.translation(in: container.superview)
        container.center = CGPoint(
            x: container.center.x + translation.x,
            y: container.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: container.superview)
    }

    private func loadAccounts() {
        let accounts = MsftAccountStore.list()
        NSLog("[LeviLauncher] Found \(accounts.count) account(s)")
    }
}
