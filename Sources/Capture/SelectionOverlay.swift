import AppKit
import os.log

final class SelectionOverlayController {
    private var windows: [OverlayWindow] = []
    private var views: [SelectionOverlayView] = []
    private var selectionState: SelectionOverlayState?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?
    private let log = OSLog(subsystem: "com.grantbirki.oneshot", category: "SelectionOverlay")

    private enum KeyCodes {
        static let escape: UInt16 = 53
    }

    init() {}

    struct SelectionResult {
        let rect: CGRect
        let excludeWindowID: CGWindowID?
    }

    func beginSelection(showSelectionCoordinates: Bool, completion: @escaping (SelectionResult?) -> Void) {
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
        let state = SelectionOverlayState(showSelectionCoordinates: showSelectionCoordinates)
        selectionState = state
        let refreshViews: () -> Void = { [weak self] in
            guard let self else { return }
            views.forEach { $0.updateOverlay() }
        }
        let mouseLocation = NSEvent.mouseLocation
        var didSetKeyWindow = false

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
            window.orderFrontRegardless()
            if screen.frame.contains(mouseLocation) {
                window.makeKeyAndOrderFront(nil)
                didSetKeyWindow = true
                #if DEBUG
                os_log(
                    "made key window %{public}d for screen %{public}@, appActive=%{public}@",
                    log: log,
                    type: .debug,
                    window.windowNumber,
                    "\(screen.frame)",
                    "\(NSApp.isActive)"
                )
                #endif
            }
            window.makeFirstResponder(view)
            windowID = CGWindowID(window.windowNumber)
            windows.append(window)
            views.append(view)
        }

        if !didSetKeyWindow {
            windows.first?.makeKeyAndOrderFront(nil)
            #if DEBUG
            if let window = windows.first, let screen = screens.first {
                os_log(
                    "default key window %{public}d for screen %{public}@, appActive=%{public}@",
                    log: log,
                    type: .debug,
                    window.windowNumber,
                    "\(screen.frame)",
                    "\(NSApp.isActive)"
                )
            }
            #endif
        }
        // Ensure a key window is set for event handling.
        if let keyWindow = windows.first(where: { $0.isKeyWindow }) ?? windows.first {
            keyWindow.makeKeyAndOrderFront(nil)
            #if DEBUG
            os_log(
                "reassert key window %{public}d appActive=%{public}@",
                log: log,
                type: .debug,
                keyWindow.windowNumber,
                "\(NSApp.isActive)"
            )
            #endif
        }

        startKeyMonitor(onCancel: { finish(nil) })
    }

    private func end() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        views.removeAll()
        selectionState = nil
        stopKeyMonitor()
    }

    private func startKeyMonitor(onCancel: @escaping () -> Void) {
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                if event.keyCode == KeyCodes.escape {
                    onCancel()
                    return nil
                }
                return event
            }
        }

        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
                DispatchQueue.main.async {
                    if event.keyCode == KeyCodes.escape {
                        onCancel()
                    }
                }
            }
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil

        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalKeyMonitor = nil
    }
}

