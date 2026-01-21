import AppKit
import Foundation

@main
struct TokenMonitorMenuBarMain {
    static func main() {
        let app = NSApplication.shared
        let debugMode = ProcessInfo.processInfo.environment["TOKEN_MONITOR_DEBUG"] == "1"
        let forceRegular = ProcessInfo.processInfo.environment["TOKEN_MONITOR_FORCE_REGULAR"] == "1"
        let isUIElement = (Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool) ?? false
        let policy: NSApplication.ActivationPolicy = (debugMode || forceRegular || !isUIElement) ? .regular : .accessory
        app.setActivationPolicy(policy)
        AppLogger.log("Activation policy set: \(policy == .regular ? "regular" : "accessory")")
        let delegate = TokenMonitorMenuBarApp()
        app.delegate = delegate
        app.run()
    }
}
