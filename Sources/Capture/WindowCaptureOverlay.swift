import AppKit

final class WindowCaptureOverlayController {
    private var windows: [OverlayWindow] = []
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?

    private enum KeyCodes {
        static let escape: UInt16 = 53
    }

    func beginSelection(completion: @escaping (WindowInfo?) -> Void) {
        guard windows.isEmpty else { return }
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            completion(nil)
            return
        }

        var didFinish = false
        let finish: (WindowInfo?) -> Void = { [weak self] result in
            guard let self, !didFinish else { return }
            didFinish = true
            end()
            completion(result)
        }

        for screen in screens {
            let window = OverlayWindow(contentRect: screen.frame)
            let view = WindowCaptureOverlayView(frame: window.contentView?.bounds ?? .zero)
            view.onSelection = { windowInfo in
                finish(windowInfo)
            }
            view.onCancel = {
                finish(nil)
            }
            window.contentView = view
            window.orderFrontRegardless()
            window.makeFirstResponder(view)
            windows.append(window)
        }

        startKeyMonitor(onCancel: { finish(nil) })
    }

    private func end() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
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
                    guard !NSApp.isActive else { return }
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

final class WindowCaptureOverlayView: NSView {
    var onSelection: ((WindowInfo) -> Void)?
    var onCancel: (() -> Void)?

    private var highlightedWindow: WindowInfo?
    private var hoverTrackingArea: NSTrackingArea?
    private let dimmingLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
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

    override func mouseMoved(with event: NSEvent) {
        guard let window else { return }
        let point = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: point)
        updateHighlight(at: screenPoint)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let point = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: point)
        updateHighlight(at: screenPoint)
    }

    override func mouseUp(with _: NSEvent) {
        if let windowInfo = highlightedWindow {
            onSelection?(windowInfo)
        } else {
            onCancel?()
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

    private func updateHighlight(at screenPoint: CGPoint) {
        let nextWindow = WindowInfoProvider.window(at: screenPoint)
        guard nextWindow != highlightedWindow else { return }
        highlightedWindow = nextWindow
        updateLayers()
    }

    private func configureLayers() {
        dimmingLayer.fillColor = NSColor.black.withAlphaComponent(0.25).cgColor

        highlightLayer.fillColor = nil
        highlightLayer.strokeColor = NSColor.systemBlue.cgColor
        highlightLayer.lineWidth = 2
        highlightLayer.isHidden = true

        layer?.addSublayer(dimmingLayer)
        layer?.addSublayer(highlightLayer)
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
        if let dimmingPath = OverlayPathBuilder.dimmingPath(for: highlight, in: bounds, mode: .selectionOnly) {
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
}

struct WindowInfo: Equatable {
    let id: CGWindowID
    let bounds: CGRect
}

enum WindowInfoProvider {
    static func window(at point: CGPoint) -> WindowInfo? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID,
        ) as? [[String: Any]] else {
            return nil
        }

        let currentPID = getpid()

        for info in list {
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let cgBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  let bounds = appKitBounds(for: cgBounds),
                  bounds.contains(point),
                  let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != currentPID
            else {
                continue
            }

            if let alpha = info[kCGWindowAlpha as String] as? CGFloat, alpha == 0 {
                continue
            }

            if let layer = info[kCGWindowLayer as String] as? Int, layer != 0 {
                continue
            }

            return WindowInfo(id: windowID, bounds: bounds)
        }

        return nil
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
