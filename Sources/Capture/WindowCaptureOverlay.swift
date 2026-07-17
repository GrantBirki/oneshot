import AppKit

@MainActor
final class WindowCaptureOverlayController {
    private var windows: [OverlayWindow] = []
    private let windowProvider: @MainActor () -> [WindowInfo]

    init(windowProvider: @escaping @MainActor () -> [WindowInfo] = WindowInfoProvider.windows) {
        self.windowProvider = windowProvider
    }

    func beginSelection(completion: @escaping (WindowInfo?) -> Void) {
        guard windows.isEmpty else {
            completion(nil)
            return
        }
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            completion(nil)
            return
        }

        let selectableWindows = windowProvider()
        var didFinish = false
        let finish: (WindowInfo?) -> Void = { [weak self] result in
            guard let self, !didFinish else { return }
            didFinish = true
            end()
            completion(result)
        }

        for screen in screens {
            let window = OverlayWindow(contentRect: screen.frame)
            let view = WindowCaptureOverlayView(
                frame: window.contentView?.bounds ?? .zero,
                windowInfos: selectableWindows,
                refreshWindowInfos: windowProvider,
            )
            view.onSelection = { windowInfo in
                finish(windowInfo)
            }
            view.onCancel = {
                finish(nil)
            }
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
        }

        let pointerLocation = NSEvent.mouseLocation
        let keyWindow = windows.first(where: { $0.frame.contains(pointerLocation) }) ?? windows.first
        if let keyWindow, let view = keyWindow.contentView {
            keyWindow.makeKeyAndOrderFront(nil)
            keyWindow.makeFirstResponder(view)
        }
    }

    private func end() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    func cancel() {
        end()
    }
}

@MainActor
final class WindowCaptureOverlayView: NSView {
    var onSelection: ((WindowInfo) -> Void)?
    var onCancel: (() -> Void)?

    private var highlightedWindow: WindowInfo?
    private var windowInfos: [WindowInfo]
    private let refreshWindowInfos: @MainActor () -> [WindowInfo]
    private var hoverTrackingArea: NSTrackingArea?
    private let dimmingLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        windowInfos = WindowInfoProvider.windows()
        refreshWindowInfos = WindowInfoProvider.windows
        super.init(frame: frameRect)
        configureView()
    }

    init(
        frame frameRect: NSRect,
        windowInfos: [WindowInfo],
        refreshWindowInfos: @escaping @MainActor () -> [WindowInfo],
    ) {
        self.windowInfos = windowInfos
        self.refreshWindowInfos = refreshWindowInfos
        super.init(frame: frameRect)
        configureView()
    }

    private func configureView() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        configureLayers()
        configureAccessibility()
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLayerScale()
        updateHighlight(at: NSEvent.mouseLocation)
    }

    override func layout() {
        super.layout()
        updateLayers()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let window else { return }
        window.makeKey()
        window.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: point)
        updateHighlight(at: screenPoint)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        window.makeKey()
        window.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: point)
        updateHighlight(at: screenPoint, refreshing: true)
    }

    override func mouseUp(with _: NSEvent) {
        if let windowInfo = highlightedWindow {
            onSelection?(windowInfo)
        } else {
            onCancel?()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyboardKeyCode.escape {
            onCancel?()
        } else if event.keyCode == KeyboardKeyCode.returnKey || event.keyCode == KeyboardKeyCode.keypadEnter {
            if let highlightedWindow {
                onSelection?(highlightedWindow)
            }
        }
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }

    func updateHighlight(at screenPoint: CGPoint, refreshing: Bool = false) {
        if refreshing {
            windowInfos = refreshWindowInfos()
        }
        let nextWindow: WindowInfo? = if let window, !window.frame.contains(screenPoint) {
            nil
        } else {
            WindowInfoProvider.window(at: screenPoint, in: windowInfos)
        }
        guard nextWindow != highlightedWindow else { return }
        highlightedWindow = nextWindow
        updateLayers()
        updateAccessibilityValue()
        if let nextWindow {
            AccessibilityAnnouncer.announce("Selected \(nextWindow.accessibilityName)")
        }
    }

    private func configureLayers() {
        dimmingLayer.fillColor = NSColor.black.withAlphaComponent(0.25).cgColor
        dimmingLayer.fillRule = .evenOdd

        highlightLayer.fillColor = nil
        highlightLayer.strokeColor = NSColor.systemBlue.cgColor
        highlightLayer.lineWidth = 2
        highlightLayer.isHidden = true

        layer?.addSublayer(dimmingLayer)
        layer?.addSublayer(highlightLayer)
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Window capture overlay")
        setAccessibilityHelp(
            "Move the pointer over a window and click or press Return to capture it. Press Escape to cancel.",
        )
        updateAccessibilityValue()
    }

    private func updateLayerScale() {
        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0
        dimmingLayer.contentsScale = scale
        highlightLayer.contentsScale = scale
    }

    private func updateLayers() {
        guard layer != nil else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        dimmingLayer.frame = bounds
        highlightLayer.frame = bounds

        let highlight = highlightRect()
        if let dimmingPath = OverlayPathBuilder.dimmingPath(for: highlight, in: bounds, mode: .fullScreen) {
            dimmingLayer.path = dimmingPath
            dimmingLayer.isHidden = false
        } else {
            dimmingLayer.path = nil
            dimmingLayer.isHidden = true
        }
        if let highlight {
            highlightLayer.path = CGPath(rect: highlight, transform: nil)
            highlightLayer.isHidden = false
        } else {
            highlightLayer.path = nil
            highlightLayer.isHidden = true
        }

        CATransaction.commit()
    }

    private func highlightRect() -> CGRect? {
        guard let highlight = highlightedWindow?.bounds, let window else { return nil }
        return window.convertFromScreen(highlight)
    }

    private func updateAccessibilityValue() {
        setAccessibilityValue(highlightedWindow?.accessibilityName ?? "No window selected")
    }
}

