import AppKit

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

@MainActor
final class CaptureManager {
    private let settings: SettingsStore
    private let selectionOverlay = SelectionOverlayController()
    private let windowOverlay = WindowCaptureOverlayController()
    private let outputCoordinator: OutputCoordinator
    private let previewController = PreviewController()
    private let scrollingCaptureSession = ScrollingCaptureSession()
    private let scrollingOverlay = ScrollingCaptureOverlayController()
    private var sessionTracker = CaptureSessionTracker()

    var onScrollingCaptureStateChange: ((Bool) -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
        outputCoordinator = OutputCoordinator(settings: settings)
    }

    func captureSelection() {
        guard ScreenCapturePermission.ensureAccess() else { return }
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
            Task { [weak self] in
                guard let self else { return }
                if let image = await ScreenCaptureService.capture(
                    rect: selection.rect,
                    excludingWindowIDs: selection.excludeWindowIDs,
                ) {
                    await handleCapture(image, displaySize: selection.rect.size, anchorRect: selection.rect)
                }
                await MainActor.run {
                    self.finishSession(.processing)
                }
            }
        }
    }

    func captureFullScreen() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        guard beginSession(.processing) else { return }
        Task { [weak self] in
            guard let self else { return }
            if let image = await ScreenCaptureService.captureFullScreen() {
                let frame = await MainActor.run {
                    ScreenFrameHelper.allScreensFrame()
                }
                let size = frame?.size ?? NSSize(width: image.width, height: image.height)
                await handleCapture(image, displaySize: size, anchorRect: frame)
            }
            await MainActor.run {
                self.finishSession(.processing)
            }
        }
    }

    func captureWindow() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        guard beginSession(.windowSelecting) else { return }
        AccessibilityAnnouncer.announce("Window capture started")
        windowOverlay.beginSelection { [weak self] windowInfo in
            guard let self else { return }
            guard let windowInfo else {
                finishSession(.windowSelecting)
                return
            }
            sessionTracker.transition(to: .processing)
            Task { [weak self] in
                guard let self else { return }
                if let image = await ScreenCaptureService.capture(windowID: windowInfo.id) {
                    await handleCapture(image, displaySize: windowInfo.bounds.size, anchorRect: windowInfo.bounds)
                }
                await MainActor.run {
                    self.finishSession(.processing)
                }
            }
        }
    }

    func captureScrolling() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        if sessionTracker.state == .scrolling || scrollingCaptureSession.isActive {
            scrollingCaptureSession.stop()
            return
        }
        guard beginSession(.selecting) else { return }

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
            sessionTracker.transition(to: .scrolling)
            updateScrollingCaptureState(isActive: true)
            scrollingOverlay.show(selectionRect: anchorRect) { [weak self] in
                self?.scrollingCaptureSession.stop()
            }
            scrollingCaptureSession.start(rect: anchorRect) { [weak self] image in
                guard let self else { return }
                scrollingOverlay.hide()
                updateScrollingCaptureState(isActive: false)
                finishSession(.scrolling)
                guard let image else { return }
                sessionTracker.transition(to: .processing)
                let displaySize = displaySize(for: image, baseRect: anchorRect)
                Task { [weak self] in
                    guard let self else { return }
                    await handleCapture(image, displaySize: displaySize, anchorRect: anchorRect)
                    await MainActor.run {
                        self.finishSession(.processing)
                    }
                }
            }
        }
    }

    func cleanup() {
        selectionOverlay.cancel()
        windowOverlay.cancel()
        scrollingCaptureSession.stop()
        scrollingOverlay.hide()
        previewController.hide()
        sessionTracker.reset()
        updateScrollingCaptureState(isActive: false)
    }

    private func handleCapture(_ image: CGImage, displaySize: NSSize, anchorRect: CGRect?) async {
        let signpostID = AppSignpost.begin("Capture process")
        do {
            let pngData = try await PNGDataEncoder.encodeAsync(cgImage: image)
            await MainActor.run {
                let captured = CapturedImage(cgImage: image, displaySize: displaySize, pngData: pngData)
                ScreenshotSoundPlayer.play(
                    sound: settings.shutterSound,
                    volume: settings.shutterSoundVolume,
                    isEnabled: settings.shutterSoundEnabled,
                )
                if settings.previewEnabled {
                    handleCaptureWithPreview(captured, anchorRect: anchorRect)
                } else {
                    handleCaptureWithoutPreview(captured)
                }
            }
        } catch {
            await MainActor.run {
                AppLog.capture.error("Failed to encode screenshot: \(String(describing: error), privacy: .public)")
                AccessibilityAnnouncer.announce("Screenshot could not be encoded")
            }
        }
        AppSignpost.end("Capture process", id: signpostID)
    }

    private func handleCaptureWithPreview(_ captured: CapturedImage, anchorRect: CGRect?) {
        let previewTimeout = settings.previewTimeout
        let shouldAutoDismiss = previewTimeout != nil
        let autoDismissBehavior = settings.previewAutoDismissBehavior
        let scheduleSave = PreviewSaveScheduler.shouldScheduleSave(previewTimeout: previewTimeout)
        let saveID = outputCoordinator.begin(pngData: captured.pngData, scheduleSave: scheduleSave)
        let replacementBehavior = settings.previewReplacementBehavior
        let autoDismissHandler: (() -> Void)? = shouldAutoDismiss ? { [weak self] in
            guard let self else { return }
            switch autoDismissBehavior {
            case .saveToDisk:
                outputCoordinator.finalize(id: saveID)
            case .discard:
                outputCoordinator.cancel(id: saveID)
            }
        } : nil
        let request = PreviewRequest(
            image: captured.previewImage,
            pngData: captured.pngData,
            filenamePrefix: settings.filenamePrefix,
            timeout: previewTimeout,
            onClose: { [weak self] in
                self?.outputCoordinator.finalize(id: saveID)
            },
            onTrash: { [weak self] in
                self?.outputCoordinator.cancel(id: saveID)
            },
            onOpen: { [weak self] in
                self?.outputCoordinator.finalize(id: saveID) { url in
                    guard let url else {
                        AppLog.output.error("Failed to open saved screenshot: missing file URL")
                        return
                    }
                    if !NSWorkspace.shared.open(url) {
                        AppLog.output.error("Failed to open saved screenshot at \(url.path, privacy: .public)")
                    }
                }
            },
            onReplace: { [weak self] in
                guard let self else { return }
                switch replacementBehavior {
                case .saveImmediately:
                    outputCoordinator.finalize(id: saveID)
                case .discard:
                    outputCoordinator.cancel(id: saveID)
                }
            },
            onAutoDismiss: autoDismissHandler,
            anchorRect: anchorRect,
        )
        previewController.show(request)
    }

    private func handleCaptureWithoutPreview(_ captured: CapturedImage) {
        switch settings.previewDisabledOutputBehavior {
        case .saveToDisk:
            let saveID = outputCoordinator.begin(pngData: captured.pngData, scheduleSave: false)
            outputCoordinator.finalize(id: saveID)
        case .clipboardOnly:
            ClipboardService.copy(pngData: captured.pngData)
        }
    }

    private func displaySize(for image: CGImage, baseRect: CGRect) -> NSSize {
        guard baseRect.width > 0 else {
            return NSSize(width: image.width, height: image.height)
        }
        let scale = CGFloat(image.width) / baseRect.width
        let height = scale > 0 ? CGFloat(image.height) / scale : CGFloat(image.height)
        return NSSize(width: baseRect.width, height: height)
    }

    private func updateScrollingCaptureState(isActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onScrollingCaptureStateChange?(isActive)
        }
    }

    private func beginSession(_ state: CaptureSessionState) -> Bool {
        guard sessionTracker.begin(state) else {
            NSSound.beep()
            AccessibilityAnnouncer.announce("OneShot is already capturing")
            return false
        }
        return true
    }

    private func finishSession(_ state: CaptureSessionState) {
        sessionTracker.finish(state)
    }
}

enum PreviewSaveScheduler {
    static func shouldScheduleSave(previewTimeout: TimeInterval?) -> Bool {
        previewTimeout == nil
    }
}
