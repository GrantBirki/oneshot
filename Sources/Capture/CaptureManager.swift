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
            guard let self, let selection else { return }
            capture(rect: selection.rect, excludingWindowID: selection.excludeWindowID)
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
            guard let self, let windowInfo else { return }
            if let image = ScreenCaptureService.capture(windowID: windowInfo.id) {
                handleCapture(image, displaySize: windowInfo.bounds.size, anchorRect: windowInfo.bounds)
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
            let previewTimeout = settings.previewTimeout
            let shouldAutoDismiss = previewTimeout.map { $0 > 0 } ?? false
            let saveID = outputCoordinator.begin(pngData: captured.pngData, scheduleSave: !shouldAutoDismiss)
            if settings.previewEnabled {
                let replacementBehavior = settings.previewReplacementBehavior
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
                    onAutoDismiss: { [weak self] in
                        // Auto-dismiss commits the save and closes the preview together.
                        self?.outputCoordinator.finalize(id: saveID)
                    },
                    anchorRect: anchorRect,
                )
                previewController.show(request)
            } else {
                outputCoordinator.finalize(id: saveID)
            }
        } catch {
            NSLog("Failed to encode screenshot: \(error)")
        }
    }
}
