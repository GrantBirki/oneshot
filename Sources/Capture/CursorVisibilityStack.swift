import AppKit
import CoreGraphics
import os.log

final class CursorVisibilityStack {
    private let displayProvider: () -> [CGDirectDisplayID]
    private let hideHandler: ([CGDirectDisplayID]) -> Void
    private let showHandler: ([CGDirectDisplayID]) -> Void
    private var hideCount = 0
    private var hiddenDisplays: [CGDirectDisplayID] = []
    #if DEBUG
    private let log = OSLog(subsystem: "com.grantbirki.oneshot", category: "CursorVisibility")
    #endif

    init(
        displayProvider: @escaping () -> [CGDirectDisplayID] = CursorVisibilityStack.activeDisplays,
        hideHandler: @escaping ([CGDirectDisplayID]) -> Void = CursorVisibilityStack.hide,
        showHandler: @escaping ([CGDirectDisplayID]) -> Void = CursorVisibilityStack.show,
    ) {
        self.displayProvider = displayProvider
        self.hideHandler = hideHandler
        self.showHandler = showHandler
    }

    func hide() {
        hideCount += 1
        guard hideCount == 1 else { return }
        hiddenDisplays = displayProvider()
        #if DEBUG
        os_log("hiding cursor on %{public}@", log: log, type: .debug, hiddenDisplays)
        #endif
        hideHandler(hiddenDisplays)
        NSCursor.hide()
    }

    func show() {
        guard hideCount > 0 else { return }
        hideCount -= 1
        guard hideCount == 0 else { return }
        #if DEBUG
        os_log("showing cursor on %{public}@", log: log, type: .debug, hiddenDisplays)
        #endif
        showHandler(hiddenDisplays)
        NSCursor.unhide()
        hiddenDisplays = []
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        var status = CGGetActiveDisplayList(0, nil, &displayCount)
        guard status == .success else { return [CGMainDisplayID()] }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        status = CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        guard status == .success else { return [CGMainDisplayID()] }

        return Array(displays.prefix(Int(displayCount)))
    }

    private static func hide(_ displays: [CGDirectDisplayID]) {
        for display in displays {
            CGDisplayHideCursor(display)
        }
    }

    private static func show(_ displays: [CGDirectDisplayID]) {
        for display in displays {
            CGDisplayShowCursor(display)
        }
    }
}
