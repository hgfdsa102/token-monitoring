import Foundation

enum AppLogger {
    private static let logFile = ProcessInfo.processInfo.environment["TOKEN_MONITOR_LOG_PATH"]
        ?? ("~/Library/Logs/TokenMonitorMenuBar.log" as NSString).expandingTildeInPath

    private static func ensureLogDirectory() {
        let dir = (logFile as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: dir) {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
    }

    static func log(_ message: String) {
        ensureLogDirectory()
        let line = "\(Date()) \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile) {
                if let handle = FileHandle(forWritingAtPath: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logFile))
            }
        }
        NSLog("%@", message)
    }
}
