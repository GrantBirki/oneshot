import AppKit

@MainActor
final class PreviewPanel: NSPanel {
    private let content: PreviewContentView
    private let imageSize: NSSize
    private var keyMonitor: EventMonitor?

    private enum Layout {
        static let padding: CGFloat = 16
        static let minimumSize = NSSize(width: 160, height: 120)
        static let maximumSize = NSSize(width: 300, height: 250)
        static let maximumScreenFraction: CGFloat = 0.4
    }

    init(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        onSave: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onSaveAs: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onDragChanged: @escaping (Bool) -> Void,
    ) {
        imageSize = image.size
        let size = Layout.maximumSize
        content = PreviewContentView(frame: NSRect(origin: .zero, size: size))
        content.autoresizingMask = [.width, .height]
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
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
            onSave: onSave,
            onDiscard: onDiscard,
            onOpen: onOpen,
            onSaveAs: onSaveAs,
            onCopy: onCopy,
            onHoverChanged: onHoverChanged,
            onDragChanged: onDragChanged,
        )
        content.configure(with: configuration)
        contentView = content
    }

    override var canBecomeKey: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            makeKey()
        }
        super.sendEvent(event)
    }

    func show(on screen: NSScreen?) {
        guard let screen = screen ?? PreviewPanel.targetScreen() else {
            center()
            orderFrontRegardless()
            startKeyMonitor()
            return
        }

        let safeFrame = PreviewPanel.safeFrame(for: screen)
        let padding = Layout.padding
        let availableSize = NSSize(
            width: max(safeFrame.width - padding * 2, 1),
            height: max(safeFrame.height - padding * 2, 1),
        )
        let screenMaximum = NSSize(
            width: min(Layout.maximumSize.width, safeFrame.width * Layout.maximumScreenFraction),
            height: min(Layout.maximumSize.height, safeFrame.height * Layout.maximumScreenFraction),
        )
        let targetSize = PreviewPanel.preferredSize(
            imageSize: imageSize,
            minimumSize: Layout.minimumSize,
            maximumSize: NSSize(
                width: min(screenMaximum.width, availableSize.width),
                height: min(screenMaximum.height, availableSize.height),
            ),
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
        setFrame(targetFrame, display: false)
        startKeyMonitor()
    }

    override func close() {
        stopKeyMonitor()
        super.close()
    }

    func showRecovery(message: String, onRetry: @escaping () -> Void) {
        content.showRecovery(message: message, onRetry: onRetry)
    }

    func showOpenRecovery(
        message: String,
        onRetryOpen: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
    ) {
        content.showOpenRecovery(
            message: message,
            onRetryOpen: onRetryOpen,
            onReveal: onReveal,
            onDismiss: onDismiss,
        )
    }

    func clearRecovery() {
        content.clearRecovery()
    }

    func showStatus(message: String) {
        content.showStatus(message: message)
    }

    func setBusy(_ busy: Bool) {
        content.setBusy(busy)
    }

    func setSavedState(_ saved: Bool) {
        content.setSavedState(saved)
    }

    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = EventMonitor(NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self, self.isKeyWindow else { return false }
                return self.handleKeyCode(event.keyCode, modifiers: event.modifierFlags)
            }
            return handled ? nil : event
        })
    }

    private func stopKeyMonitor() {
        keyMonitor?.cancel()
        keyMonitor = nil
    }

    private func handleKeyCode(_ keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard isVisible, isKeyWindow else { return false }
        if keyCode == KeyboardKeyCode.escape {
            content.performSave()
            return true
        }
        if keyCode == KeyboardKeyCode.returnKey || keyCode == KeyboardKeyCode.keypadEnter {
            content.performOpen()
            return true
        }
        if keyCode == KeyboardKeyCode.delete, modifiers.contains(.command) {
            content.performDiscard()
            return true
        }
        return false
    }

    static func preferredSize(
        imageSize: NSSize,
        minimumSize: NSSize,
        maximumSize: NSSize,
    ) -> NSSize {
        let maximumWidth = max(maximumSize.width, 1)
        let maximumHeight = max(maximumSize.height, 1)
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: maximumWidth, height: maximumHeight)
        }

        let imageAspect = imageSize.width / imageSize.height
        var width = maximumWidth
        var height = width / imageAspect
        if height > maximumHeight {
            height = maximumHeight
            width = height * imageAspect
        }

        return NSSize(
            width: min(max(width, min(minimumSize.width, maximumWidth)), maximumWidth),
            height: min(max(height, min(minimumSize.height, maximumHeight)), maximumHeight),
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
