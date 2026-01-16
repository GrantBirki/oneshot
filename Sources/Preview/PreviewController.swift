import AppKit

struct PreviewRequest {
    let image: NSImage
    let pngData: Data
    let filenamePrefix: String
    let timeout: TimeInterval?
    let onClose: () -> Void
    let onTrash: () -> Void
    let onOpen: () -> Void
    let onReplace: () -> Void
    let onAutoDismiss: (() -> Void)?
    let anchorRect: CGRect?
}

struct PreviewAutoDismissGate {
    var deadline: Date?
    var pending = false
    var isHovered = false
    var isDragging = false

    var isBlockingDismissal: Bool {
        isHovered || isDragging
    }

    mutating func reset(deadline: Date?) {
        self.deadline = deadline
        pending = false
        isHovered = false
        isDragging = false
    }

    mutating func deadlineReached(now: Date) -> Bool {
        guard let deadline, now >= deadline else { return false }
        if isBlockingDismissal {
            pending = true
            return false
        }
        pending = false
        return true
    }

    mutating func interactionChanged(isHovered: Bool? = nil, isDragging: Bool? = nil, now: Date) -> Bool {
        if let isHovered {
            self.isHovered = isHovered
        }
        if let isDragging {
            self.isDragging = isDragging
        }

        guard let deadline, now >= deadline else { return false }
        guard pending, !isBlockingDismissal else { return false }
        return true
    }
}

final class PreviewController {
    private var panel: PreviewPanel?
    private var hideWorkItem: DispatchWorkItem?
    private var graceWorkItem: DispatchWorkItem?
    private var replaceAction: (() -> Void)?
    private var autoDismissAction: (() -> Void)?
    private var autoDismissGate = PreviewAutoDismissGate()
    private let dateProvider: () -> Date
    private let graceDelay: TimeInterval = 0.2

    init(dateProvider: @escaping () -> Date = Date.init) {
        self.dateProvider = dateProvider
    }

    func show(_ request: PreviewRequest) {
        dismissForReplacement()
        hideWorkItem?.cancel()
        graceWorkItem?.cancel()
        autoDismissGate.reset(deadline: nil)

        let panel = PreviewPanel(
            image: request.image,
            pngData: request.pngData,
            filenamePrefix: request.filenamePrefix,
            onClose: { [weak self] in
                request.onClose()
                self?.hide()
            },
            onTrash: { [weak self] in
                request.onTrash()
                self?.hide()
            },
            onOpen: { [weak self] in
                request.onOpen()
                self?.hide()
            },
            onHoverChanged: { [weak self] hovered in
                self?.handleInteractionChange(isHovered: hovered, isDragging: nil)
            },
            onDragChanged: { [weak self] dragging in
                self?.handleInteractionChange(isHovered: nil, isDragging: dragging)
            },
        )
        panel.show(on: PreviewPanel.screen(for: request.anchorRect))
        self.panel = panel
        replaceAction = { [weak self] in
            request.onReplace()
            self?.hide()
        }
        autoDismissAction = request.onAutoDismiss

        if let timeout = request.timeout, timeout > 0 {
            autoDismissGate.reset(deadline: dateProvider().addingTimeInterval(timeout))
            let workItem = DispatchWorkItem { [weak self] in
                self?.handleDismissDeadlineReached()
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
        }
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        graceWorkItem?.cancel()
        graceWorkItem = nil
        autoDismissAction = nil
        autoDismissGate.reset(deadline: nil)
        panel?.close()
        panel = nil
        replaceAction = nil
    }

    private func handleDismissDeadlineReached() {
        if autoDismissGate.deadlineReached(now: dateProvider()) {
            performAutoDismiss()
        }
    }

    // Auto-dismiss waits for the deadline, then only completes once the user isn't hovering or dragging.
    private func handleInteractionChange(isHovered: Bool?, isDragging: Bool?) {
        if autoDismissGate.interactionChanged(isHovered: isHovered, isDragging: isDragging, now: dateProvider()) {
            scheduleGraceDismiss()
        } else if autoDismissGate.isBlockingDismissal {
            cancelGraceDismiss()
        }
    }

    private func scheduleGraceDismiss() {
        graceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if autoDismissGate.deadlineReached(now: dateProvider()) {
                performAutoDismiss()
            }
        }
        graceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay, execute: workItem)
    }

    private func cancelGraceDismiss() {
        graceWorkItem?.cancel()
        graceWorkItem = nil
    }

    private func performAutoDismiss() {
        autoDismissAction?()
        autoDismissAction = nil
        hide()
    }

    private func dismissForReplacement() {
        guard panel != nil else { return }
        replaceAction?()
    }
}
