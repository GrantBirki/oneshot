import AppKit

final class PreviewController {
    private var panel: PreviewPanel?
    private var hideWorkItem: DispatchWorkItem?
    private var replaceAction: (() -> Void)?

    func show(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        timeout: TimeInterval?,
        onClose: @escaping () -> Void,
        onTrash: @escaping () -> Void,
        onReplace: @escaping () -> Void,
        onAutoDismiss: (() -> Void)? = nil,
        anchorRect: CGRect? = nil
    ) {
        dismissForReplacement()
        hideWorkItem?.cancel()

        let panel = PreviewPanel(
            image: image,
            pngData: pngData,
            filenamePrefix: filenamePrefix,
            onClose: { [weak self] in
                onClose()
                self?.hide()
            },
            onTrash: { [weak self] in
                onTrash()
                self?.hide()
            }
        )
        panel.show(on: PreviewPanel.screen(for: anchorRect))
        self.panel = panel
        replaceAction = { [weak self] in
            onReplace()
            self?.hide()
        }

        if let timeout = timeout, timeout > 0 {
            let workItem = DispatchWorkItem { [weak self] in
                onAutoDismiss?()
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
