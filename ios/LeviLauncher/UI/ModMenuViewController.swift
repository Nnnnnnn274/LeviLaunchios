import UIKit

class ModMenuViewController: UIViewController {
    private var mainView: UIView?
    private var menuButton: UIButton?
    private var isMenuVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = true
        setupMenuButton()
        setupGestureRecognizers()
    }

    private func setupMenuButton() {
        let button = UIButton(type: .custom)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        button.setImage(UIImage(systemName: "leaf.fill", withConfiguration: config), for: .normal)
        button.tintColor = .systemGreen
        button.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        button.layer.cornerRadius = 28
        button.layer.masksToBounds = true
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.systemGreen.cgColor

        button.frame = CGRect(x: UIScreen.main.bounds.width - 80,
                               y: 100, width: 56, height: 56)
        button.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]

        button.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)

        view.addSubview(button)
        menuButton = button
    }

    private func setupGestureRecognizers() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        menuButton?.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let button = menuButton else { return }
        let translation = gesture.translation(in: view)
        button.center = CGPoint(
            x: button.center.x + translation.x,
            y: button.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func toggleMenu() {
        isMenuVisible.toggle()
        if isMenuVisible {
            showModMenu()
        } else {
            hideModMenu()
        }
    }

    private func showModMenu() {
        let menuView = ModMenuView(frame: CGRect(x: 20, y: 60,
                                                   width: view.bounds.width - 40,
                                                   height: view.bounds.height - 120))
        menuView.backgroundColor = UIColor(white: 0.08, alpha: 0.95)
        menuView.layer.cornerRadius = 16
        menuView.layer.masksToBounds = true
        menuView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        menuView.tag = 999
        menuView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        menuView.alpha = 0
        view.addSubview(menuView)

        UIView.animate(withDuration: 0.2) {
            menuView.transform = .identity
            menuView.alpha = 1
        }
        mainView = menuView
    }

    private func hideModMenu() {
        UIView.animate(withDuration: 0.2, animations: {
            self.mainView?.alpha = 0
            self.mainView?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.mainView?.removeFromSuperview()
            self.mainView = nil
        }
    }
}

class ModMenuView: UIView {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let titleLabel = UILabel()

    enum MenuSection: CaseIterable {
        case accounts, mods, content, settings

        var title: String {
            switch self {
            case .accounts: return "Accounts"
            case .mods: return "Mods"
            case .content: return "Content"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .accounts: return "person.circle"
            case .mods: return "wrench.fill"
            case .content: return "folder.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        titleLabel.text = "LeviLauncher"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func presentViewController(_ vc: UIViewController) {
        guard let rootVC = window?.rootViewController else { return }
        rootVC.present(vc, animated: true)
    }
}

extension ModMenuView: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        MenuSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch MenuSection.allCases[section] {
        case .accounts: return 1
        case .mods: return 2
        case .content: return 4
        case .settings: return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        MenuSection.allCases[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = UIColor(white: 0.15, alpha: 0.8)
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = .systemFont(ofSize: 16)

        let section = MenuSection.allCases[indexPath.section]
        switch section {
        case .accounts:
            cell.textLabel?.text = MsftAccountStore.activeAccount?.xboxGamertag ?? "Add Account"
            cell.imageView?.image = UIImage(systemName: "person.circle")
            cell.imageView?.tintColor = .systemGreen
        case .mods:
            cell.textLabel?.text = indexPath.row == 0 ? "Manage Mods" : "Inbuilt Mods"
            cell.imageView?.image = UIImage(systemName: indexPath.row == 0 ? "wrench.and.screwdriver" : "gearshape.2")
            cell.imageView?.tintColor = .systemPurple
        case .content:
            let items = ["Worlds", "Resource Packs", "Servers", "Screenshots"]
            cell.textLabel?.text = items[indexPath.row]
            cell.imageView?.image = UIImage(systemName: ["globe", "paintbrush", "server.rack", "photo"][indexPath.row])
            cell.imageView?.tintColor = .systemOrange
        case .settings:
            cell.textLabel?.text = "Settings"
            cell.imageView?.image = UIImage(systemName: "gearshape.fill")
            cell.imageView?.tintColor = .systemGray
        }

        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = MenuSection.allCases[indexPath.section]
        switch section {
        case .accounts:
            let vc = InGameAccountViewController()
            presentViewController(UINavigationController(rootViewController: vc))
        case .mods:
            if indexPath.row == 0 {
                let vc = InGameModListViewController()
                presentViewController(UINavigationController(rootViewController: vc))
            }
        case .content:
            let vc = InGameContentViewController(contentType: indexPath.row)
            presentViewController(UINavigationController(rootViewController: vc))
        case .settings:
            let vc = InGameSettingsViewController()
            presentViewController(UINavigationController(rootViewController: vc))
        }
    }
}
