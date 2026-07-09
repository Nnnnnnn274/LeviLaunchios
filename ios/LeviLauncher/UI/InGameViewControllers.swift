import UIKit
import AuthenticationServices

// MARK: - Minecraft-style helpers
private func mcLabel(_ text: String, size: CGFloat = 15) -> UILabel {
    let l = UILabel()
    l.translatesAutoresizingMaskIntoConstraints = false
    l.text = text
    l.font = UIFont(name: "Menlo-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    l.textColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
    l.shadowColor = UIColor(white: 0, alpha: 0.6)
    l.shadowOffset = CGSize(width: 1, height: 1)
    return l
}

private let mcBg = UIColor(red: 0.2, green: 0.16, blue: 0.13, alpha: 1)
private let mcCellBg = UIColor(red: 0.3, green: 0.26, blue: 0.22, alpha: 1)
private let mcBorder = UIColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 1)

private func mcCell(text: String, icon: String, tag: Int) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.backgroundColor = mcCellBg
    cell.contentView.backgroundColor = .clear
    cell.textLabel?.text = text
    cell.textLabel?.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
    cell.textLabel?.font = UIFont(name: "Menlo-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
    cell.textLabel?.shadowColor = UIColor(white: 0, alpha: 0.5)
    cell.textLabel?.shadowOffset = CGSize(width: 1, height: 1)
    cell.imageView?.image = UIImage(systemName: icon)
    cell.imageView?.tintColor = UIColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 1)
    cell.accessoryType = .disclosureIndicator
    cell.tag = tag
    // Stone button border
    cell.contentView.layer.borderWidth = 2
    cell.contentView.layer.borderColor = mcBorder.cgColor
    cell.contentView.layer.cornerRadius = 2
    return cell
}

private func styleNav(_ vc: UIViewController) {
    guard let nav = vc.navigationController else { return }
    nav.navigationBar.isTranslucent = false
    nav.navigationBar.barTintColor = UIColor(red: 0.15, green: 0.12, blue: 0.09, alpha: 1)
    nav.navigationBar.titleTextAttributes = [
        .font: UIFont(name: "Menlo-Bold", size: 16) ?? .boldSystemFont(ofSize: 16),
        .foregroundColor: UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
    ]
    vc.navigationItem.leftBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "xmark"),
        style: .done, target: vc, action: #selector(UIViewController.dismissSelfNav)
    )
    vc.navigationItem.leftBarButtonItem?.tintColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
}

// MARK: - In-Game Account Management

