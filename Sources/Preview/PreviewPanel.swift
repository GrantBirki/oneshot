import AppKit

final class PreviewPanel: NSPanel {
    private let content: PreviewContentView
    private static let padding: CGFloat = 16
    private static let contentInset: CGFloat = 10
    private static let maxSize = NSSize(width: 360, height: 220)
    private static let minSize = NSSize(width: 200, height: 130)

    init(image: NSImage, onClose: @escaping () -> Void, onTrash: @escaping () -> Void) {
        let size = PreviewPanel.preferredSize(for: image)
        content = PreviewContentView(frame: NSRect(origin: .zero, size: size))
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        content.configure(image: image, onClose: onClose, onTrash: onTrash)
        contentView = content
    }

    func show() {
        guard let screen = PreviewPanel.targetScreen() else {
            center()
            makeKeyAndOrderFront(nil)
            return
        }

        let visible = screen.visibleFrame
        var frame = frameRect(forContentRect: content.bounds)
        let maxWidth = max(visible.width - PreviewPanel.padding * 2, PreviewPanel.minSize.width)
        let maxHeight = max(visible.height - PreviewPanel.padding * 2, PreviewPanel.minSize.height)

        if frame.width > maxWidth || frame.height > maxHeight {
            setContentSize(NSSize(width: min(frame.width, maxWidth), height: min(frame.height, maxHeight)))
            frame = frameRect(forContentRect: content.bounds)
        }
        var origin = CGPoint(
            x: visible.maxX - frame.width - PreviewPanel.padding,
            y: visible.minY + PreviewPanel.padding
        )

        origin.x = min(max(origin.x, visible.minX + PreviewPanel.padding), visible.maxX - frame.width - PreviewPanel.padding)
        origin.y = min(max(origin.y, visible.minY + PreviewPanel.padding), visible.maxY - frame.height - PreviewPanel.padding)

        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    private static func preferredSize(for image: NSImage) -> NSSize {
        let imageSize = image.size
        let maxContentWidth = maxSize.width - contentInset * 2
        let maxContentHeight = maxSize.height - contentInset * 2
        let widthRatio = maxContentWidth / imageSize.width
        let heightRatio = maxContentHeight / imageSize.height
        let scale = min(widthRatio, heightRatio, 1)
        let contentWidth = imageSize.width * scale
        let contentHeight = imageSize.height * scale
        let width = min(max(contentWidth + contentInset * 2, minSize.width), maxSize.width)
        let height = min(max(contentHeight + contentInset * 2, minSize.height), maxSize.height)
        return NSSize(width: width, height: height)
    }

    private static func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}

final class PreviewContentView: NSView {
    private let backgroundView = NSVisualEffectView()
    private let imageView = PreviewImageView()
    private let closeButton = NSButton()
    private let trashButton = NSButton()
    private var onClose: (() -> Void)?
    private var onTrash: (() -> Void)?
    private let contentInset: CGFloat = 10

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 12
        backgroundView.layer?.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(imageView)

        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(handleClose)
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(closeButton)

        trashButton.bezelStyle = .inline
        trashButton.isBordered = false
        trashButton.target = self
        trashButton.action = #selector(handleTrash)
        trashButton.image = NSImage(systemSymbolName: "trash.circle.fill", accessibilityDescription: "Trash")
        trashButton.contentTintColor = .systemRed
        trashButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(trashButton)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: contentInset),
            imageView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -contentInset),
            imageView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: contentInset),
            imageView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -contentInset),

            closeButton.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 8),
            closeButton.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            trashButton.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -8),
            trashButton.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 8),
            trashButton.widthAnchor.constraint(equalToConstant: 18),
            trashButton.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(image: NSImage, onClose: @escaping () -> Void, onTrash: @escaping () -> Void) {
        imageView.image = image
        imageView.onOpen = { [weak self] in
            self?.openImage(image)
        }
        self.onClose = onClose
        self.onTrash = onTrash
    }

    private func openImage(_ image: NSImage) {
        let filename = FilenameFormatter.makeFilename(prefix: "screenshot")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            _ = try FileSaveService.save(image: image, to: tempURL.deletingLastPathComponent(), filename: filename)
            NSWorkspace.shared.open(tempURL)
        } catch {
            NSLog("Failed to open preview image: \(error)")
        }
    }

    @objc private func handleClose() {
        onClose?()
    }

    @objc private func handleTrash() {
        onTrash?()
    }
}

final class PreviewImageView: NSImageView, NSDraggingSource {
    var onOpen: (() -> Void)?
    private var didDrag = false
    private var draggingSessionStarted = false

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        draggingSessionStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !draggingSessionStarted, let image = image else { return }
        didDrag = true
        draggingSessionStarted = true

        let draggingItem = NSDraggingItem(pasteboardWriter: image)
        let dragFrame = bounds
        draggingItem.setDraggingFrame(dragFrame, contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onOpen?()
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        draggingSessionStarted = false
    }
}
