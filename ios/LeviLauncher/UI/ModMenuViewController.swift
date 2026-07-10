import UIKit

// MARK: - Minecraft-style button
private enum MinecraftButtonStyle {
    case stone
    case redstone
}

private func makeMinecraftButton(title: String, icon: String,
                                 style: MinecraftButtonStyle = .stone) -> UIButton {
    let btn = UIButton(type: .custom)
    btn.translatesAutoresizingMaskIntoConstraints = false

    // Square, bevelled controls match Bedrock menus better than rounded iOS UI.
    let base: UIColor = style == .stone
        ? UIColor(red: 0.40, green: 0.40, blue: 0.42, alpha: 1)
        : UIColor(red: 0.50, green: 0.20, blue: 0.16, alpha: 1)
    let highlight: UIColor = style == .stone
        ? UIColor(red: 0.62, green: 0.62, blue: 0.64, alpha: 1)
        : UIColor(red: 0.72, green: 0.32, blue: 0.26, alpha: 1)
    let shadow: UIColor = style == .stone
        ? UIColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1)
        : UIColor(red: 0.26, green: 0.08, blue: 0.06, alpha: 1)
    let border = UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)

    btn.backgroundColor = base
    btn.layer.borderWidth = 3
    btn.layer.borderColor = border.cgColor
    btn.layer.cornerRadius = 0

    // Content
    btn.setTitle(title, for: .normal)
    btn.setImage(UIImage(systemName: icon), for: .normal)
    btn.tintColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
    btn.setTitleColor(UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), for: .normal)
    btn.contentHorizontalAlignment = .center
    btn.imageView?.contentMode = .scaleAspectFit
    btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
    btn.titleLabel?.font = UIFont(name: "Menlo-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
    btn.titleLabel?.shadowColor = UIColor(white: 0, alpha: 0.5)
    btn.titleLabel?.shadowOffset = CGSize(width: 1, height: 1)

    // 3D edge overlays via extra layers
    let topEdge = UIView()
    topEdge.isUserInteractionEnabled = false
    topEdge.backgroundColor = highlight
    topEdge.translatesAutoresizingMaskIntoConstraints = false
    btn.addSubview(topEdge)
    NSLayoutConstraint.activate([
        topEdge.topAnchor.constraint(equalTo: btn.topAnchor),
        topEdge.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 3),
        topEdge.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -3),
        topEdge.heightAnchor.constraint(equalToConstant: 2),
    ])

    let leftEdge = UIView()
    leftEdge.isUserInteractionEnabled = false
    leftEdge.backgroundColor = highlight
    leftEdge.translatesAutoresizingMaskIntoConstraints = false
    btn.addSubview(leftEdge)
    NSLayoutConstraint.activate([
        leftEdge.topAnchor.constraint(equalTo: btn.topAnchor, constant: 3),
        leftEdge.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -3),
        leftEdge.leadingAnchor.constraint(equalTo: btn.leadingAnchor),
        leftEdge.widthAnchor.constraint(equalToConstant: 2),
    ])

    let bottomEdge = UIView()
    bottomEdge.isUserInteractionEnabled = false
    bottomEdge.backgroundColor = shadow
    bottomEdge.translatesAutoresizingMaskIntoConstraints = false
    btn.addSubview(bottomEdge)
    NSLayoutConstraint.activate([
        bottomEdge.bottomAnchor.constraint(equalTo: btn.bottomAnchor),
        bottomEdge.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 3),
        bottomEdge.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -3),
        bottomEdge.heightAnchor.constraint(equalToConstant: 2),
    ])

    let rightEdge = UIView()
    rightEdge.isUserInteractionEnabled = false
    rightEdge.backgroundColor = shadow
    rightEdge.translatesAutoresizingMaskIntoConstraints = false
    btn.addSubview(rightEdge)
    NSLayoutConstraint.activate([
        rightEdge.topAnchor.constraint(equalTo: btn.topAnchor, constant: 3),
        rightEdge.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -3),
        rightEdge.trailingAnchor.constraint(equalTo: btn.trailingAnchor),
        rightEdge.widthAnchor.constraint(equalToConstant: 2),
    ])

    btn.heightAnchor.constraint(equalToConstant: 48).isActive = true
    btn.addAction(UIAction { [weak btn] _ in
        btn?.alpha = 0.82
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { btn?.alpha = 1 }
    }, for: .touchDown)
    return btn
}

// MARK: - Main Menu VC
class ModMenuViewController: UIViewController, UIGestureRecognizerDelegate {
    private var panelView: UIView?
    private let sections: [(title: String, icon: String)] = [
        ("Accounts", "person.circle"),
        ("Mods", "wrench.and.screwdriver"),
        ("Content", "folder.fill"),
        ("Settings", "gearshape.fill"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.6)
        setupMinecraftMenu()
    }

    override var prefersStatusBarHidden: Bool { true }

    private func setupMinecraftMenu() {
        // Darkened world behind a compact, chest-like panel.
        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor(red: 0.16, green: 0.12, blue: 0.08, alpha: 0.98)
        panel.layer.borderWidth = 3
        panel.layer.borderColor = UIColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 1).cgColor
        panel.layer.cornerRadius = 0
        view.addSubview(panel)
        panelView = panel

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "LEVI LAUNCHER"
        titleLabel.font = UIFont(name: "Menlo-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        titleLabel.textColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        titleLabel.shadowColor = UIColor(white: 0, alpha: 0.6)
        titleLabel.shadowOffset = CGSize(width: 1.5, height: 1.5)
        titleLabel.textAlignment = .center
        panel.addSubview(titleLabel)

        // Separator line
        let sep = UIView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.backgroundColor = UIColor(red: 0.35, green: 0.3, blue: 0.25, alpha: 1)
        panel.addSubview(sep)

        // Buttons stack
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fillEqually
        panel.addSubview(stack)

        for (i, section) in sections.enumerated() {
            let btn = makeMinecraftButton(title: section.title, icon: section.icon)
            btn.tag = i
            btn.addTarget(self, action: #selector(sectionTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }

        // Close button (red stone style)
        let closeBtn = makeMinecraftButton(title: "Back to Game", icon: "xmark", style: .redstone)
        closeBtn.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        panel.addSubview(closeBtn)

        // Layout
        let margin: CGFloat = 20
        let preferredWidth = panel.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panel.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            panel.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),

            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: margin),
            titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -margin),

            sep.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            sep.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: margin),
            sep.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -margin),
            sep.heightAnchor.constraint(equalToConstant: 1),

            stack.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: margin),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -margin),

            closeBtn.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
            closeBtn.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: margin),
            closeBtn.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -margin),
            closeBtn.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
        ])

        // Entrance animation
        panel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        panel.alpha = 0
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
            panel.transform = .identity
            panel.alpha = 1
        }

        // Background tap to dismiss
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        let pt = gesture.location(in: view)
        return !(panelView?.frame.contains(pt) ?? false)
    }

    @objc private func sectionTapped(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            let vc = InGameAccountViewController()
            present(UINavigationController(rootViewController: vc), animated: true)
        case 1:
            let vc = InGameModListViewController()
            present(UINavigationController(rootViewController: vc), animated: true)
        case 2:
            let vc = InGameContentViewController(contentType: 0)
            present(UINavigationController(rootViewController: vc), animated: true)
        case 3:
            let vc = InGameSettingsViewController()
            present(UINavigationController(rootViewController: vc), animated: true)
        default:
            break
        }
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

// Keep the topMostPresented extension for other files
extension UIViewController {
    var topMostPresented: UIViewController {
        var top = self
        while let next = top.presentedViewController {
            top = next
        }
        return top
    }
}
