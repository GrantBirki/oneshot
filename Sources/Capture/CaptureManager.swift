import AppKit
import UniformTypeIdentifiers

enum CaptureSessionState: Equatable {
    case idle
    case selecting
    case windowSelecting
    case scrolling
    case processing
}

struct CaptureSessionTracker {
    private(set) var state: CaptureSessionState = .idle

    mutating func begin(_ nextState: CaptureSessionState) -> Bool {
        guard state == .idle else {
            return false
        }
        state = nextState
        return true
    }

    mutating func transition(to nextState: CaptureSessionState) {
        state = nextState
    }

    mutating func finish(_ completedState: CaptureSessionState) {
        if state == completedState || state == .processing {
            state = .idle
        }
    }

    mutating func reset() {
        state = .idle
    }
}

enum CaptureError: LocalizedError, Sendable {
    case captureFailed(String)
    case encodingFailed(String)
    case scrollingRequiresSingleDisplay

    var errorDescription: String? {
        switch self {
        case let .captureFailed(message), let .encodingFailed(message):
            message
        case .scrollingRequiresSingleDisplay:
            "Scrolling capture must stay on one display."
        }
    }
}

struct PreviewActionCancelled: Error {}

@MainActor
final class CaptureManager {
    private let settings: SettingsStore
    private let selectionOverlay = SelectionOverlayController()
    private let windowOverlay = WindowCaptureOverlayController()
    private let outputCoordinator: OutputCoordinator
    private let previewController: PreviewController
    private let scrollingCaptureSession = ScrollingCaptureSession()
    private let scrollingOverlay = ScrollingCaptureOverlayController()
    private var sessionTracker = CaptureSessionTracker()
    private var preparationTask: Task<Void, Never>?
    private var scrollingPreparationTask: Task<Void, Never>?
    private var scrollingPreparationID: UUID?
    private var captureTask: Task<Void, Never>?
    private var activeOutputID: UUID?

    var onScrollingCaptureStateChange: ((Bool) -> Void)?

    var hasPendingTerminationWork: Bool {
        activeOutputID != nil || captureTask != nil || scrollingPreparationTask != nil
    }

    init(settings: SettingsStore) {
        self.settings = settings
        previewController = PreviewController()
        outputCoordinator = OutputCoordinator(settings: settings)
        outputCoordinator.setScheduledSaveFailureHandler { [weak previewController] _, error in
            previewController?.showRecovery(for: error)
        }
        outputCoordinator.setSaveHandler { [weak self] id, _ in
            guard let self, activeOutputID == id else { return }
            previewController.setSavedState(true)
        }
    }

    func captureSelection() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        prepareForCapture { [weak self] in
            self?.startSelectionCapture()
        }
    }

    func captureFullScreen() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        prepareForCapture { [weak self] in
            self?.startFullScreenCapture()
        }
    }

    func captureWindow() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        prepareForCapture { [weak self] in
            self?.startWindowCapture()
        }
    }

    func captureScrolling() {
        if sessionTracker.state == .scrolling || scrollingCaptureSession.isActive {
            scrollingCaptureSession.stop()
            return
        }
        guard ScreenCapturePermission.ensureAccess() else { return }
        prepareForCapture { [weak self] in
            self?.startScrollingSelection()
        }
    }

    func prepareForTermination() async -> Bool {
        previewController.beginTermination()
        preparationTask?.cancel()
        preparationTask = nil
        cancelScrollingPreparation()

        switch sessionTracker.state {
        case .selecting:
            selectionOverlay.cancel()
            sessionTracker.reset()
        case .windowSelecting:
            windowOverlay.cancel()
            sessionTracker.reset()
        case .scrolling:
            scrollingCaptureSession.cancel()
            scrollingOverlay.hide()
            updateScrollingCaptureState(isActive: false)
            sessionTracker.reset()
        case .idle, .processing:
            break
        }

        if let captureTask {
            let completed = await waitForTask(captureTask, timeout: .seconds(5))
            if !completed {
                previewController.cancelTermination()
                UserErrorPresenter.showCaptureFailure(
                    "OneShot is still processing a screenshot. Quit again after it finishes so the capture is not lost.",
                )
                return false
            }
        }

        if await !(previewController.waitForCurrentAction(timeout: .seconds(5))) {
            previewController.cancelTermination()
            UserErrorPresenter.showCaptureFailure(
                "OneShot is still finishing a screenshot action. Quit again after it completes so the capture is not lost.",
            )
            return false
        }

        guard let activeOutputID else { return true }
        do {
            _ = try await outputCoordinator.saveAndFinish(id: activeOutputID)
            self.activeOutputID = nil
            previewController.hide()
            return true
        } catch {
            previewController.cancelTermination()
            previewController.showRecovery(for: error)
            return false
        }
    }

    func cleanup() {
        preparationTask?.cancel()
        preparationTask = nil
        cancelScrollingPreparation()
        captureTask?.cancel()
        captureTask = nil
        previewController.cancelCurrentAction()
        selectionOverlay.cancel()
        windowOverlay.cancel()
        scrollingCaptureSession.cancel()
        scrollingOverlay.hide()
        previewController.hide()
        sessionTracker.reset()
        updateScrollingCaptureState(isActive: false)
    }
}

