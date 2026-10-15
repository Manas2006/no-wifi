import AppKit

/// Separate menu-bar app. The only status item is Apple's Wi-Fi symbol with a slash.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.autosaveName = "NoWiFi"
        item.isVisible = true

        if let button = item.button {
            let pointSize = min(18, max(14, NSStatusBar.system.thickness * 0.55))
            let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
            let image = NSImage(systemSymbolName: "wifi.slash", accessibilityDescription: "No Wi-Fi")?
                .withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "No Wi-Fi"
        }

        let menu = NSMenu()
        let quit = NSMenuItem(
            title: "Quit No Wi-Fi",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)
        item.menu = menu
    }
}

@main
enum Entry {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
