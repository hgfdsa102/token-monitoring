import AppKit
import Foundation

final class TokenMonitorMenuBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var countdownTimer: Timer?
    private let monitor = StatusMonitor()
    private let refreshIntervalKey = "refreshIntervalSeconds"
    private let refreshOptions: [(title: String, seconds: TimeInterval)] = [
        ("10 min", 10 * 60),
        ("30 min", 30 * 60),
        ("1 hour", 60 * 60),
    ]
    private let resetCycleSeconds: TimeInterval = 5 * 60 * 60
    private var lastStatus: StatusResult?

    private func ensureStatusItem() {
        if statusItem == nil || statusItem.button == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem.isVisible = true
            AppLogger.log("Status item created")
        }
        if let button = statusItem.button {
            if button.title.isEmpty {
                button.title = "CC ..."
            }
            if button.image != nil {
                button.image = nil
            }
            button.target = self
            button.action = #selector(openMenu)
            AppLogger.log("Status item button ensured")
        } else {
            AppLogger.log("Status item button missing")
        }

        statusItem.menu = buildMenu()
        AppLogger.log("Status item menu attached")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let debugMode = ProcessInfo.processInfo.environment["TOKEN_MONITOR_DEBUG"] == "1"
        AppLogger.log("TokenMonitorMenuBar started (debug=\(debugMode))")

        ensureStatusItem()

        refreshNow()
        rescheduleTimer()
        rescheduleCountdownTimer()

        if debugMode {
            let alert = NSAlert()
            alert.messageText = "TokenMonitorMenuBar started"
            alert.runModal()
        }
    }

    @objc private func refreshNow() {
        ensureStatusItem()
        AppLogger.log("Refreshing status")
        monitor.fetchStatus { [weak self] result in
            DispatchQueue.main.async {
                self?.lastStatus = result
                let title = self?.currentMenuTitle() ?? "CC ..."
                if result.resetDate == nil, let resetText = result.resetText {
                    AppLogger.log("Reset parse failed for text: \(resetText)")
                }
                AppLogger.log("Status updated: \(title)")
                self?.statusItem.button?.title = title
            }
        }
    }

    @objc private func selectRefreshInterval(_ sender: NSMenuItem) {
        let seconds = TimeInterval(sender.tag)
        UserDefaults.standard.set(seconds, forKey: refreshIntervalKey)
        statusItem.menu = buildMenu()
        rescheduleTimer()
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: currentRefreshInterval(), target: self, selector: #selector(refreshNow), userInfo: nil, repeats: true)
        AppLogger.log("Refresh interval set to \(Int(currentRefreshInterval()))s")
    }

    private func rescheduleCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(tickCountdown), userInfo: nil, repeats: true)
        tickCountdown()
    }

    @objc private func tickCountdown() {
        ensureStatusItem()
        let title = currentMenuTitle()
        statusItem.button?.title = title
    }

    private func currentRefreshInterval() -> TimeInterval {
        let stored = UserDefaults.standard.double(forKey: refreshIntervalKey)
        if stored > 0 {
            return stored
        }
        return refreshOptions[0].seconds
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))

        let intervalMenu = NSMenu()
        let current = currentRefreshInterval()
        for option in refreshOptions {
            let item = NSMenuItem(title: option.title, action: #selector(selectRefreshInterval(_:)), keyEquivalent: "")
            item.tag = Int(option.seconds)
            item.state = option.seconds == current ? .on : .off
            item.target = self
            intervalMenu.addItem(item)
        }
        let intervalItem = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
        menu.setSubmenu(intervalMenu, for: intervalItem)
        menu.addItem(intervalItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        return menu
    }

    private func currentMenuTitle() -> String {
        guard let status = lastStatus else {
            return "CC ..."
        }
        let countdown = countdownString(from: status)
        if let percent = status.percent {
            return "\(percent)%|\(countdown)"
        }
        return countdown
    }

    private func countdownString(from status: StatusResult) -> String {
        guard let resetDate = status.resetDate else {
            return "--:--"
        }
        var target = resetDate
        let now = Date()
        while target <= now {
            target = target.addingTimeInterval(resetCycleSeconds)
        }
        let interval = max(0, Int(target.timeIntervalSince(now)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    @objc private func openMenu() {
        statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
