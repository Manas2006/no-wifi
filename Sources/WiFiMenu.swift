import AppKit

/// A visual copy of the macOS Wi-Fi menu. The switch only changes this panel
/// and the menu-bar icon. It never joins a network or touches the real radio.
final class WiFiMenuView: NSView {
    override var isFlipped: Bool { true }

    /// Called after the switch moves. `true` means the fake Wi-Fi radio is on.
    var onPowerChange: ((Bool) -> Void)?

    /// Starts off, which is the disconnected menu-bar icon.
    private(set) var isOn = false
    /// Keeps the network list drawn while the panel shrinks shut.
    private var listDrawn = false
    /// 0 is off, 1 is on. Animates between them.
    private var knob: CGFloat = 0
    private var knobTimer: Timer?

    private struct Network {
        var name: String
        var secured: Bool
    }

    private let networks = [
        Network(name: "utexas", secured: true),
        Network(name: "utguest", secured: false),
        Network(name: "utexas-iot", secured: true),
    ]

    private enum Hit: Equatable {
        case network(Int)
        case other
        case settings
    }

    private var hits: [(Hit, NSRect)] = []
    private var hovered: Hit?

    static let width: CGFloat = 312
    static let offHeight: CGFloat = 52
    static let onHeight: CGFloat = 260

    var preferredHeight: CGFloat { isOn ? Self.onHeight : Self.offHeight }

