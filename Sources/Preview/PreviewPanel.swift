import AppKit

final class PreviewPanel: NSPanel {
    private let content: PreviewContentView
    private let image: NSImage
    private static let padding: CGFloat = 16
    private static let desiredPixelSize = CGSize(width: 600, height: 500)

    init(image: NSImage, onClose: @escaping () -> Void, onTrash: @escaping () -> Void) {
        self.image = image
        let size = PreviewPanel.defaultSize()
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

    func show(on screen: NSScreen?) {
        guard let screen = screen ?? PreviewPanel.targetScreen() else {
            center()
            makeKeyAndOrderFront(nil)
            return
        }

        let safeFrame = PreviewPanel.safeFrame(for: screen)
        let availableSize = NSSize(
            width: max(safeFrame.width - PreviewPanel.padding * 2, 1),
            height: max(safeFrame.height - PreviewPanel.padding * 2, 1)
        )
        let desiredSize = PreviewPanel.desiredSize(for: screen)
        let targetSize = NSSize(
            width: min(desiredSize.width, availableSize.width),
            height: min(desiredSize.height, availableSize.height)
        )
        content.frame = NSRect(origin: .zero, size: targetSize)
        content.autoresizingMask = [.width, .height]
        setContentSize(targetSize)

        let frame = frameRect(forContentRect: NSRect(origin: .zero, size: targetSize))
        var origin = CGPoint(
            x: safeFrame.maxX - frame.width - PreviewPanel.padding,
            y: safeFrame.minY + PreviewPanel.padding
        )

        let minX = safeFrame.minX + PreviewPanel.padding
        let maxX = safeFrame.maxX - frame.width - PreviewPanel.padding
        let minY = safeFrame.minY + PreviewPanel.padding
        let maxY = safeFrame.maxY - frame.height - PreviewPanel.padding

        origin.x = maxX < minX ? minX : min(max(origin.x, minX), maxX)
        origin.y = maxY < minY ? minY : min(max(origin.y, minY), maxY)

        contentMinSize = targetSize
        contentMaxSize = targetSize
        minSize = frame.size
        maxSize = frame.size

        let targetFrame = NSRect(origin: origin, size: frame.size)
        setFrame(targetFrame, display: false)
        orderFrontRegardless()
        setFrame(targetFrame, display: false)
    }

    private static func desiredSize(for screen: NSScreen) -> NSSize {
        let rect = NSRect(origin: .zero, size: desiredPixelSize)
        return screen.convertRectFromBacking(rect).size
    }

    private static func defaultSize() -> NSSize {
        if let screen = NSScreen.main {
            return desiredSize(for: screen)
        }
        return NSSize(
            width: desiredPixelSize.width,
            height: desiredPixelSize.height
        )
    }

    static func screen(for rect: CGRect?) -> NSScreen? {
        guard let rect = rect else {
            return targetScreen()
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let best = screens.max { lhs, rhs in
            rect.intersection(lhs.frame).area < rect.intersection(rhs.frame).area
        }

        if let best = best, rect.intersection(best.frame).area > 0 {
            return best
        }

        return targetScreen()
    }

    private static func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private static func safeFrame(for screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        if visible.width > 0, visible.height > 0 {
            return visible
        }
        return screen.frame
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
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
        addSubview(backgroundView)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        backgroundView.addSubview(imageView)

        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(handleClose)
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = .secondaryLabelColor
        backgroundView.addSubview(closeButton)

        trashButton.bezelStyle = .inline
        trashButton.isBordered = false
        trashButton.target = self
        trashButton.action = #selector(handleTrash)
        trashButton.image = NSImage(systemSymbolName: "trash.circle.fill", accessibilityDescription: "Trash")
        trashButton.contentTintColor = .systemRed
        backgroundView.addSubview(trashButton)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        imageView.frame = bounds.insetBy(dx: contentInset, dy: contentInset)
        closeButton.frame = NSRect(
            x: 8,
            y: bounds.height - 8 - 18,
            width: 18,
            height: 18
        )
        trashButton.frame = NSRect(
            x: bounds.width - 8 - 18,
            y: bounds.height - 8 - 18,
            width: 18,
            height: 18
        )
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
