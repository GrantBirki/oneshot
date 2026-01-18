import AppKit
import os.log

final class CursorStack {
    private let pushHandler: () -> Void
    private let popHandler: () -> Void
    private var isPushed = false
    #if DEBUG
    private let log = OSLog(subsystem: "com.grantbirki.oneshot", category: "CursorStack")
    #endif

    init(
        pushHandler: @escaping () -> Void = { NSCursor.crosshair.push() },
        popHandler: @escaping () -> Void = { NSCursor.pop() },
    ) {
        self.pushHandler = pushHandler
        self.popHandler = popHandler
    }

    func pushCrosshair() {
        guard !isPushed else { return }
        pushHandler()
        isPushed = true
        #if DEBUG
        os_log("push crosshair", log: log, type: .debug)
        #endif
    }

    func pop() {
        guard isPushed else { return }
        popHandler()
        isPushed = false
        #if DEBUG
        os_log("pop crosshair", log: log, type: .debug)
        #endif
    }
}
