import UIKit

/*  ── Built-in Mod definition ──────────────────────────────────
 *  Each mod has an id, display info, an SF Symbol icon, and an
 *  on/off toggle that bridges to the C++ mod namespace.
 *  ────────────────────────────────────────────────────────────────
 */

@objc enum BuiltinModID: Int, CaseIterable {
    case fpsCounter, zoom, snaplook
}

@objc class BuiltinMod: NSObject {
    let id: BuiltinModID
    let displayName: String
    let desc: String
    let icon: String

    @objc var isEnabled: Bool {
        didSet {
            if isEnabled { onEnable() } else { onDisable() }
        }
    }

    init(id: BuiltinModID, displayName: String, desc: String, icon: String) {
        self.id = id
        self.displayName = displayName
        self.desc = desc
        self.icon = icon
        self.isEnabled = false
    }

    private func onEnable() {
        switch id {
        case .fpsCounter: LauncherBridge.enableFpsCounter(true)
        case .zoom:       LauncherBridge.enableZoom(true)
        case .snaplook:   LauncherBridge.enableSnaplook(true)
        }
        BuiltinModManager.shared.refreshOverlays()
    }

    private func onDisable() {
        switch id {
        case .fpsCounter: LauncherBridge.enableFpsCounter(false)
        case .zoom:       LauncherBridge.enableZoom(false)
        case .snaplook:   LauncherBridge.enableSnaplook(false)
        }
        BuiltinModManager.shared.refreshOverlays()
    }

    /// Restore persisted state from the C++ mods
    func syncFromCpp() {
        let cppEnabled: Bool
        switch id {
        case .fpsCounter: cppEnabled = LauncherBridge.isFpsCounterEnabled()
        case .zoom:       cppEnabled = LauncherBridge.isZoomEnabled()
        case .snaplook:   cppEnabled = LauncherBridge.isSnaplookEnabled()
        }
        isEnabled = cppEnabled
    }
}

/*  ── Manager singleton ─────────────────────────────────────── */

@objc class BuiltinModManager: NSObject {
    @objc static let shared = BuiltinModManager()
    private override init() {}

    let mods: [BuiltinMod] = [
        BuiltinMod(id: .fpsCounter,
                   displayName: "FPS Counter",
                   desc: "Show frames per second in the top-left corner",
                   icon: "number.circle"),
        BuiltinMod(id: .zoom,
                   displayName: "Zoom",
                   desc: "Hold to zoom in 3× (like OptiFine zoom)",
                   icon: "magnifyingglass"),
        BuiltinMod(id: .snaplook,
                   displayName: "Snaplook",
                   desc: "Quick-look behind you (hold to look back)",
                   icon: "arrow.triangle.swap"),
    ]

    func loadPersistedState() {
        for mod in mods { mod.syncFromCpp() }
    }

    /*  ── Overlay views (currently only FPS) ──────────────── */
    private weak var fpsLabel: UILabel?

    func refreshOverlays() {
        DispatchQueue.main.async { self._rebuildOverlays() }
    }

    private var gameView: UIView? {
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for w in ws.windows {
                if let root = w.rootViewController {
                    if let vc = findGameVC(from: root) { return vc.view }
                }
            }
        }
        return nil
    }

    private var _displayLink: CADisplayLink?

    private func _rebuildOverlays() {
        fpsLabel?.removeFromSuperview()
        fpsLabel = nil
        _displayLink?.invalidate()
        _displayLink = nil

        guard let gv = gameView else { return }

        if mods[0].isEnabled {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont(name: "Menlo-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
            label.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.2, alpha: 1)
            label.shadowColor = UIColor(white: 0, alpha: 0.8)
            label.shadowOffset = CGSize(width: 1, height: 1)
            label.text = "0 FPS"
            gv.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: gv.safeAreaLayoutGuide.topAnchor, constant: 8),
                label.leadingAnchor.constraint(equalTo: gv.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            ])
            fpsLabel = label

            let dl = CADisplayLink(target: self, selector: #selector(_tickFps))
            dl.add(to: .main, forMode: .common)
            _displayLink = dl
        }
    }

    @objc private func _tickFps() {
        let fps = LauncherBridge.fpsValue()
        fpsLabel?.text = "\(fps) FPS"
    }
}

/*  ── Helper: walk VC hierarchy looking for game VC ─────────── */

private func findGameVC(from root: UIViewController) -> UIViewController? {
    let names = ["minecraftpeViewController", "MCGameViewController",
                 "GameViewController", "MinecraftViewController",
                 "ScreenViewController", "minecraft::MinecraftGameViewController"]
    let name = NSStringFromClass(type(of: root))
    if names.contains(where: { name.contains($0) }) { return root }
    if let p = root.presentedViewController { return findGameVC(from: p) }
    for child in root.children { if let f = findGameVC(from: child) { return f } }
    return nil
}
