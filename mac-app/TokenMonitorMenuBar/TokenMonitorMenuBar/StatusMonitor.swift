import Foundation

struct StatusResult {
    let percent: Int?
    let resetDate: Date?
    let resetTimeZone: TimeZone?
    let resetText: String?
}

final class StatusMonitor {
    private let stateQueue = DispatchQueue(label: "StatusMonitor.state")
    private var isRunning = false
    private var pendingCompletions: [(StatusResult) -> Void] = []

    private var scriptPath: String {
        // 1. 환경 변수 우선
        if let envPath = ProcessInfo.processInfo.environment["TOKEN_MONITOR_CAPTURE_PATH"], !envPath.isEmpty {
            return envPath
        }
        // 2. 앱 번들 내 Resources
        if let bundlePath = Bundle.main.path(forResource: "capture-status", ofType: "py") {
            return bundlePath
        }
        // 3. 폴백: 개발용 경로
        return ("~/github/token-monitoring/capture-status.py" as NSString).expandingTildeInPath
    }

    func fetchStatus(completion: @escaping (StatusResult) -> Void) {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            self.pendingCompletions.append(completion)
            if self.isRunning {
                AppLogger.log("Capture already running; coalescing request")
                return
            }
            self.isRunning = true
            self.runCapture(attempt: 1)
        }
    }

    private func runCapture(attempt: Int) {
        let process = Process()
        process.launchPath = "/usr/bin/python3"
        // 홈 디렉토리에서 실행 (앱 번들 Resources는 읽기 전용)
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var arguments = [scriptPath, "--json"]
        if let rawPath = ProcessInfo.processInfo.environment["TOKEN_MONITOR_CAPTURE_RAW"], !rawPath.isEmpty {
            arguments += ["--raw", rawPath]
        }
        process.arguments = arguments

        // Pass through essential environment variables
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        env["TERM"] = "xterm-256color"
        // 이미 승인된 폴더를 cwd로 사용 (홈 디렉토리는 매번 확인 프롬프트 발생)
        env["CLAUDE_CWD"] = FileManager.default.temporaryDirectory.path
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            AppLogger.log("Running capture script: \(scriptPath)")
            try process.run()
        } catch {
            AppLogger.log("Failed to run capture script: \(error.localizedDescription)")
            finishCapture(with: StatusResult(percent: nil, resetDate: nil, resetTimeZone: nil, resetText: nil))
            return
        }

        process.terminationHandler = { [weak self] _ in
            guard let self = self else { return }
            AppLogger.log("Capture script finished")
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            let result = Self.parseStatus(from: output)
            if result == nil && attempt < 2 {
                AppLogger.log("Capture parse failed; retrying (attempt \(attempt + 1))")
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    self.runCapture(attempt: attempt + 1)
                }
                return
            }
            if result == nil {
                let tail = output.split(separator: "\n").suffix(6).joined(separator: " | ")
                if !tail.isEmpty {
                    AppLogger.log("Capture output tail: \(tail)")
                }
            }
            self.finishCapture(with: result ?? StatusResult(percent: nil, resetDate: nil, resetTimeZone: nil, resetText: nil))
        }
    }

    private func finishCapture(with result: StatusResult) {
        let completions = stateQueue.sync { () -> [(StatusResult) -> Void] in
            let pending = pendingCompletions
            pendingCompletions.removeAll()
            isRunning = false
            return pending
        }
        for completion in completions {
            completion(result)
        }
    }

    static func parseStatus(from jsonText: String) -> StatusResult? {
        guard
            let data = jsonText.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let resetText = obj["current_session_reset"] as? String
        let percent = obj["current_session_percent"] as? Int
        if resetText == nil && percent == nil {
            return nil
        }
        let parsed = resetText.map { Self.parseResetDate(from: $0) }
        return StatusResult(
            percent: percent,
            resetDate: parsed?.date,
            resetTimeZone: parsed?.timeZone,
            resetText: resetText
        )
    }

    static func parseResetDate(from resetText: String) -> (date: Date?, timeZone: TimeZone) {
        // Example: "Resets 7pm (Asia/Seoul)" or "Resets6pm (Asia/Seoul)"
        var cleaned = resetText.replacingOccurrences(of: "Resets ", with: "")
            .replacingOccurrences(of: "Resets", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        if let match = cleaned.range(of: "\\(([^)]+)\\)", options: .regularExpression) {
            let tzId = cleaned[match]
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
            if let tz = TimeZone(identifier: tzId) {
                timeZone = tz
            }
            cleaned = cleaned.replacingOccurrences(of: String(cleaned[match]), with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let tz = extractTrailingTimeZone(from: cleaned) {
            timeZone = tz.timeZone
            cleaned = tz.cleaned
        }

        let lowered = cleaned.lowercased()
        if let relative = parseRelativeTime(from: lowered) {
            return (Date().addingTimeInterval(relative), timeZone)
        }

        cleaned = cleaned
            .replacingOccurrences(of: "today at ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "tomorrow at ", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "(mon|tue|wed|thu|fri|sat|sun)\\w*\\s+at\\s+", with: "", options: .regularExpression)
        let normalized = Self.normalizeAmPmSpacing(cleaned)

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = ["h a", "h:mm a", "H:mm", "MMM d 'at' h a", "MMM d 'at' h:mm a", "MMM d, h a", "MMM d, h:mm a", "MMM d h a", "MMM d h:mm a"]

        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var target: Date?
        for format in formats {
            formatter.dateFormat = format
            if let candidate = Self.targetDate(from: normalized, now: now, calendar: calendar, formatter: formatter) {
                target = candidate
                break
            }
        }
        return (target, timeZone)
    }

    private static func parseRelativeTime(from text: String) -> TimeInterval? {
        if let match = text.range(of: "in\\s+(\\d+)\\s+hours?", options: .regularExpression) {
            let value = Int(text[match].replacingOccurrences(of: "in ", with: "").replacingOccurrences(of: " hours", with: "").replacingOccurrences(of: " hour", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            return TimeInterval(value * 3600)
        }
        if let match = text.range(of: "in\\s+(\\d+)\\s+minutes?", options: .regularExpression) {
            let value = Int(text[match].replacingOccurrences(of: "in ", with: "").replacingOccurrences(of: " minutes", with: "").replacingOccurrences(of: " minute", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            return TimeInterval(value * 60)
        }
        return nil
    }

    private static func extractTrailingTimeZone(from text: String) -> (cleaned: String, timeZone: TimeZone)? {
        let parts = text.split(separator: " ")
        guard let last = parts.last else {
            return nil
        }
        let lastToken = String(last)
        if let tz = TimeZone(identifier: lastToken) ?? TimeZone(abbreviation: lastToken) {
            let cleaned = parts.dropLast().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return (cleaned, tz)
        }
        return nil
    }

    private static func targetDate(from text: String, now: Date, calendar: Calendar, formatter: DateFormatter) -> Date? {
        if let parsedTime = formatter.date(from: text) {
            let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
            var targetComponents = DateComponents()
            targetComponents.year = nowComponents.year
            targetComponents.month = nowComponents.month
            targetComponents.day = nowComponents.day
            targetComponents.hour = timeComponents.hour
            targetComponents.minute = timeComponents.minute
            guard var targetDate = calendar.date(from: targetComponents) else {
                return nil
            }
            if targetDate < now {
                targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
            }
            return targetDate
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = formatter.timeZone
        dateFormatter.locale = formatter.locale
        dateFormatter.dateFormat = "MMM d 'at' h a"
        if let parsedDate = dateFormatter.date(from: text) {
            return parsedDate
        }

        return nil
    }

    private static func normalizeAmPmSpacing(_ text: String) -> String {
        let pattern = "(\\d)(am|pm)\\b"
        return text.replacingOccurrences(of: pattern, with: "$1 $2", options: .regularExpression)
    }
}