class InGameAccountViewController: UITableViewController, ASWebAuthenticationSessionPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? UIWindow()
    }
    private var accounts: [MsftAccount] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Accounts"
        styleNav(self)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain, target: self, action: #selector(addAccount)
        )
        navigationItem.rightBarButtonItem?.tintColor = UIColor(red: 0.5, green: 0.8, blue: 0.5, alpha: 1)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = mcBg
        tableView.separatorColor = mcBorder
        loadAccounts()
    }

    private func loadAccounts() {
        accounts = MsftAccountStore.list()
        tableView.reloadData()
    }

    @objc private func addAccount() {
        Task {
            let viewModel = MainViewModel()
            await viewModel.login(presenting: self)
            loadAccounts()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(accounts.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = mcCellBg
        cell.textLabel?.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        cell.textLabel?.font = UIFont(name: "Menlo-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        cell.textLabel?.shadowColor = UIColor(white: 0, alpha: 0.5)
        cell.textLabel?.shadowOffset = CGSize(width: 1, height: 1)

        if accounts.isEmpty {
            cell.textLabel?.text = "No accounts — tap + to add"
            cell.imageView?.image = UIImage(systemName: "person.slash")
            cell.imageView?.tintColor = .systemGray
        } else {
            let account = accounts[indexPath.row]
            cell.textLabel?.text = account.xboxGamertag ?? account.msUserId
            cell.imageView?.image = UIImage(systemName: account.isActive ? "person.circle.fill" : "person.circle")
            cell.imageView?.tintColor = account.isActive ? .systemGreen : .systemGray
            cell.accessoryType = account.isActive ? .checkmark : .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < accounts.count else { return }
        MsftAccountStore.setActive(id: accounts[indexPath.row].id)
        loadAccounts()
    }
}

// MARK: - In-Game Mod List

private let builtinSection = 0
private let externalSection = 1

class InGameModListViewController: UITableViewController {
    private var externalMods: [Mod] = []
    private var builtinMods: [BuiltinMod] { BuiltinModManager.shared.mods }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Mods"
        styleNav(self)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain, target: self, action: #selector(addMod)
        )
        navigationItem.rightBarButtonItem?.tintColor = UIColor(red: 0.5, green: 0.8, blue: 0.5, alpha: 1)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = mcBg
        tableView.separatorColor = mcBorder
        loadExternalMods()
    }

    private func loadExternalMods() {
        let modsDir = LauncherStorage.minecraftRoot.appendingPathComponent("mods")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: modsDir,
                            includingPropertiesForKeys: nil) else { return }
        externalMods = contents.compactMap { url -> Mod? in
            guard url.pathExtension == "dylib" else { return nil }
            return Mod(id: url.lastPathComponent, fileName: url.lastPathComponent,
                       entryPath: url.path, displayName: url.deletingPathExtension().lastPathComponent)
        }
        tableView.reloadData()
    }

    @objc private func addMod() {}

    // ── Sections ────────────────────────────────────────────────

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == builtinSection ? "Built-in" : "External"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == builtinSection ? builtinMods.count : max(externalMods.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == builtinSection {
            return cellForBuiltinMod(at: indexPath)
        }
        return cellForExternalMod(at: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // ── Built-in mod cell ───────────────────────────────────────

    private func cellForBuiltinMod(at indexPath: IndexPath) -> UITableViewCell {
        let mod = builtinMods[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = mcCellBg
        cell.textLabel?.text = mod.displayName
        cell.textLabel?.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        cell.textLabel?.font = UIFont(name: "Menlo-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        cell.textLabel?.shadowColor = UIColor(white: 0, alpha: 0.5)
        cell.textLabel?.shadowOffset = CGSize(width: 1, height: 1)
        cell.detailTextLabel?.text = mod.desc
        cell.detailTextLabel?.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        cell.detailTextLabel?.font = UIFont(name: "Menlo", size: 10) ?? .systemFont(ofSize: 10)
        cell.imageView?.image = UIImage(systemName: mod.icon)
        cell.imageView?.tintColor = UIColor(red: 0.5, green: 0.7, blue: 0.5, alpha: 1)
        cell.selectionStyle = .none

        let toggle = UISwitch()
        toggle.isOn = mod.isEnabled
        toggle.onTintColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1)
        toggle.tag = mod.id.rawValue
        toggle.addTarget(self, action: #selector(builtinToggled(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        return cell
    }

    @objc private func builtinToggled(_ sender: UISwitch) {
        guard let modID = BuiltinModID(rawValue: sender.tag) else { return }
        let mod = builtinMods.first { $0.id == modID }
        mod?.isEnabled = sender.isOn
    }

    // ── External mod cell ───────────────────────────────────────

    private func cellForExternalMod(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = mcCellBg
        cell.textLabel?.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        cell.textLabel?.font = UIFont(name: "Menlo-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        cell.textLabel?.shadowColor = UIColor(white: 0, alpha: 0.5)
        cell.textLabel?.shadowOffset = CGSize(width: 1, height: 1)

        if externalMods.isEmpty {
            cell.textLabel?.text = "No mods installed"
            cell.imageView?.image = UIImage(systemName: "wrench.and.screwdriver")
            cell.imageView?.tintColor = .systemGray
        } else {
            let mod = externalMods[indexPath.row]
            cell.textLabel?.text = mod.displayName
            cell.imageView?.image = UIImage(systemName: mod.isEnabled ? "checkmark.circle.fill" : "circle")
            cell.imageView?.tintColor = mod.isEnabled ? .systemGreen : .systemGray
        }
        return cell
    }
}

// MARK: - In-Game Content Browser

class InGameContentViewController: UITableViewController {
    private let contentType: Int
    private var items: [ContentItem] = []

    init(contentType: Int) {
        self.contentType = contentType
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let titles = ["Worlds", "Resource Packs", "Servers", "Screenshots"]
        title = titles[safe: contentType] ?? "Content"
        styleNav(self)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = mcBg
        tableView.separatorColor = mcBorder
        loadContent()
    }

    private func loadContent() {
        let gameDir = LauncherStorage.sharedDataRoot.appendingPathComponent("games/com.mojang")
        switch contentType {
        case 0:
            let worldsDir = gameDir.appendingPathComponent("minecraftWorlds")
            items = WorldManager.shared.listWorlds(in: worldsDir)
        case 1:
            let packsDir = gameDir.appendingPathComponent("resource_packs")
            items = ResourcePackManager.shared.listPacks(in: packsDir)
        case 3:
            let shotsDir = gameDir.appendingPathComponent("screenshots")
            items = ScreenshotManager.shared.listScreenshots(in: shotsDir).map {
                ContentItem(name: $0.file.lastPathComponent, file: $0.file)
            }
        default:
            break
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(items.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = mcCellBg
        cell.textLabel?.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        cell.textLabel?.font = UIFont(name: "Menlo-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        cell.textLabel?.shadowColor = UIColor(white: 0, alpha: 0.5)
        cell.textLabel?.shadowOffset = CGSize(width: 1, height: 1)

        if items.isEmpty {
            cell.textLabel?.text = "No \(title ?? "content") found"
            cell.textLabel?.textColor = .gray
        } else {
            let item = items[indexPath.row]
            cell.textLabel?.text = item.name
            cell.detailTextLabel?.text = item.formattedSize
            cell.detailTextLabel?.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        }
        return cell
    }
}

// MARK: - In-Game Settings

class InGameSettingsViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        styleNav(self)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = mcBg
        tableView.separatorColor = mcBorder
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 4 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = mcCellBg
        cell.textLabel?.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        cell.textLabel?.font = UIFont(name: "Menlo-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        cell.textLabel?.shadowColor = UIColor(white: 0, alpha: 0.5)
        cell.textLabel?.shadowOffset = CGSize(width: 1, height: 1)
        cell.detailTextLabel?.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        cell.detailTextLabel?.font = UIFont(name: "Menlo", size: 12) ?? .systemFont(ofSize: 12)

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "LeviLauncher Version"
            cell.detailTextLabel?.text = "1.0.0"
        case 1:
            cell.textLabel?.text = "Active Account"
            cell.detailTextLabel?.text = MsftAccountStore.activeAccount?.xboxGamertag ?? "None"
        case 2:
            cell.textLabel?.text = "Mod Injection"
            cell.detailTextLabel?.text = "Active"
            cell.detailTextLabel?.textColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
        case 3:
            cell.textLabel?.text = "iOS Version"
            cell.detailTextLabel?.text = UIDevice.current.systemVersion
        default:
            break
        }
        return cell
    }
}

// MARK: - Dismiss helper
extension UIViewController {
    @objc func dismissSelfNav() {
        dismiss(animated: true)
    }
}

// MARK: - Safe Array Access
extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
