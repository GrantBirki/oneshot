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
        selectionOverlay.beginSelection { [weak self] rect in
            guard let self = self, let rect = rect else { return }
            self.capture(rect: rect)
        }
    }

    func captureFullScreen() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        if let image = ScreenCaptureService.captureFullScreen() {
            handleCapture(image)
        }
    }

    func captureWindow() {
        guard ScreenCapturePermission.ensureAccess() else { return }
        NSApp.activate(ignoringOtherApps: true)
        windowOverlay.beginSelection { [weak self] windowID in
            guard let self = self, let windowID = windowID else { return }
            if let image = ScreenCaptureService.capture(windowID: windowID) {
                self.handleCapture(image)
            }
        }
    }

    private func capture(rect: CGRect) {
        if let image = ScreenCaptureService.capture(rect: rect) {
            handleCapture(image)
        }
    }

    private func handleCapture(_ image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let saveID = outputCoordinator.begin(image: nsImage)
        if settings.previewEnabled {
            previewController.show(
                image: nsImage,
                timeout: settings.previewTimeout,
                onClose: { [weak self] in
                    self?.outputCoordinator.finalize(id: saveID)
                },
                onTrash: { [weak self] in
                    self?.outputCoordinator.cancel(id: saveID)
                },
                onAutoDismiss: { [weak self] in
                    self?.outputCoordinator.markAutoDismissed(id: saveID)
                }
            )
        } else {
            outputCoordinator.markAutoDismissed(id: saveID)
        }
    }
}