struct WindowInfo: Equatable {
    let id: CGWindowID
    let bounds: CGRect
    let ownerName: String?
    let title: String?

    init(id: CGWindowID, bounds: CGRect, ownerName: String? = nil, title: String? = nil) {
        self.id = id
        self.bounds = bounds
        self.ownerName = ownerName
        self.title = title
    }

    var accessibilityName: String {
        switch (ownerName?.nonEmpty, title?.nonEmpty) {
        case let (.some(owner), .some(title)):
            "\(owner): \(title)"
        case let (.some(owner), .none):
            owner
        case let (.none, .some(title)):
            title
        case (.none, .none):
            "Window selected"
        }
    }
}

@MainActor
enum WindowInfoProvider {
    static func window(at point: CGPoint) -> WindowInfo? {
        window(at: point, in: windows())
    }

    static func window(at point: CGPoint, in windows: [WindowInfo]) -> WindowInfo? {
        windows.first { $0.bounds.contains(point) }
    }

    static func windows() -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID,
        ) as? [[String: Any]] else {
            return []
        }

        let currentPID = getpid()

        return list.compactMap { info in
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let cgBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  let bounds = appKitBounds(for: cgBounds),
                  let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != currentPID
            else {
                return nil
            }

            if let alpha = info[kCGWindowAlpha as String] as? CGFloat, alpha == 0 {
                return nil
            }

            if let layer = info[kCGWindowLayer as String] as? Int, layer != 0 {
                return nil
            }

            return WindowInfo(
                id: windowID,
                bounds: bounds,
                ownerName: info[kCGWindowOwnerName as String] as? String,
                title: info[kCGWindowName as String] as? String,
            )
        }
    }

    private static func appKitBounds(for cgBounds: CGRect) -> CGRect? {
        guard let screen = screen(for: cgBounds),
              let displayID = displayID(for: screen)
        else {
            return nil
        }
        let cgScreenFrame = CGDisplayBounds(displayID)
        let localX = cgBounds.origin.x - cgScreenFrame.origin.x
        let localY = cgBounds.origin.y - cgScreenFrame.origin.y
        let flippedY = cgScreenFrame.height - localY - cgBounds.height
        return CGRect(
            x: screen.frame.origin.x + localX,
            y: screen.frame.origin.y + flippedY,
            width: cgBounds.width,
            height: cgBounds.height,
        )
    }

    private static func screen(for cgBounds: CGRect) -> NSScreen? {
        let center = CGPoint(x: cgBounds.midX, y: cgBounds.midY)
        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen) else { continue }
            if CGDisplayBounds(displayID).contains(center) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber {
            return CGDirectDisplayID(number.uint32Value)
        }
        return nil
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
