import AppKit

final class PreviewController {
    private var panel: PreviewPanel?
    private var hideWorkItem: DispatchWorkItem?

    func show(
        image: NSImage,
        timeout: TimeInterval?,
        onClose: @escaping () -> Void,
        onTrash: @escaping () -> Void,
        onAutoDismiss: (() -> Void)? = nil,
        anchorRect: CGRect? = nil
    ) {
        hideWorkItem?.cancel()

        let panel = PreviewPanel(
            image: image,
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
    }
}
