import AppKit

final class SelectionOverlayController {
    private var window: NSWindow?

    struct SelectionResult {
        let rect: CGRect
        let excludeWindowID: CGWindowID?
    }

    func beginSelection(completion: @escaping (SelectionResult?) -> Void) {
        guard let frame = ScreenFrameHelper.allScreensFrame() else {
            completion(nil)
            return
        }

        let window = OverlayWindow(contentRect: frame)
        let view = SelectionOverlayView(frame: window.contentView?.bounds ?? frame)
        var windowID: CGWindowID = 0
        view.onSelection = { [weak self] rect in
            self?.end()
            completion(SelectionResult(rect: rect, excludeWindowID: windowID))
        }
        view.onCancel = { [weak self] in
            self?.end()
            completion(nil)
        }
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        windowID = CGWindowID(window.windowNumber)
        self.window = window
    }

    private func end() {
        window?.orderOut(nil)
        window = nil
    }
}

final class SelectionOverlayView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        dragCurrent = dragStart
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        dragCurrent = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart, let end = dragCurrent, let window = window else {
            onCancel?()
            return
        }

        let startScreen = window.convertPoint(toScreen: start)
        let endScreen = window.convertPoint(toScreen: end)
        let rect = CGRect(
            x: min(startScreen.x, endScreen.x),
            y: min(startScreen.y, endScreen.y),
            width: abs(startScreen.x - endScreen.x),
            height: abs(startScreen.y - endScreen.y)
        )

        if rect.width < 2 || rect.height < 2 {
            onCancel?()
        } else {
            onSelection?(rect)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        dirtyRect.fill()

        if let selection = selectionRect() {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.setBlendMode(.clear)
            context.fill(selection)
            context.setBlendMode(.normal)

            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: selection)
            path.lineWidth = 2
            path.stroke()
        }
    }

    private func selectionRect() -> CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(start.x - current.x),
            height: abs(start.y - current.y)
        )
    }
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}

enum ScreenFrameHelper {
    static func allScreensFrame() -> CGRect? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        return screens.reduce(CGRect.null) { $0.union($1.frame) }
    }
}
