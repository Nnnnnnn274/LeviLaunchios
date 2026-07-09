import UIKit

// MARK: - Minecraft-style button
private func makeMinecraftButton(title: String, icon: String) -> UIButton {
    let btn = UIButton(type: .custom)
    btn.translatesAutoresizingMaskIntoConstraints = false

    // Stone texture gradient
    let base = UIColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1)
    let highlight = UIColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 1)
    let shadow = UIColor(red: 0.35, green: 0.35, blue: 0.37, alpha: 1)
    let border = UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)

    btn.backgroundColor = base
    btn.layer.borderWidth = 3
    btn.layer.borderColor = border.cgColor
    btn.layer.cornerRadius = 2

    // Top/left highlight, bottom/right shadow via bezier
    let size = CGSize(width: 1, height: 1)
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    if let ctx = UIGraphicsGetCurrentContext() {
        ctx.setFillColor(base.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
    }
    let bgImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    btn.setBackgroundImage(bgImage, for: .normal)

    // Content
    var cfg = UIButton.Configuration.plain()
    cfg.title = title
    cfg.image = UIImage(systemName: icon)
    cfg.imagePadding = 8
    cfg.baseForegroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
    btn.configuration = cfg
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

    private func setupMinecraftMenu() {
        // Chest-like panel background
        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor(red: 0.2, green: 0.16, blue: 0.13, alpha: 0.95)
        panel.layer.borderWidth = 3
        panel.layer.borderColor = UIColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 1).cgColor
        panel.layer.cornerRadius = 4
        view.addSubview(panel)
        panelView = panel

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "§lLeviLauncher"
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
        let closeBtn = makeMinecraftButton(title: "Close", icon: "xmark")
        closeBtn.backgroundColor = UIColor(red: 0.55, green: 0.25, blue: 0.2, alpha: 1)
        closeBtn.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        panel.addSubview(closeBtn)

        // Layout
        let margin: CGFloat = 20
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panel.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -60),
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
