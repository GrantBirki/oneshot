import AppKit
import os.log

final class SelectionOverlayController {
    private var windows: [OverlayWindow] = []
    private var views: [SelectionOverlayView] = []
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

    func beginSelection(
        showSelectionCoordinates: Bool,
        visualCue: SelectionVisualCue,
        dimmingMode: SelectionDimmingMode,
        selectionDimmingColor: NSColor,
        completion: @escaping (SelectionResult?) -> Void,
    ) {
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
                os_log(
                    "reassert key window %{public}d appActive=%{public}@",
                    log: log,
                    type: .debug,
                    keyWindow.windowNumber,
                    "\(NSApp.isActive)",
                )
            #endif
        }
    }

    private func logKeyWindow(_ window: NSWindow, screen: NSScreen, message: String) {
        #if DEBUG
            os_log(
                "%{public}@ %{public}d for screen %{public}@, appActive=%{public}@",
                log: log,
                type: .debug,
                message,
                window.windowNumber,
                "\(screen.frame)",
                "\(NSApp.isActive)",
            )
        #endif
    }
}
