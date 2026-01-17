import AppKit

final class CursorStack {
    private let pushHandler: () -> Void
    private let popHandler: () -> Void
    private var isPushed = false

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
    }

    func pop() {
        guard isPushed else { return }
        popHandler()
        isPushed = false
    }
}
