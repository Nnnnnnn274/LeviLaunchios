import UIKit
import AuthenticationServices

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
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .done,
            target: self,
            action: #selector(dismissSelf)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addAccount)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = UIColor(white: 0.1, alpha: 1)
        loadAccounts()
    }

    private func loadAccounts() {
        accounts = MsftAccountStore.list()
        tableView.reloadData()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
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
        cell.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        cell.textLabel?.textColor = .white
        cell.imageView?.tintColor = .systemGreen

        if accounts.isEmpty {
            cell.textLabel?.text = "No accounts - tap + to add"
            cell.imageView?.image = UIImage(systemName: "person.slash")
        } else {
            let account = accounts[indexPath.row]
            cell.textLabel?.text = account.xboxGamertag ?? account.msUserId
            cell.imageView?.image = UIImage(systemName: account.isActive ? "person.circle.fill" : "person.circle")
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

class InGameModListViewController: UITableViewController {
    private var mods: [Mod] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Mods"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .done, target: self, action: #selector(dismissSelf)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = UIColor(white: 0.1, alpha: 1)
        loadMods()
    }

    private func loadMods() {
        let modsDir = LauncherStorage.minecraftRoot.appendingPathComponent("mods")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: modsDir,
                            includingPropertiesForKeys: nil) else { return }
        mods = contents.compactMap { url -> Mod? in
            guard url.pathExtension == "dylib" else { return nil }
            return Mod(id: url.lastPathComponent, fileName: url.lastPathComponent,
                       entryPath: url.path, displayName: url.deletingPathExtension().lastPathComponent)
        }
        tableView.reloadData()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(mods.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        cell.textLabel?.textColor = .white
        cell.imageView?.tintColor = .systemPurple

        if mods.isEmpty {
            cell.textLabel?.text = "No mods installed"
            cell.imageView?.image = UIImage(systemName: "wrench.and.screwdriver")
        } else {
            let mod = mods[indexPath.row]
            cell.textLabel?.text = mod.displayName
            cell.imageView?.image = UIImage(systemName: mod.isEnabled ? "checkmark.circle.fill" : "circle")
            cell.imageView?.tintColor = mod.isEnabled ? .systemGreen : .systemGray
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .done, target: self, action: #selector(dismissSelf)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = UIColor(white: 0.1, alpha: 1)
        loadContent()
    }

    private func loadContent() {
        let gameDir = LauncherStorage.sharedDataRoot.appendingPathComponent("games/com.mojang")
        switch contentType {
        case 0: // Worlds
            let worldsDir = gameDir.appendingPathComponent("minecraftWorlds")
            items = WorldManager.shared.listWorlds(in: worldsDir)
        case 1: // Resource Packs
            let packsDir = gameDir.appendingPathComponent("resource_packs")
            items = ResourcePackManager.shared.listPacks(in: packsDir)
        case 3: // Screenshots
            let shotsDir = gameDir.appendingPathComponent("screenshots")
            items = ScreenshotManager.shared.listScreenshots(in: shotsDir).map {
                ContentItem(name: $0.file.lastPathComponent, file: $0.file)
            }
        default:
            break
        }
        tableView.reloadData()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(items.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        cell.textLabel?.textColor = .white

        if items.isEmpty {
            cell.textLabel?.text = "No \(title ?? "content") found"
            cell.textLabel?.textColor = .gray
        } else {
            let item = items[indexPath.row]
            cell.textLabel?.text = item.name
            cell.detailTextLabel?.text = item.formattedSize
        }
        return cell
    }
}

// MARK: - In-Game Settings

class InGameSettingsViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .done, target: self, action: #selector(dismissSelf)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = UIColor(white: 0.1, alpha: 1)
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 4 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")
        cell.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = .gray

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
            cell.detailTextLabel?.textColor = .systemGreen
        case 3:
            cell.textLabel?.text = "iOS Version"
            cell.detailTextLabel?.text = UIDevice.current.systemVersion
        default:
            break
        }
        return cell
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
