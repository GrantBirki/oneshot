import AppKit

final class SelectionOverlayController {
    private var windows: [OverlayWindow] = []
    private var views: [SelectionOverlayView] = []
    private var selectionState: SelectionOverlayState?

    struct SelectionResult {
        let rect: CGRect
        let excludeWindowID: CGWindowID?
    }

    func beginSelection(completion: @escaping (SelectionResult?) -> Void) {
        guard windows.isEmpty else { return }
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            completion(nil)
            return
        }

        var didFinish = false
        let finish: (SelectionResult?) -> Void = { [weak self] result in
            guard let self, !didFinish else { return }
            didFinish = true
            end()
            completion(result)
        }
        let state = SelectionOverlayState()
        selectionState = state
        let refreshViews: () -> Void = { [weak self] in
            guard let self else { return }
            views.forEach { $0.needsDisplay = true }
        }

        for screen in screens {
            let window = OverlayWindow(contentRect: screen.frame)
            let view = SelectionOverlayView(frame: window.contentView?.bounds ?? .zero, state: state)
            var windowID: CGWindowID = 0
            view.onSelectionChanged = refreshViews
            view.onSelection = { rect in
                finish(SelectionResult(rect: rect, excludeWindowID: windowID))
            }
            view.onCancel = {
                finish(nil)
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            windowID = CGWindowID(window.windowNumber)
            windows.append(window)
            views.append(view)
        }
    }

    private func end() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        views.removeAll()
        selectionState = nil
    }
}

final class SelectionOverlayState {
    var start: CGPoint?
    var current: CGPoint?

    var rect: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(start.x - current.x),
            height: abs(start.y - current.y),
        )
    }
}

final class SelectionOverlayView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    var onSelectionChanged: (() -> Void)?
    private let state: SelectionOverlayState

    init(frame frameRect: NSRect, state: SelectionOverlayState) {
        self.state = state
        super.init(frame: frameRect)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let point = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: point)
        state.start = screenPoint
        state.current = screenPoint
        onSelectionChanged?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let point = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: point)
        state.current = screenPoint
        onSelectionChanged?()
    }

    override func mouseUp(with event: NSEvent) {
        guard let window else {
            onCancel?()
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        state.current = window.convertPoint(toScreen: point)
        onSelectionChanged?()
        guard let rect = state.rect else {
            onCancel?()
            return
        }

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

    override func cancelOperation(_: Any?) {
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
        guard let rect = state.rect, let window else { return nil }
        return window.convertFromScreen(rect)
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
            defer: false,
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
