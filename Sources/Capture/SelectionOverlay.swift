import AppKit

@MainActor
final class SelectionOverlayController {
    private var windows: [OverlayWindow] = []
    private var views: [SelectionOverlayView] = []
    private var keyMonitor: EventMonitor?
    private var globalKeyMonitor: EventMonitor?

    init() {}

    struct SelectionResult {
        let rect: CGRect
        let excludeWindowID: CGWindowID?
    }

    func beginSelection(
        showSelectionCoordinates: Bool,
        visualCue: SelectionVisualCue,
        dimmingMode: SelectionDimmingMode,
        selectionDimmingColor: NSColor,
        completion: @escaping (SelectionResult?) -> Void,
    ) {
        guard windows.isEmpty else {
            completion(nil)
            return
        }
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
        let state = SelectionOverlayState(
            showSelectionCoordinates: showSelectionCoordinates,
            dimmingMode: dimmingMode,
            selectionDimmingColor: selectionDimmingColor,
        )
        let refreshViews: () -> Void = { [weak self] in
            guard let self else { return }
            views.forEach { $0.updateOverlay() }
        }
        let mouseLocation = NSEvent.mouseLocation

        let didSetKeyWindow = buildOverlayWindows(
            screens: screens,
            state: state,
            mouseLocation: mouseLocation,
            refreshViews: refreshViews,
            finish: finish,
        )

        ensureKeyWindow(screens: screens, didSetKeyWindow: didSetKeyWindow)

        startKeyMonitor(onCancel: { finish(nil) })
        if visualCue == .pulse {
            views.forEach { $0.showSelectionPulse(at: mouseLocation) }
        }
    }

    private func end() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        views.removeAll()
        stopKeyMonitor()
    }

    private func startKeyMonitor(onCancel: @escaping () -> Void) {
        if keyMonitor == nil {
            keyMonitor = EventMonitor(NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                let shouldCancel = event.keyCode == KeyboardKeyCode.escape
                let handled = MainActor.assumeIsolated {
                    if shouldCancel {
                        onCancel()
                        return true
                    }
                    return false
                }
                return handled ? nil : event
            })
        }

        if globalKeyMonitor == nil {
            globalKeyMonitor = EventMonitor(NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
                let keyCode = event.keyCode
                DispatchQueue.main.async {
                    guard !NSApp.isActive else { return }
                    if keyCode == KeyboardKeyCode.escape {
                        onCancel()
                    }
                }
            })
        }
    }

    private func stopKeyMonitor() {
        keyMonitor?.cancel()
        keyMonitor = nil

        globalKeyMonitor?.cancel()
        globalKeyMonitor = nil
    }

    private func buildOverlayWindows(
        screens: [NSScreen],
        state: SelectionOverlayState,
        mouseLocation: CGPoint,
        refreshViews: @escaping () -> Void,
        finish: @escaping (SelectionResult?) -> Void,
    ) -> Bool {
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
                logKeyWindow(window, screen: screen, message: "made key window")
            }
            window.makeFirstResponder(view)
            windowID = CGWindowID(window.windowNumber)
            windows.append(window)
            views.append(view)
        }

        return didSetKeyWindow
    }

    private func ensureKeyWindow(screens: [NSScreen], didSetKeyWindow: Bool) {
        if !didSetKeyWindow {
            windows.first?.makeKeyAndOrderFront(nil)
            if let window = windows.first, let screen = screens.first {
                logKeyWindow(window, screen: screen, message: "default key window")
            }
        }
        // Ensure a key window is set for event handling.
        if let keyWindow = windows.first(where: { $0.isKeyWindow }) ?? windows.first {
            keyWindow.makeKeyAndOrderFront(nil)
            #if DEBUG
                let windowNumber = keyWindow.windowNumber
                let appActive = NSApp.isActive
                AppLog.capture.debug(
                    "Reasserted selection key window \(windowNumber, privacy: .public)",
                )
                AppLog.capture.debug(
                    "Selection overlay appActive=\(appActive, privacy: .public)",
                )
            #endif
        }
    }

    private func logKeyWindow(_ window: NSWindow, screen: NSScreen, message: String) {
        #if DEBUG
            let frameDescription = String(describing: screen.frame)
            let windowNumber = window.windowNumber
            let appActive = NSApp.isActive
            AppLog.capture.debug(
                "\(message, privacy: .public) window=\(windowNumber, privacy: .public)",
            )
            AppLog.capture.debug(
                "Selection overlay screen=\(frameDescription, privacy: .public)",
            )
            AppLog.capture.debug(
                "Selection overlay appActive=\(appActive, privacy: .public)",
            )
        #endif
    }
}
