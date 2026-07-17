import AppKit

enum PreviewOpenError: LocalizedError {
    case failed

    var errorDescription: String? {
        "The screenshot was saved, but macOS could not open it."
    }
}

struct PreviewRequest {
    typealias Action = @MainActor () async throws -> Void

    let image: NSImage
    let pngData: Data
    let filenamePrefix: String
    let timeout: TimeInterval?
    let onSave: Action
    let onDiscard: Action
    let onOpen: Action
    let onSaveAs: Action
    let onCopy: Action
    let onReveal: Action
    let onDismissSaved: Action
    let onReplace: Action
    let onAutoDismiss: Action?
    let anchorRect: CGRect?
}

struct PreviewAutoDismissGate {
    var pending = false
    var isHovered = false
    var isDragging = false

    var isBlockingDismissal: Bool {
        isHovered || isDragging
    }

    mutating func reset() {
        pending = false
        isHovered = false
        isDragging = false
    }

    mutating func deadlineReached() -> Bool {
        if isBlockingDismissal {
            pending = true
            return false
        }
        pending = false
        return true
    }

    mutating func interactionChanged(isHovered: Bool? = nil, isDragging: Bool? = nil) -> Bool {
        if let isHovered {
            self.isHovered = isHovered
        }
        if let isDragging {
            self.isDragging = isDragging
        }

        guard pending, !isBlockingDismissal else { return false }
        pending = false
        return true
    }
}

@MainActor
final class PreviewController {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private var panel: PreviewPanel?
    private var dismissTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    private var replaceAction: PreviewRequest.Action?
    private var saveAction: PreviewRequest.Action?
    private var revealAction: PreviewRequest.Action?
    private var dismissSavedAction: PreviewRequest.Action?
    private var autoDismissAction: PreviewRequest.Action?
    private var autoDismissGate = PreviewAutoDismissGate()
    private let sleeper: Sleep
    private let graceDelay = Duration.milliseconds(200)
    private var isPerformingAction = false
    private var isTerminating = false

    init(sleeper: @escaping Sleep = { duration in try await Task.sleep(for: duration) }) {
        self.sleeper = sleeper
    }

    @discardableResult
    func show(_ request: PreviewRequest) async -> Bool {
        guard await resolveForReplacement() else { return false }
        cancelDismissTasks()
        autoDismissGate.reset()

        let panel = PreviewPanel(
            image: request.image,
            pngData: request.pngData,
            filenamePrefix: request.filenamePrefix,
            onSave: { [weak self] in self?.perform(request.onSave, dismissOnSuccess: true) },
            onDiscard: { [weak self] in self?.perform(request.onDiscard, dismissOnSuccess: true) },
            onOpen: { [weak self] in self?.perform(request.onOpen, dismissOnSuccess: true) },
            onSaveAs: { [weak self] in self?.perform(request.onSaveAs, dismissOnSuccess: true) },
            onCopy: { [weak self] in
                self?.perform(
                    request.onCopy,
                    dismissOnSuccess: false,
                    successMessage: "Copied to the clipboard. The clipboard copy will remain after the preview closes.",
                )
            },
            onHoverChanged: { [weak self] hovered in
                self?.handleInteractionChange(isHovered: hovered, isDragging: nil)
            },
            onDragChanged: { [weak self] dragging in
                self?.handleInteractionChange(isHovered: nil, isDragging: dragging)
            },
        )
        panel.show(on: PreviewPanel.screen(for: request.anchorRect))
        panel.setSavedState(false)
        self.panel = panel
        replaceAction = request.onReplace
        saveAction = request.onSave
        revealAction = request.onReveal
        dismissSavedAction = request.onDismissSaved
        autoDismissAction = request.onAutoDismiss
        if isTerminating {
            panel.setBusy(true)
        }

        if let timeout = request.timeout, timeout >= 0 {
            scheduleAutoDismiss(after: timeout)
        }
        return true
    }

    func hide() {
        cancelDismissTasks()
        autoDismissAction = nil
        autoDismissGate.reset()
        panel?.close()
        panel = nil
        replaceAction = nil
        saveAction = nil
        revealAction = nil
        dismissSavedAction = nil
        isPerformingAction = false
    }

    func beginTermination() {
        isTerminating = true
        panel?.setBusy(true)
    }

    func cancelTermination() {
        isTerminating = false
        if !isPerformingAction {
            panel?.setBusy(false)
        }
    }

    func waitForCurrentAction(timeout: Duration) async -> Bool {
        guard let actionTask else { return true }
        return await TaskCompletionRace.wait(for: actionTask, timeout: timeout)
    }