    private let inset: CGFloat = 16
    private let rowHeight: CGFloat = 32

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: preferredHeight)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hit = toggleRect().insetBy(dx: -8, dy: -10)
        guard hit.contains(point) else { return }
        setOn(!isOn)
    }

    private func setOn(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        if on {
            listDrawn = true
        }
        invalidateIntrinsicContentSize()
        animateKnob(to: on ? 1 : 0)
        onPowerChange?(on)
        guard !on else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self, !self.isOn else { return }
            self.listDrawn = false
            self.hovered = nil
            self.needsDisplay = true
        }
    }

    private func animateKnob(to target: CGFloat) {
        knobTimer?.invalidate()
        let start = knob
        let began = Date()
        let duration = 0.2
        knobTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let t = min(1, Date().timeIntervalSince(began) / duration)
            let eased = t * t * (3 - 2 * t)
            self.knob = start + (target - start) * eased
            self.needsDisplay = true
            if t >= 1 {
                timer.invalidate()
                self.knobTimer = nil
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let next = hits.first { $0.1.contains(point) }?.0
        guard next != hovered else { return }
        hovered = next
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        hits.removeAll()
        let content = bounds.insetBy(dx: inset, dy: 0)
        var y: CGFloat = 12

        let titleFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let title = "Wi-Fi" as NSString
        let titleSize = title.size(withAttributes: [.font: titleFont])
        title.draw(
            at: NSPoint(x: content.minX, y: y + (24 - titleSize.height) / 2),
            withAttributes: [
                .font: titleFont,
                .foregroundColor: NSColor.labelColor,
            ]
        )
        drawToggle(toggleRect())
        guard listDrawn else { return }
        y += 24 + 10

        drawSeparator(x: content.minX, y: y, width: content.width)
        y += 9

        let sectionFont = NSFont.systemFont(ofSize: 13, weight: .regular)
        let section = "Known Networks" as NSString
        let sectionSize = section.size(withAttributes: [.font: sectionFont])
        section.draw(
            at: NSPoint(x: content.minX, y: y),
            withAttributes: [
                .font: sectionFont,
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        y += sectionSize.height + 6

        for (index, network) in networks.enumerated() {
            let rect = NSRect(x: content.minX, y: y, width: content.width, height: rowHeight)
            hits.append((.network(index), rect.insetBy(dx: -6, dy: 0)))
            drawNetwork(network, in: rect, hovered: hovered == .network(index))
            y += rowHeight
        }

        y += 6
        drawSeparator(x: content.minX, y: y, width: content.width)
        y += 4

        let other = NSRect(x: content.minX, y: y, width: content.width, height: rowHeight)
        hits.append((.other, other.insetBy(dx: -6, dy: 0)))
        drawFooter("Other Networks", in: other, chevron: true, hovered: hovered == .other)
        y += rowHeight

        drawSeparator(x: content.minX, y: y, width: content.width)

        let settings = NSRect(x: content.minX, y: y, width: content.width, height: rowHeight)
        hits.append((.settings, settings))
        drawFooter("Wi-Fi Settings…", in: settings, chevron: false, hovered: hovered == .settings)
    }

    private func toggleRect() -> NSRect {
        let content = bounds.insetBy(dx: inset, dy: 0)
        return NSRect(x: content.maxX - 54, y: 12, width: 54, height: 24)
    }

    private func drawToggle(_ rect: NSRect) {
        let track = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        let offTrack = isDark ? NSColor(white: 0.30, alpha: 1) : NSColor(white: 0.84, alpha: 1)
        offTrack.setFill()
        track.fill()
        if knob > 0 {
            NSColor.controlAccentColor.withAlphaComponent(knob).setFill()
            track.fill()
        }

        let knobSide = rect.height - 4
        let travel = rect.width - 4 - knobSide
        let knob = NSRect(x: rect.minX + 2 + travel * knob, y: rect.minY + 2, width: knobSide, height: knobSide)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowOffset = NSSize(width: 0, height: -0.5)
        shadow.shadowBlurRadius = 1.5
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: knob).fill()
        NSShadow().set()
    }

    private func drawSeparator(x: CGFloat, y: CGFloat, width: CGFloat) {
        NSColor.separatorColor.setFill()
        NSRect(x: x, y: y, width: width, height: 1).fill()
    }

    private func drawNetwork(_ network: Network, in rect: NSRect, hovered: Bool) {
        if hovered {
            drawHover(rect.insetBy(dx: -6, dy: 1))
        }

        let circleSide: CGFloat = 22
        let circle = NSRect(
            x: rect.minX,
            y: rect.midY - circleSide / 2,
            width: circleSide,
            height: circleSide
        )
        let dark = isDark
        NSColor.labelColor.withAlphaComponent(dark ? 0.16 : 0.10).setFill()
        NSBezierPath(ovalIn: circle).fill()

        let glyphColor = NSColor.labelColor
        if let image = symbol("wifi", size: 12, weight: .semibold, color: glyphColor) {
            let side: CGFloat = 14
            image.draw(in: NSRect(
                x: circle.midX - side / 2,
                y: circle.midY - side / 2,
                width: side,
                height: side
            ))
        }

        let font = NSFont.systemFont(ofSize: 13, weight: .regular)
        let name = network.name as NSString
        let nameSize = name.size(withAttributes: [.font: font])
        name.draw(
            at: NSPoint(x: circle.maxX + 8, y: rect.midY - nameSize.height / 2),
            withAttributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ]
        )

        if network.secured, let lock = symbol("lock.fill", size: 11, weight: .regular, color: .secondaryLabelColor) {
            let side = lock.size
            lock.draw(in: NSRect(
                x: rect.maxX - side.width,
                y: rect.midY - side.height / 2,
                width: side.width,
                height: side.height
            ))
        }
    }

    private func drawFooter(_ title: String, in rect: NSRect, chevron: Bool, hovered: Bool) {
        if hovered {
            drawHover(rect.insetBy(dx: -6, dy: 1))
        }
        let font = NSFont.systemFont(ofSize: 13, weight: .regular)
        let text = title as NSString
        let size = text.size(withAttributes: [.font: font])
        text.draw(
            at: NSPoint(x: rect.minX, y: rect.midY - size.height / 2),
            withAttributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ]
        )
        if chevron, let image = symbol("chevron.right", size: 11, weight: .semibold, color: .secondaryLabelColor) {
            let side = image.size
            image.draw(in: NSRect(
                x: rect.maxX - side.width,
                y: rect.midY - side.height / 2,
                width: side.width,
                height: side.height
            ))
        }
    }

    private func drawHover(_ rect: NSRect) {
        NSColor.labelColor.withAlphaComponent(isDark ? 0.08 : 0.06).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
    }

    private var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}

final class WiFiPanel: NSPanel {
    init(view: NSView) {
        super.init(
            contentRect: NSRect(origin: .zero, size: view.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        becomesKeyOnlyIfNeeded = true
        acceptsMouseMovedEvents = true

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: view.fittingSize))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 22
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        effect.autoresizingMask = [.width, .height]

        view.frame = effect.bounds
        view.autoresizingMask = [.width, .height]
        effect.addSubview(view)
        contentView = effect
    }
}