final class SelectionOverlayView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    var onSelectionChanged: (() -> Void)?
    private let state: SelectionOverlayState
    private let dimmingLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let metricsBackgroundLayer = CAShapeLayer()
    private let metricsTextLayer = CATextLayer()
    private let metricsFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    private let log = OSLog(subsystem: "com.grantbirki.oneshot", category: "SelectionOverlayView")

    init(frame frameRect: NSRect, state: SelectionOverlayState) {
        self.state = state
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        configureLayers()
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLayerScale()
        updateOverlay()
        #if DEBUG
        os_log(
            "viewDidMoveToWindow window=%{public}@ key=%{public}@ main=%{public}@",
            log: log,
            type: .debug,
            window?.description ?? "nil",
            "\(window?.isKeyWindow ?? false)",
            "\(window?.isMainWindow ?? false)"
        )
        #endif
    }

    override func layout() {
        super.layout()
        updateOverlay()
    }

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

    func updateOverlay() {
        guard layer != nil else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        dimmingLayer.frame = bounds
        borderLayer.frame = bounds
        metricsBackgroundLayer.frame = bounds

        let selection = selectionRect()
        if let dimmingPath = OverlayPathBuilder.innerDimmingPath(for: selection) {
            dimmingLayer.path = dimmingPath
            dimmingLayer.isHidden = false
        } else {
            dimmingLayer.path = nil
            dimmingLayer.isHidden = true
        }
        if let selection {
            borderLayer.path = CGPath(rect: selection, transform: nil)
            borderLayer.isHidden = false
        } else {
            borderLayer.path = nil
            borderLayer.isHidden = true
        }

        updateMetrics()

        CATransaction.commit()
    }

    private func configureLayers() {
        dimmingLayer.fillColor = NSColor.black.withAlphaComponent(0.35).cgColor

        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor(calibratedWhite: 0.92, alpha: 1).cgColor
        borderLayer.lineWidth = 1
        borderLayer.isHidden = true

        metricsBackgroundLayer.fillColor = NSColor.black.withAlphaComponent(0.75).cgColor
        metricsBackgroundLayer.isHidden = true

        metricsTextLayer.font = metricsFont
        metricsTextLayer.fontSize = metricsFont.pointSize
        metricsTextLayer.foregroundColor = NSColor.white.cgColor
        metricsTextLayer.alignmentMode = .left
        metricsTextLayer.isWrapped = false
        metricsTextLayer.isHidden = true

        layer?.addSublayer(dimmingLayer)
        layer?.addSublayer(borderLayer)
        layer?.addSublayer(metricsBackgroundLayer)
        layer?.addSublayer(metricsTextLayer)
    }

    private func updateLayerScale() {
        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0
        dimmingLayer.contentsScale = scale
        borderLayer.contentsScale = scale
        metricsBackgroundLayer.contentsScale = scale
        metricsTextLayer.contentsScale = scale
    }

    private func updateMetrics() {
        guard let window,
              let current = state.current,
              let text = state.selectionSizeText
        else {
            metricsBackgroundLayer.isHidden = true
            metricsTextLayer.isHidden = true
            metricsTextLayer.string = nil
            return
        }

        let anchor = window.convertPoint(fromScreen: current)
        guard bounds.contains(anchor) else {
            metricsBackgroundLayer.isHidden = true
            metricsTextLayer.isHidden = true
            metricsTextLayer.string = nil
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: metricsFont, .foregroundColor: NSColor.white]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        let padding = CGSize(width: 6, height: 4)
        let offset = CGPoint(x: 12, y: 12)
        var bubbleRect = CGRect(
            x: anchor.x + offset.x,
            y: anchor.y + offset.y,
            width: textSize.width + padding.width * 2,
            height: textSize.height + padding.height * 2,
        )
        bubbleRect = clamp(bubbleRect, to: bounds, margin: 8)

        metricsBackgroundLayer.path = CGPath(
            roundedRect: bubbleRect,
            cornerWidth: 6,
            cornerHeight: 6,
            transform: nil,
        )
        metricsBackgroundLayer.isHidden = false

        metricsTextLayer.string = attributedText
        metricsTextLayer.frame = CGRect(
            x: bubbleRect.minX + padding.width,
            y: bubbleRect.minY + padding.height,
            width: textSize.width,
            height: textSize.height,
        )
        metricsTextLayer.isHidden = false
    }

    private func clamp(_ rect: CGRect, to bounds: CGRect, margin: CGFloat) -> CGRect {
        var rect = rect
        rect.origin.x = min(max(rect.origin.x, bounds.minX + margin), bounds.maxX - rect.width - margin)
        rect.origin.y = min(max(rect.origin.y, bounds.minY + margin), bounds.maxY - rect.height - margin)
        return rect
    }

    private func selectionRect() -> CGRect? {
        guard let rect = state.rect, let window else { return nil }
        return window.convertFromScreen(rect)
    }
}
