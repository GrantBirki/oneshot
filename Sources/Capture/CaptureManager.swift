import AppKit

final class CaptureManager {
    private let settings: SettingsStore
    private let selectionOverlay = SelectionOverlayController()
    private let windowOverlay = WindowCaptureOverlayController()
    private let outputCoordinator: OutputCoordinator
    private let previewController = PreviewController()

    init(settings: SettingsStore) {
        self.settings = settings
        outputCoordinator = OutputCoordinator(settings: settings)
    }

    func captureSelection() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        NSApp.activate(ignoringOtherApps: true)
        selectionOverlay.beginSelection { [weak self] selection in
            guard let self = self, let selection = selection else { return }
            self.capture(rect: selection.rect, excludingWindowID: selection.excludeWindowID)
        }
    }

    func captureFullScreen() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        if let image = ScreenCaptureService.captureFullScreen() {
            let size = ScreenFrameHelper.allScreensFrame()?.size ?? NSSize(width: image.width, height: image.height)
            handleCapture(image, displaySize: size, anchorRect: ScreenFrameHelper.allScreensFrame())
        }
    }

    func captureWindow() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        NSApp.activate(ignoringOtherApps: true)
        windowOverlay.beginSelection { [weak self] windowInfo in
            guard let self = self, let windowInfo = windowInfo else { return }
            if let image = ScreenCaptureService.capture(windowID: windowInfo.id) {
                self.handleCapture(image, displaySize: windowInfo.bounds.size, anchorRect: windowInfo.bounds)
            }
        }
    }

    private func capture(rect: CGRect, excludingWindowID: CGWindowID?) {
        if let image = ScreenCaptureService.capture(rect: rect, excludingWindowID: excludingWindowID) {
            handleCapture(image, displaySize: rect.size, anchorRect: rect)
        }
    }

    private func handleCapture(_ image: CGImage, displaySize: NSSize, anchorRect: CGRect?) {
        do {
            let captured = try CapturedImage(cgImage: image, displaySize: displaySize)
            let saveID = outputCoordinator.begin(pngData: captured.pngData)
            if settings.previewEnabled {
                let replacementBehavior = settings.previewReplacementBehavior
                previewController.show(
                    image: captured.previewImage,
                    pngData: captured.pngData,
                    filenamePrefix: settings.filenamePrefix,
                    timeout: settings.previewTimeout,
                    onClose: { [weak self] in
                        self?.outputCoordinator.finalize(id: saveID)
                    },
                    onTrash: { [weak self] in
                        self?.outputCoordinator.cancel(id: saveID)
                    },
                    onReplace: { [weak self] in
                        guard let self = self else { return }
                        switch replacementBehavior {
                        case .saveImmediately:
                            self.outputCoordinator.finalize(id: saveID)
                        case .discard:
                            self.outputCoordinator.cancel(id: saveID)
                        }
                    },
                    onAutoDismiss: { [weak self] in
                        self?.outputCoordinator.markAutoDismissed(id: saveID)
                    },
                    anchorRect: anchorRect
                )
            } else {
                outputCoordinator.markAutoDismissed(id: saveID)
            }
        } catch {
            NSLog("Failed to encode screenshot: \(error)")
        }
    }
}
