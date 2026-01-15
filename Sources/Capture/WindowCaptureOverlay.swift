import AppKit

final class WindowCaptureOverlayController {
    private var window: NSWindow?

    func beginSelection(completion: @escaping (WindowInfo?) -> Void) {
        guard let frame = ScreenFrameHelper.allScreensFrame() else {
            completion(nil)
            return
        }

        let window = OverlayWindow(contentRect: frame)
        let view = WindowCaptureOverlayView(frame: window.contentView?.bounds ?? frame)
        view.onSelection = { [weak self] windowInfo in
            self?.end()
            completion(windowInfo)
        }
        view.onCancel = { [weak self] in
            self?.end()
            completion(nil)
        }
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        self.window = window
    }

    private func end() {
        window?.orderOut(nil)
        window = nil
    }
}

final class WindowCaptureOverlayView: NSView {
    var onSelection: ((WindowInfo) -> Void)?
    var onCancel: (() -> Void)?

    private var highlightedWindow: WindowInfo?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateHighlight(at: NSEvent.mouseLocation)
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

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        dirtyRect.fill()

        if let highlight = highlightedWindow?.bounds, let window {
            let localRect = window.convertFromScreen(highlight)
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.setBlendMode(.clear)
            context.fill(localRect)
            context.setBlendMode(.normal)

            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: localRect)
            path.lineWidth = 2
            path.stroke()
        }
    }

    private func updateHighlight(at screenPoint: CGPoint) {
        highlightedWindow = WindowInfoProvider.window(at: screenPoint)
        needsDisplay = true
    }
}

struct WindowInfo {
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
