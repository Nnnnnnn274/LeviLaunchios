import Foundation
import UIKit

actor CrashReporter {
    static let shared = CrashReporter()
    static let crashLogsDir: URL = LauncherStorage.crashLogsDir

    struct CrashLog: Codable, Identifiable {
        var id: String { "\(timestamp)" }
        let timestamp: Date
        let type: CrashType
        let summary: String
        let details: String
        let logFileURL: URL?

        enum CrashType: String, Codable {
            case java = "JAVA"
            case native = "NATIVE"
            case anr = "ANR"
            case unknown = "UNKNOWN"
        }
    }

    func writeCrashLog(type: CrashLog.CrashType, error: Error, details: String = "") -> URL? {
        let timestamp = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "crash_\(df.string(from: timestamp))_\(type.rawValue).log"
        let fileURL = Self.crashLogsDir.appendingPathComponent(fileName)

        var log = """
        LeviLauncher Crash Report
        ========================
        Date: \(timestamp)
        Type: \(type.rawValue)
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)

        \(details)

        Error: \(error.localizedDescription)

        """

        do {
            try FileManager.default.createDirectory(at: Self.crashLogsDir, withIntermediateDirectories: true)
            try log.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            Logger.error("CrashReporter", "Failed to write crash log: \(error)")
            return nil
        }
    }

    func listCrashLogs() -> [CrashLog] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: Self.crashLogsDir,
                                                                        includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        return files.compactMap { url -> CrashLog? in
            guard url.pathExtension == "log" else { return nil }
            let typeStr = url.deletingPathExtension().lastPathComponent.components(separatedBy: "_").last ?? "UNKNOWN"
            let type = CrashLog.CrashType(rawValue: typeStr) ?? .unknown
            let details = (try? String(contentsOf: url)) ?? ""
            let summary = details.components(separatedBy: .newlines).first { $0.contains("Error:") }
                ?? details.components(separatedBy: .newlines).first ?? "Unknown crash"
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            return CrashLog(timestamp: modDate, type: type, summary: summary, details: details, logFileURL: url)
        }.sorted { $0.timestamp > $1.timestamp }
    }

    func deleteCrashLog(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
