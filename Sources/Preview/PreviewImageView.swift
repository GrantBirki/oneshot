import AppKit

final class PreviewImageView: NSImageView, NSDraggingSource {
    var onOpen: (() -> Void)?
    var dragPayload: PreviewDragPayload?
    var shouldIgnoreEvent: ((NSEvent) -> Bool)?
    var onDragStateChanged: ((Bool) -> Void)?
    private var didDrag = false
    private var draggingSessionStarted = false

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        draggingSessionStarted = false
        guard !shouldIgnore(event) else { return }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !shouldIgnore(event) else { return }
        guard !draggingSessionStarted, let payload = dragPayload else { return }
        guard let draggingItem = payload.makeDraggingItem(dragFrame: bounds) else { return }
        didDrag = true
        draggingSessionStarted = true
        onDragStateChanged?(true)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard !shouldIgnore(event) else { return }
        if !didDrag {
            onOpen?()
        }
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        draggingSessionStarted = false
        onDragStateChanged?(false)
        dragPayload?.rescheduleCleanup()
    }

    private func shouldIgnore(_ event: NSEvent) -> Bool {
        shouldIgnoreEvent?(event) ?? false
    }
}
