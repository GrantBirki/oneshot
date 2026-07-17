import AppKit

final class PreviewImageView: NSImageView, NSDraggingSource {
    var onOpen: (() -> Void)?
    var onSave: (() -> Void)? {
        didSet { updateAccessibilityActions() }
    }

    var onDiscard: (() -> Void)? {
        didSet { updateAccessibilityActions() }
    }

    var onFocusChanged: ((Bool) -> Void)?
    var dragPayload: PreviewDragPayload?
    var shouldIgnoreEvent: ((NSEvent) -> Bool)?
    var onDragStateChanged: ((Bool) -> Void)?
    private var didDrag = false
    private var draggingSessionStarted = false
    private var isOutputSaved = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAccessibility()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        didDrag = false
        draggingSessionStarted = false
        guard !shouldIgnore(event) else { return }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !shouldIgnore(event) else { return }
        guard !draggingSessionStarted, let payload = dragPayload else { return }
        let draggingItem = payload.makeDraggingItem(dragFrame: bounds)
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
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        onFocusChanged?(true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        onFocusChanged?(false)
        return true
    }

    override func accessibilityPerformPress() -> Bool {
        onOpen?()
        return true
    }

    func setSavedState(_ saved: Bool) {
        isOutputSaved = saved
        setAccessibilityHelp(
            saved
                ? "Open or drag the screenshot, save another copy, or delete the saved file. Clipboard copies are kept."
                : "Open the screenshot, drag it to another app, save it, or choose not to save it.",
        )
        updateAccessibilityActions()
    }

    private func shouldIgnore(_ event: NSEvent) -> Bool {
        shouldIgnoreEvent?(event) ?? false
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Screenshot preview")
        setAccessibilityHelp("Open the screenshot, drag it to another app, save it, or choose not to save it.")
        updateAccessibilityActions()
    }

    private func updateAccessibilityActions() {
        let actions = [
            NSAccessibilityCustomAction(name: "Open screenshot") { [weak self] in
                self?.onOpen?()
                return self?.onOpen != nil
            },
            NSAccessibilityCustomAction(name: "Save screenshot") { [weak self] in
                self?.onSave?()
                return self?.onSave != nil
            },
            NSAccessibilityCustomAction(
                name: isOutputSaved ? "Delete saved screenshot" : "Don't save screenshot",
            ) { [weak self] in
                self?.onDiscard?()
                return self?.onDiscard != nil
            },
        ]
        setAccessibilityCustomActions(actions)
    }
}