private extension CaptureManager {
    func prepareForCapture(_ operation: @escaping @MainActor () -> Void) {
        guard preparationTask == nil, sessionTracker.state == .idle else {
            rejectConcurrentCapture()
            return
        }

        preparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let canProceed = await previewController.resolveForReplacement()
            preparationTask = nil
            guard canProceed, !Task.isCancelled else { return }
            operation()
        }
    }

    func startSelectionCapture() {
        guard beginSession(.selecting) else { return }
        AccessibilityAnnouncer.announce("Selection capture started")
        selectionOverlay.beginSelection(
            showSelectionCoordinates: settings.showSelectionCoordinates,
            visualCue: settings.selectionVisualCue,
            dimmingMode: settings.selectionDimmingMode,
            selectionDimmingColor: settings.selectionDimmingColor,
        ) { [weak self] selection in
            guard let self else { return }
            guard let selection else {
                finishSession(.selecting)
                return
            }
            sessionTracker.transition(to: .processing)
            captureTask = Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    captureTask = nil
                    finishSession(.processing)
                }
                guard let image = await ScreenCaptureService.capture(
                    rect: selection.rect,
                    excludingWindowIDs: selection.excludeWindowIDs,
                ) else {
                    presentCaptureFailure("OneShot could not capture the selected area. Please try again.")
                    return
                }
                await handleCapture(image, displaySize: selection.rect.size, anchorRect: selection.rect)
            }
        }
    }

    func startFullScreenCapture() {
        guard beginSession(.processing) else { return }
        captureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                captureTask = nil
                finishSession(.processing)
            }
            guard let image = await ScreenCaptureService.captureFullScreen() else {
                presentCaptureFailure("OneShot could not capture the displays. Please try again.")
                return
            }
            let frame = ScreenFrameHelper.allScreensFrame()
            let size = frame?.size ?? NSSize(width: image.width, height: image.height)
            await handleCapture(image, displaySize: size, anchorRect: frame)
        }
    }

    func startWindowCapture() {
        guard beginSession(.windowSelecting) else { return }
        AccessibilityAnnouncer.announce("Window capture started")
        windowOverlay.beginSelection { [weak self] windowInfo in
            guard let self else { return }
            guard let windowInfo else {
                finishSession(.windowSelecting)
                return
            }
            sessionTracker.transition(to: .processing)
            captureTask = Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    captureTask = nil
                    finishSession(.processing)
                }
                guard let image = await ScreenCaptureService.capture(windowID: windowInfo.id) else {
                    presentCaptureFailure("OneShot could not capture the selected window. It may have closed or moved.")
                    return
                }
                await handleCapture(image, displaySize: windowInfo.bounds.size, anchorRect: windowInfo.bounds)
            }
        }
    }

    func startScrollingSelection() {
        guard beginSession(.selecting) else { return }
        AccessibilityAnnouncer.announce("Scrolling capture started. Scroll downward and use Stop when finished.")
        selectionOverlay.beginSelection(
            showSelectionCoordinates: settings.showSelectionCoordinates,
            visualCue: settings.selectionVisualCue,
            dimmingMode: settings.selectionDimmingMode,
            selectionDimmingColor: settings.selectionDimmingColor,
        ) { [weak self] selection in
            guard let self else { return }
            guard let selection else {
                finishSession(.selecting)
                return
            }
            let anchorRect = selection.rect.integral
            let preparationID = UUID()
            scrollingPreparationID = preparationID
            scrollingPreparationTask = Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    if scrollingPreparationID == preparationID {
                        scrollingPreparationTask = nil
                        scrollingPreparationID = nil
                    }
                }
                let preflight = await ScreenCaptureService.preflightScrollingCapture(rect: anchorRect)
                guard !Task.isCancelled,
                      scrollingPreparationID == preparationID,
                      sessionTracker.state == .selecting
                else {
                    return
                }
                guard preflight == .ready else {
                    finishSession(.selecting)
                    if preflight == .multipleDisplays {
                        presentCaptureFailure(CaptureError.scrollingRequiresSingleDisplay.localizedDescription)
                    } else {
                        presentCaptureFailure("The scrolling capture selection is not valid.")
                    }
                    return
                }

                sessionTracker.transition(to: .scrolling)
                updateScrollingCaptureState(isActive: true)
                scrollingOverlay.show(selectionRect: anchorRect) { [weak self] in
                    self?.scrollingCaptureSession.stop()
                }
                let started = scrollingCaptureSession.start(rect: anchorRect) { [weak self] result in
                    self?.finishScrollingCapture(result, anchorRect: anchorRect)
                }
                if !started {
                    scrollingOverlay.hide()
                    updateScrollingCaptureState(isActive: false)
                    finishSession(.scrolling)
                    presentCaptureFailure("Scrolling capture could not be started.")
                }
            }
        }
    }

    func finishScrollingCapture(_ result: ScrollingCaptureResult, anchorRect: CGRect) {
        scrollingOverlay.hide()
        updateScrollingCaptureState(isActive: false)
        finishSession(.scrolling)

        guard result.reason != .cancelled else { return }
        guard let image = result.image else {
            presentCaptureFailure("OneShot could not capture any scrolling content.")
            return
        }

        sessionTracker.transition(to: .processing)
        let displaySize = displaySize(for: image, baseRect: anchorRect)
        captureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                captureTask = nil
                finishSession(.processing)
            }
            await handleCapture(image, displaySize: displaySize, anchorRect: anchorRect)
            switch result.reason {
            case .limitReached:
                UserErrorPresenter.show(
                    title: "Scrolling Capture Reached Its Limit",
                    message: "OneShot kept the content captured so far. Start a new capture for the remaining content.",
                )
            case .captureFailed:
                UserErrorPresenter.show(
                    title: "Scrolling Capture Stopped",
                    message: "Repeated frame failures stopped the session. OneShot kept the content captured so far.",
                )
            case .userStopped, .cancelled:
                break
            }
        }
    }

    func handleCapture(_ image: CGImage, displaySize: NSSize, anchorRect: CGRect?) async {
        let signpostID = AppSignpost.begin("Capture process")
        defer { AppSignpost.end("Capture process", id: signpostID) }
        do {
            let widthScale = displaySize.width > 0 ? CGFloat(image.width) / displaySize.width : 1
            let heightScale = displaySize.height > 0 ? CGFloat(image.height) / displaySize.height : 1
            let scale = max(widthScale, heightScale, 1)
            let pngData = try await PNGDataEncoder.encodeAsync(cgImage: image, scale: scale)
            let captured = CapturedImage(cgImage: image, displaySize: displaySize, pngData: pngData)
            ScreenshotSoundPlayer.play(
                sound: settings.shutterSound,
                volume: settings.shutterSoundVolume,
                isEnabled: settings.shutterSoundEnabled,
            )
            if settings.previewEnabled {
                await handleCaptureWithPreview(captured, anchorRect: anchorRect)
            } else {
                await handleCaptureWithoutPreview(captured, anchorRect: anchorRect)
            }
        } catch {
            AppLog.capture.error("Failed to encode screenshot: \(String(describing: error), privacy: .private)")
            presentCaptureFailure("OneShot captured the screen but could not encode the image.")
        }
    }

    func handleCaptureWithPreview(_ captured: CapturedImage, anchorRect: CGRect?) async {
        let previewTimeout = settings.previewTimeout
        let saveID = await outputCoordinator.begin(
            pngData: captured.pngData,
            scheduleSave: PreviewSaveScheduler.shouldScheduleSave(previewTimeout: previewTimeout),
        )
        activeOutputID = saveID
        let request = makePreviewRequest(
            captured: captured,
            saveID: saveID,
            timeout: previewTimeout,
            replacementBehavior: settings.previewReplacementBehavior,
            autoDismissBehavior: previewTimeout == nil ? nil : settings.previewAutoDismissBehavior,
            anchorRect: anchorRect,
        )
        if await previewController.show(request) {
            await previewController.setSavedState(outputCoordinator.isSaved(id: saveID))
        }
    }

    func handleCaptureWithoutPreview(_ captured: CapturedImage, anchorRect: CGRect?) async {
        switch settings.previewDisabledOutputBehavior {
        case .saveToDisk:
            let saveID = await outputCoordinator.begin(pngData: captured.pngData, scheduleSave: false)
            activeOutputID = saveID
            do {
                _ = try await outputCoordinator.saveAndFinish(id: saveID)
                activeOutputID = nil
            } catch {
                let request = makePreviewRequest(
                    captured: captured,
                    saveID: saveID,
                    timeout: nil,
                    replacementBehavior: .saveImmediately,
                    autoDismissBehavior: nil,
                    anchorRect: anchorRect,
                )
                _ = await previewController.show(request)
                previewController.showRecovery(for: error)
            }
        case .clipboardOnly:
            do {
                try await outputCoordinator.copy(pngData: captured.pngData)
            } catch {
                presentCaptureFailure("OneShot could not copy the screenshot to the clipboard.")
            }
        }
    }

    func makePreviewRequest(
        captured: CapturedImage,
        saveID: UUID,
        timeout: TimeInterval?,
        replacementBehavior: PreviewReplacementBehavior,
        autoDismissBehavior: PreviewAutoDismissBehavior?,
        anchorRect: CGRect?,
    ) -> PreviewRequest {
        let autoDismissAction: PreviewRequest.Action? = if let autoDismissBehavior {
            { @MainActor [weak self] in
                guard let self else { return }
                switch autoDismissBehavior {
                case .saveToDisk:
                    try await saveAndComplete(id: saveID)
                case .discard:
                    try await discardAndComplete(id: saveID)
                }
            }
        } else {
            nil
        }

        return PreviewRequest(
            image: captured.previewImage,
            pngData: captured.pngData,
            filenamePrefix: settings.filenamePrefix,
            timeout: timeout,
            onSave: { [weak self] in
                try await self?.saveAndComplete(id: saveID)
            },
            onDiscard: { [weak self] in
                try await self?.discardAndComplete(id: saveID)
            },
            onOpen: { [weak self] in
                guard let self else { return }
                let result = try await outputCoordinator.finalize(id: saveID)
                guard NSWorkspace.shared.open(result.url) else {
                    throw PreviewOpenError.failed
                }
                await outputCoordinator.finish(id: saveID)
                clearActiveOutput(id: saveID)
            },
            onSaveAs: { [weak self] in
                guard let self else { return }
                guard let url = chooseSaveURL() else {
                    throw PreviewActionCancelled()
                }
                _ = try await outputCoordinator.saveAndFinish(id: saveID, destination: .file(url))
                clearActiveOutput(id: saveID)
            },
            onCopy: { [weak self] in
                try await self?.outputCoordinator.copy(id: saveID)
            },
            onReveal: { [weak self] in
                guard let self else { return }
                let result = try await outputCoordinator.finalize(id: saveID)
                NSWorkspace.shared.activateFileViewerSelecting([result.url])
            },
            onDismissSaved: { [weak self] in
                guard let self else { return }
                await outputCoordinator.finish(id: saveID)
                clearActiveOutput(id: saveID)
            },
            onReplace: { [weak self] in
                guard let self else { return }
                switch replacementBehavior {
                case .saveImmediately:
                    try await saveAndComplete(id: saveID)
                case .discard:
                    try await discardAndComplete(id: saveID)
                }
            },
            onAutoDismiss: autoDismissAction,
            anchorRect: anchorRect,
        )
    }

    func saveAndComplete(id: UUID) async throws {
        _ = try await outputCoordinator.saveAndFinish(id: id)
        clearActiveOutput(id: id)
    }

    func discardAndComplete(id: UUID) async throws {
        try await outputCoordinator.discard(id: id)
        clearActiveOutput(id: id)
    }

    func clearActiveOutput(id: UUID) {
        if activeOutputID == id {
            activeOutputID = nil
        }
    }

    func chooseSaveURL() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = FilenameFormatter.makeFilename(prefix: settings.filenamePrefix)
        panel.directoryURL = SaveLocationResolver.resolve(
            option: settings.saveLocationOption,
            customPath: settings.customSavePath,
        )
        return panel.runModal() == .OK ? panel.url : nil
    }

    func displaySize(for image: CGImage, baseRect: CGRect) -> NSSize {
        guard baseRect.width > 0 else {
            return NSSize(width: image.width, height: image.height)
        }
        let scale = CGFloat(image.width) / baseRect.width
        let height = scale > 0 ? CGFloat(image.height) / scale : CGFloat(image.height)
        return NSSize(width: baseRect.width, height: height)
    }

    func updateScrollingCaptureState(isActive: Bool) {
        onScrollingCaptureStateChange?(isActive)
    }

    func cancelScrollingPreparation() {
        scrollingPreparationTask?.cancel()
        scrollingPreparationTask = nil
        scrollingPreparationID = nil
    }

    func beginSession(_ state: CaptureSessionState) -> Bool {
        guard sessionTracker.begin(state) else {
            rejectConcurrentCapture()
            return false
        }
        return true
    }

    func finishSession(_ state: CaptureSessionState) {
        sessionTracker.finish(state)
    }

    func rejectConcurrentCapture() {
        NSSound.beep()
        AccessibilityAnnouncer.announce("OneShot is already capturing or resolving a screenshot")
    }

    func presentCaptureFailure(_ message: String) {
        UserErrorPresenter.showCaptureFailure(message)
    }

    func waitForTask(_ task: Task<Void, Never>, timeout: Duration) async -> Bool {
        await TaskCompletionRace.wait(for: task, timeout: timeout)
    }
}

@MainActor
enum TaskCompletionRace {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    static func wait(
        for task: Task<Void, Never>,
        timeout: Duration,
        sleeper: @escaping Sleep = { try await Task.sleep(for: $0) },
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let gate = TaskCompletionGate(continuation: continuation)
            Task { @MainActor in
                await task.value
                gate.resolve(true)
            }
            Task { @MainActor in
                do {
                    try await sleeper(timeout)
                    gate.resolve(false)
                } catch {
                    // The caller owns the task being observed. A cancelled timeout
                    // must not be mistaken for successful task completion.
                }
            }
        }
    }
}

@MainActor
private final class TaskCompletionGate {
    private var continuation: CheckedContinuation<Bool, Never>?

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resolve(_ completed: Bool) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: completed)
    }
}

enum PreviewSaveScheduler {
    static func shouldScheduleSave(previewTimeout: TimeInterval?) -> Bool {
        previewTimeout == nil
    }
}
