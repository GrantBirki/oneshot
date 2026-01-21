import AppKit

final class CaptureManager {
    private let settings: SettingsStore
    private let selectionOverlay = SelectionOverlayController()
    private let windowOverlay = WindowCaptureOverlayController()
    private let outputCoordinator: OutputCoordinator
    private let previewController = PreviewController()
    private let scrollingCaptureSession = ScrollingCaptureSession()
    private let scrollingOverlay = ScrollingCaptureOverlayController()

    var onScrollingCaptureStateChange: ((Bool) -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
        outputCoordinator = OutputCoordinator(settings: settings)
    }

    func captureSelection() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        selectionOverlay.beginSelection(
            showSelectionCoordinates: settings.showSelectionCoordinates,
            visualCue: settings.selectionVisualCue,
            dimmingMode: settings.selectionDimmingMode,
            selectionDimmingColor: settings.selectionDimmingColor,
        ) { [weak self] selection in
            guard let self, let selection else { return }
            Task { [weak self] in
                guard let self else { return }
                if let image = await ScreenCaptureService.capture(
                    rect: selection.rect,
                    excludingWindowID: selection.excludeWindowID,
                ) {
                    await MainActor.run {
                        self.handleCapture(image, displaySize: selection.rect.size, anchorRect: selection.rect)
                    }
                }
            }
        }
    }

    func captureFullScreen() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        Task { [weak self] in
            guard let self else { return }
            guard let image = await ScreenCaptureService.captureFullScreen() else { return }
            await MainActor.run {
                let frame = ScreenFrameHelper.allScreensFrame()
                let size = frame?.size ?? NSSize(width: image.width, height: image.height)
                self.handleCapture(image, displaySize: size, anchorRect: frame)
            }
        }
    }

    func captureWindow() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        windowOverlay.beginSelection { [weak self] windowInfo in
            guard let self, let windowInfo else { return }
            Task { [weak self] in
                guard let self else { return }
                if let image = await ScreenCaptureService.capture(windowID: windowInfo.id) {
                    await MainActor.run {
                        self.handleCapture(image, displaySize: windowInfo.bounds.size, anchorRect: windowInfo.bounds)
                    }
                }
            }
        }
    }

    func captureScrolling() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        if scrollingCaptureSession.isActive {
            scrollingCaptureSession.stop()
            return
        }

        selectionOverlay.beginSelection(
            showSelectionCoordinates: settings.showSelectionCoordinates,
            visualCue: settings.selectionVisualCue,
            dimmingMode: settings.selectionDimmingMode,
            selectionDimmingColor: settings.selectionDimmingColor,
        ) { [weak self] selection in
            guard let self, let selection else { return }
            let anchorRect = selection.rect.integral
            updateScrollingCaptureState(isActive: true)
            scrollingOverlay.show(selectionRect: anchorRect) { [weak self] in
                self?.scrollingCaptureSession.stop()
            }
            scrollingCaptureSession.start(rect: anchorRect) { [weak self] image in
                guard let self else { return }
                scrollingOverlay.hide()
                updateScrollingCaptureState(isActive: false)
                guard let image else { return }
                let displaySize = displaySize(for: image, baseRect: anchorRect)
                handleCapture(image, displaySize: displaySize, anchorRect: anchorRect)
            }
        }
    }

    private func handleCapture(_ image: CGImage, displaySize: NSSize, anchorRect: CGRect?) {
        do {
            let captured = try CapturedImage(cgImage: image, displaySize: displaySize)
            ScreenshotSoundPlayer.play()
            if settings.previewEnabled {
                handleCaptureWithPreview(captured, anchorRect: anchorRect)
            } else {
                handleCaptureWithoutPreview(captured)
            }
        } catch {
            NSLog("Failed to encode screenshot: \(error)")
        }
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
                        NSLog("Failed to open saved screenshot: missing file URL")
                        return
                    }
                    if !NSWorkspace.shared.open(url) {
                        NSLog("Failed to open saved screenshot at \(url.path)")
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
}

enum PreviewSaveScheduler {
    static func shouldScheduleSave(previewTimeout: TimeInterval?) -> Bool {
        previewTimeout == nil
    }
}
