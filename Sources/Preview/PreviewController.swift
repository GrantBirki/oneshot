import AppKit

struct PreviewRequest {
    let image: NSImage
    let pngData: Data
    let filenamePrefix: String
    let timeout: TimeInterval?
    let onClose: () -> Void
    let onTrash: () -> Void
    let onReplace: () -> Void
    let onAutoDismiss: (() -> Void)?
    let anchorRect: CGRect?
}

final class PreviewController {
    private var panel: PreviewPanel?
    private var hideWorkItem: DispatchWorkItem?
    private var replaceAction: (() -> Void)?

    func show(_ request: PreviewRequest) {
        dismissForReplacement()
        hideWorkItem?.cancel()

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
        )
        panel.show(on: PreviewPanel.screen(for: request.anchorRect))
        self.panel = panel
        replaceAction = { [weak self] in
            request.onReplace()
            self?.hide()
        }

        if let timeout = request.timeout, timeout > 0 {
            let workItem = DispatchWorkItem { [weak self] in
                request.onAutoDismiss?()
                self?.hide()
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
        }
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel?.close()
        panel = nil
        replaceAction = nil
    }

    private func dismissForReplacement() {
        guard panel != nil else { return }
        replaceAction?()
    }
}
