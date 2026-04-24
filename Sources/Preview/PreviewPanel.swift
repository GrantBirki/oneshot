import AppKit

@MainActor
final class PreviewPanel: NSPanel {
    private let content: PreviewContentView
    private var keyMonitor: EventMonitor?
    private var globalKeyMonitor: EventMonitor?

    private enum Layout {
        static let padding: CGFloat = 16
        static let desiredPixelSize = CGSize(width: 600, height: 500)
    }

    init(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        onClose: @escaping () -> Void,
        onTrash: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onDragChanged: @escaping (Bool) -> Void,
    ) {
        let size = PreviewPanel.defaultSize()
        content = PreviewContentView(frame: NSRect(origin: .zero, size: size))
        content.autoresizingMask = [.width, .height]
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let configuration = PreviewContentConfiguration(
            image: image,
            pngData: pngData,
            filenamePrefix: filenamePrefix,
            onClose: onClose,
            onTrash: onTrash,
            onOpen: onOpen,
            onHoverChanged: onHoverChanged,
            onDragChanged: onDragChanged,
        )
        content.configure(with: configuration)
        contentView = content
    }

    func show(on screen: NSScreen?) {
        guard let screen = screen ?? PreviewPanel.targetScreen() else {
            center()
            makeKeyAndOrderFront(nil)
            startKeyMonitor()
            return
        }

        let safeFrame = PreviewPanel.safeFrame(for: screen)
        let padding = Layout.padding
        let availableSize = NSSize(
            width: max(safeFrame.width - padding * 2, 1),
            height: max(safeFrame.height - padding * 2, 1),
        )
        let desiredSize = PreviewPanel.desiredSize(for: screen)
        let targetSize = NSSize(
            width: min(desiredSize.width, availableSize.width),
            height: min(desiredSize.height, availableSize.height),
        )
        let contentRect = NSRect(origin: .zero, size: targetSize)
        content.frame = contentRect
        setContentSize(targetSize)

        let frame = frameRect(forContentRect: contentRect)
        var origin = CGPoint(
            x: safeFrame.maxX - frame.width - padding,
            y: safeFrame.minY + padding,
        )

        let minX = safeFrame.minX + padding
        let maxX = safeFrame.maxX - frame.width - padding
        let minY = safeFrame.minY + padding
        let maxY = safeFrame.maxY - frame.height - padding

        origin.x = maxX < minX ? minX : min(max(origin.x, minX), maxX)
        origin.y = maxY < minY ? minY : min(max(origin.y, minY), maxY)

        contentMinSize = targetSize
        contentMaxSize = targetSize
        minSize = frame.size
        maxSize = frame.size

        let targetFrame = NSRect(origin: origin, size: frame.size)
        setFrame(targetFrame, display: false)
        orderFrontRegardless()
        // AppKit can apply intrinsic sizing on first display; re-apply the fixed frame.
        setFrame(targetFrame, display: false)
        startKeyMonitor()
    }

    override func close() {
        stopKeyMonitor()
        super.close()
    }

    private func startKeyMonitor() {
        if keyMonitor == nil {
            keyMonitor = EventMonitor(NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                let keyCode = event.keyCode
                let modifiers = event.modifierFlags
                let handled = MainActor.assumeIsolated {
                    guard let self else { return false }
                    return self.handleKeyCode(keyCode, modifiers: modifiers)
                }
                return handled ? nil : event
            })
        }

        if globalKeyMonitor == nil {
            let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                let keyCode = event.keyCode
                let modifiers = event.modifierFlags
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard !NSApp.isActive else { return }
                    _ = handleKeyCode(keyCode, modifiers: modifiers)
                }
            }
            globalKeyMonitor = EventMonitor(monitor)
        }
    }

    private func stopKeyMonitor() {
        keyMonitor?.cancel()
        keyMonitor = nil

        globalKeyMonitor?.cancel()
        globalKeyMonitor = nil
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        handleKeyCode(event.keyCode, modifiers: event.modifierFlags)
    }

    private func handleKeyCode(_ keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard isVisible else { return false }
        if keyCode == KeyboardKeyCode.escape {
            content.performClose()
            return true
        }
        if keyCode == KeyboardKeyCode.returnKey || keyCode == KeyboardKeyCode.keypadEnter {
            content.performOpen()
            return true
        }
        if keyCode == KeyboardKeyCode.delete, modifiers.contains(.command) {
            content.performTrash()
            return true
        }
        return false
    }

    private static func desiredSize(for screen: NSScreen) -> NSSize {
        let rect = NSRect(origin: .zero, size: Layout.desiredPixelSize)
        return screen.convertRectFromBacking(rect).size
    }

    private static func defaultSize() -> NSSize {
        if let screen = NSScreen.main {
            return desiredSize(for: screen)
        }
        return NSSize(
            width: Layout.desiredPixelSize.width,
            height: Layout.desiredPixelSize.height,
        )
    }

    static func screen(for rect: CGRect?) -> NSScreen? {
        guard let rect else {
            return targetScreen()
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let best = screens.max { lhs, rhs in
            rect.intersection(lhs.frame).area < rect.intersection(rhs.frame).area
        }

        if let best, rect.intersection(best.frame).area > 0 {
            return best
        }

        return targetScreen()
    }

    private static func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private static func safeFrame(for screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        if visible.width > 0, visible.height > 0 {
            return visible
        }
        return screen.frame
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}
