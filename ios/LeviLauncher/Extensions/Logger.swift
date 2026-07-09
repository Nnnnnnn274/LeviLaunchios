import Foundation
import OSLog

struct Logger {
    private static let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.levimc.launcher",
                                      category: "LeviLauncher")

    static func info(_ tag: String, _ message: String) {
        os_log("%{public}@: %{public}@", log: osLog, type: .info, tag, message)
    }

    static func warn(_ tag: String, _ message: String) {
        os_log("%{public}@: %{public}@", log: osLog, type: .error, tag, message)
    }

    static func error(_ tag: String, _ message: String) {
        os_log("%{public}@: %{public}@", log: osLog, type: .fault, tag, message)
    }

    static func debug(_ tag: String, _ message: String) {
        #if DEBUG
        os_log("%{public}@: %{public}@", log: osLog, type: .debug, tag, message)
        #endif
    }
}