    func cancelCurrentAction() {
        actionTask?.cancel()
    }

    func resolveForReplacement() async -> Bool {
        guard !isPerformingAction else { return false }
        guard panel != nil, let replaceAction else { return true }
        do {
            try await replaceAction()
            hide()
            return true
        } catch {
            showRecovery(for: error, retryAction: replaceAction, dismissOnSuccess: true)
            return false
        }
    }

    func showRecovery(
        for error: Error,
        retryAction: PreviewRequest.Action? = nil,
        dismissOnSuccess: Bool = true,
        successMessage: String? = nil,
    ) {
        guard let action = retryAction ?? saveAction else { return }
        panel?.showRecovery(message: userMessage(for: error)) { [weak self] in
            self?.perform(
                action,
                dismissOnSuccess: dismissOnSuccess,
                successMessage: successMessage,
            )
        }
    }

    var hasActivePreview: Bool {
        panel != nil
    }

    func setSavedState(_ saved: Bool) {
        panel?.setSavedState(saved)
    }

    private func perform(
        _ action: @escaping PreviewRequest.Action,
        dismissOnSuccess: Bool,
        successMessage: String? = nil,
        preserveRecoveryOnSuccess: Bool = false,
    ) {
        guard !isPerformingAction, !isTerminating else { return }
        isPerformingAction = true
        panel?.setBusy(true)
        actionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                actionTask = nil
                isPerformingAction = false
                if !isTerminating {
                    panel?.setBusy(false)
                }
            }
            do {
                try await action()
                if dismissOnSuccess {
                    hide()
                } else if let successMessage {
                    panel?.showStatus(message: successMessage)
                } else if preserveRecoveryOnSuccess {
                    return
                } else {
                    panel?.clearRecovery()
                }
            } catch is PreviewActionCancelled {
                return
            } catch {
                if error is PreviewOpenError,
                   let revealAction,
                   let dismissSavedAction
                {
                    showOpenRecovery(
                        for: error,
                        retryAction: action,
                        revealAction: revealAction,
                        dismissAction: dismissSavedAction,
                    )
                } else {
                    showRecovery(
                        for: error,
                        retryAction: action,
                        dismissOnSuccess: dismissOnSuccess,
                        successMessage: successMessage,
                    )
                }
            }
        }
    }

    private func showOpenRecovery(
        for error: Error,
        retryAction: @escaping PreviewRequest.Action,
        revealAction: @escaping PreviewRequest.Action,
        dismissAction: @escaping PreviewRequest.Action,
    ) {
        panel?.showOpenRecovery(
            message: userMessage(for: error),
            onRetryOpen: { [weak self] in
                self?.perform(retryAction, dismissOnSuccess: true)
            },
            onReveal: { [weak self] in
                self?.perform(
                    revealAction,
                    dismissOnSuccess: false,
                    preserveRecoveryOnSuccess: true,
                )
            },
            onDismiss: { [weak self] in
                self?.perform(dismissAction, dismissOnSuccess: true)
            },
        )
    }

    private func scheduleAutoDismiss(after timeout: TimeInterval) {
        let duration = Duration.seconds(max(timeout, 0))
        dismissTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if duration > .zero {
                    try await sleeper(duration)
                }
                try Task.checkCancellation()
                handleDismissDeadlineReached()
            } catch {
                return
            }
        }
    }

    private func handleDismissDeadlineReached() {
        if autoDismissGate.deadlineReached() {
            performAutoDismiss()
        }
    }

    private func handleInteractionChange(isHovered: Bool?, isDragging: Bool?) {
        if autoDismissGate.interactionChanged(isHovered: isHovered, isDragging: isDragging) {
            scheduleGraceDismiss()
        } else if autoDismissGate.isBlockingDismissal {
            graceTask?.cancel()
            graceTask = nil
        }
    }

    private func scheduleGraceDismiss() {
        graceTask?.cancel()
        graceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await sleeper(graceDelay)
                try Task.checkCancellation()
                if !autoDismissGate.isBlockingDismissal {
                    performAutoDismiss()
                }
            } catch {
                return
            }
        }
    }

    private func performAutoDismiss() {
        guard let autoDismissAction else {
            hide()
            return
        }
        self.autoDismissAction = nil
        perform(autoDismissAction, dismissOnSuccess: true)
    }

    private func cancelDismissTasks() {
        dismissTask?.cancel()
        dismissTask = nil
        graceTask?.cancel()
        graceTask = nil
    }

    private func userMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
