import AppKit

@MainActor
final class ScrollingCaptureOverlayController {
    private var windows: [OverlayWindow] = []
    private var views: [ScrollingSelectionOverlayView] = []
    private var stopPanel: StopCapturePanel?
    private let stopButtonSize = NSSize(width: 112, height: 44)

    func show(selectionRect: CGRect, onStop: @escaping () -> Void) {
        hide()
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        for screen in screens {
            let window = OverlayWindow(contentRect: screen.frame)
            window.ignoresMouseEvents = true
            let view = ScrollingSelectionOverlayView(
                frame: window.contentView?.bounds ?? .zero,
                selectionRect: selectionRect,
            )
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
            views.append(view)
        }

        stopPanel = makeStopPanel(for: selectionRect, onStop: onStop)
        stopPanel?.orderFrontRegardless()
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        views.removeAll()
        stopPanel?.orderOut(nil)
        stopPanel = nil
    }

    private func makeStopPanel(for selectionRect: CGRect, onStop: @escaping () -> Void) -> StopCapturePanel? {
        guard let screen = screenContaining(selectionRect) else { return nil }
        let panelFrame = stopPanelFrame(for: selectionRect, in: screen.visibleFrame)
        return StopCapturePanel(contentRect: panelFrame, onStop: onStop)
    }

    private func stopPanelFrame(for selectionRect: CGRect, in bounds: CGRect) -> CGRect {
        let preferred = CGRect(
            x: selectionRect.maxX - stopButtonSize.width,
            y: selectionRect.maxY + 12,
            width: stopButtonSize.width,
            height: stopButtonSize.height,
        )
        return clamp(preferred, to: bounds, margin: 8)
    }

    private func clamp(_ rect: CGRect, to bounds: CGRect, margin: CGFloat) -> CGRect {
        var rect = rect
        rect.origin.x = min(max(rect.origin.x, bounds.minX + margin), bounds.maxX - rect.width - margin)
        rect.origin.y = min(max(rect.origin.y, bounds.minY + margin), bounds.maxY - rect.height - margin)
        return rect
    }

    private func screenContaining(_ rect: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let direct = screens.first(where: { $0.frame.contains(center) }) {
            return direct
        }
        return screens.max(by: { intersectionArea(rect, $0.frame) < intersectionArea(rect, $1.frame) })
    }

    private func intersectionArea(_ rect: CGRect, _ frame: CGRect) -> CGFloat {
        let intersection = rect.intersection(frame)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}

@MainActor
final class ScrollingSelectionOverlayView: NSView {
    private let selectionRect: CGRect

    init(frame frameRect: NSRect, selectionRect: CGRect) {
        self.selectionRect = selectionRect
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Scrolling capture region")
        setAccessibilityHelp("This region is being captured while you scroll. Use Stop Scrolling Capture to finish.")
        setAccessibilityValue("\(Int(selectionRect.width.rounded())) by \(Int(selectionRect.height.rounded()))")
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let window else { return }
        let rectInWindow = selectionRect.offsetBy(dx: -window.frame.origin.x, dy: -window.frame.origin.y)
        guard rectInWindow.intersects(bounds) else { return }

        let path = NSBezierPath(rect: rectInWindow)
        NSColor.systemRed.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}

@MainActor
final class StopCapturePanel: NSPanel {
    init(contentRect: CGRect, onStop: @escaping () -> Void) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = StopCaptureButtonView(onStop: onStop)
        setAccessibilityElement(false)
    }
}

@MainActor
final class StopCaptureButtonView: NSView {
    private let onStop: () -> Void
    private let glassView = NSGlassEffectView()
    private let button: NSButton
    private let contentStack = NSStackView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Stop")

    init(onStop: @escaping () -> Void) {
        self.onStop = onStop
        button = NSButton(frame: .zero)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 6
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        glassView.style = .regular
        glassView.tintColor = .systemRed
        glassView.cornerRadius = 18

        button.isBordered = false
        button.title = ""
        if let image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil) {
            iconView.image = image.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold),
            )
        }
        button.target = self
        button.action = #selector(stopPressed)
        button.setAccessibilityLabel("Stop scrolling capture")
        button.setAccessibilityHelp("Finish scrolling capture and create the stitched screenshot.")

        iconView.contentTintColor = .white
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        iconView.setFrameSize(NSSize(width: 12, height: 12))

        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center

        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.distribution = .gravityAreas
        contentStack.spacing = 8
        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(titleLabel)

        addSubview(glassView)
        addSubview(contentStack)
        addSubview(button)
        setAccessibilityElement(false)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        glassView.frame = bounds
        let contentSize = contentStack.fittingSize
        contentStack.frame = NSRect(
            x: (bounds.width - contentSize.width) / 2,
            y: (bounds.height - contentSize.height) / 2,
            width: contentSize.width,
            height: contentSize.height,
        )
        button.frame = bounds
    }

    @objc private func stopPressed() {
        onStop()
    }
}
