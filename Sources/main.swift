import AppKit

/// Menu-bar app. The icon is the crossed-out Wi-Fi mark. Clicking it opens a
/// visual copy of the macOS Wi-Fi panel. Nothing in that panel changes Wi-Fi.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var instance: AppDelegate?

    private var statusItem: NSStatusItem?
    private var panel: WiFiPanel?
    private let menuView = WiFiMenuView(frame: NSRect(x: 0, y: 0, width: WiFiMenuView.width, height: WiFiMenuView.offHeight))
    private var outsideMonitor: Any?
    private var localMonitor: Any?

    override init() {
        super.init()
        Self.instance = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.autosaveName = "NoWiFi"
        item.isVisible = true

        if let button = item.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(togglePanel(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        applyIcon(on: false)

        menuView.onPowerChange = { [weak self] isOn in
            self?.applyIcon(on: isOn)
            self?.resizePanel()
        }
        panel = WiFiPanel(view: menuView)
    }

    private func applyIcon(on: Bool) {
        guard let button = statusItem?.button else { return }
        let pointSize = min(18, max(14, NSStatusBar.system.thickness * 0.55))
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        let name = on ? "wifi" : "wifi.slash"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Wi-Fi")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
    }

    private func resizePanel() {
        guard let panel, panel.isVisible else { return }
        guard let frame = panelFrame(NSSize(width: WiFiMenuView.width, height: menuView.preferredHeight)) else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel else { return }
        place(panel)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        statusItem?.button?.highlight(true)
        installMonitors()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        statusItem?.button?.highlight(false)
        removeMonitors()
    }

    private func installMonitors() {
        removeMonitors()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated {
                AppDelegate.instance?.closeIfClickedOutside()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { event in
            let swallow: Bool = MainActor.assumeIsolated {
                if event.type == .keyDown, event.keyCode == 53 {
                    AppDelegate.instance?.hidePanel()
                    return true
                }
                AppDelegate.instance?.closeIfClickedOutside()
                return false
            }
            return swallow ? nil : event
        }
    }

    private func removeMonitors() {
        if let outsideMonitor {
            NSEvent.removeMonitor(outsideMonitor)
            self.outsideMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func closeIfClickedOutside() {
        guard panel?.isVisible == true else { return }
        let mouse = NSEvent.mouseLocation
        if let frame = panel?.frame, frame.contains(mouse) { return }
        if let anchor = statusAnchor(), anchor.insetBy(dx: -4, dy: -4).contains(mouse) { return }
        hidePanel()
    }

    private func place(_ panel: NSPanel) {
        let size = NSSize(width: WiFiMenuView.width, height: menuView.preferredHeight)
        guard let frame = panelFrame(size) else { return }
        panel.setFrame(frame, display: true)
    }

    private func panelFrame(_ size: NSSize) -> NSRect? {
        guard let anchor = statusAnchor(), let screen = screen(for: anchor) else { return nil }
        let visible = screen.visibleFrame
        var origin = NSPoint(
            x: anchor.midX - size.width / 2,
            y: anchor.minY - size.height - 5
        )
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        if origin.y < visible.minY {
            origin.y = anchor.maxY + 5
        }
        return NSRect(origin: origin, size: size)
    }

    /// Screen rect of the menu-bar icon. Control Center hosts the visible
    /// window on macOS Tahoe, so the button's own window is only a fallback.
    private func statusAnchor() -> NSRect? {
        if let hosted = controlCenterAnchor() { return hosted }
        guard let button = statusItem?.button, let window = button.window else { return nil }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard rect.width > 2, rect.height > 2 else { return nil }
        return rect
    }

    private func controlCenterAnchor() -> NSRect? {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        for window in info {
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            let name = window[kCGWindowName as String] as? String ?? ""
            guard owner == "Control Center", name == "NoWiFi" else { continue }
            guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = number(bounds["X"]),
                  let y = number(bounds["Y"]),
                  let width = number(bounds["Width"]),
                  let height = number(bounds["Height"]) else { continue }
            let screenHeight = (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main)?.frame.height ?? 0
            return NSRect(x: x, y: screenHeight - y - height, width: width, height: height)
        }
        return nil
    }

    private func screen(for rect: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main
    }

    private func number(_ value: Any?) -> CGFloat? {
        (value as? NSNumber).map { CGFloat(truncating: $0) }
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
