import AppKit

final class PreviewPanel: NSPanel {
    private let content: PreviewContentView
    private enum Layout {
        static let padding: CGFloat = 16
        static let desiredPixelSize = CGSize(width: 600, height: 500)
    }

    init(image: NSImage, onClose: @escaping () -> Void, onTrash: @escaping () -> Void) {
        let size = PreviewPanel.defaultSize()
        content = PreviewContentView(frame: NSRect(origin: .zero, size: size))
        content.autoresizingMask = [.width, .height]
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
        let padding = Layout.padding
        let availableSize = NSSize(
            width: max(safeFrame.width - padding * 2, 1),
            height: max(safeFrame.height - padding * 2, 1)
        )
        let desiredSize = PreviewPanel.desiredSize(for: screen)
        let targetSize = NSSize(
            width: min(desiredSize.width, availableSize.width),
            height: min(desiredSize.height, availableSize.height)
        )
        let contentRect = NSRect(origin: .zero, size: targetSize)
        content.frame = contentRect
        setContentSize(targetSize)

        let frame = frameRect(forContentRect: contentRect)
        var origin = CGPoint(
            x: safeFrame.maxX - frame.width - padding,
            y: safeFrame.minY + padding
        )

        let minX = safeFrame.minX + padding
        let maxX = safeFrame.maxX - frame.width - padding
        let minY = safeFrame.minY + padding
        let maxY = safeFrame.maxY - frame.height - padding

        origin.x = maxX < minX ? minX : min(max(origin.x, minX), maxX)
        origin.y = maxY < minY ? minY : min(max(origin.y, minY), maxY)

        contentMinSize = targetSize
        contentMaxSize = targetSize
        minSize = frame.size
        maxSize = frame.size

        let targetFrame = NSRect(origin: origin, size: frame.size)
        setFrame(targetFrame, display: false)
        orderFrontRegardless()
        // AppKit can apply intrinsic sizing on first display; re-apply the fixed frame.
        setFrame(targetFrame, display: false)
    }

    private static func desiredSize(for screen: NSScreen) -> NSSize {
        let rect = NSRect(origin: .zero, size: Layout.desiredPixelSize)
        return screen.convertRectFromBacking(rect).size
    }

    private static func defaultSize() -> NSSize {
        if let screen = NSScreen.main {
            return desiredSize(for: screen)
        }
        return NSSize(
            width: Layout.desiredPixelSize.width,
            height: Layout.desiredPixelSize.height
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
    private enum Layout {
        static let contentInset: CGFloat = 10
        static let buttonInset: CGFloat = 8
        static let buttonSize: CGFloat = 18
        static let cornerRadius: CGFloat = 12
    }

    private let backgroundView = NSVisualEffectView()
    private let imageView = PreviewImageView()
    private let closeButton = NSButton()
    private let trashButton = NSButton()
    private var onClose: (() -> Void)?
    private var onTrash: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = Layout.cornerRadius
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
        imageView.frame = bounds.insetBy(dx: Layout.contentInset, dy: Layout.contentInset)
        let buttonOriginY = bounds.height - Layout.buttonInset - Layout.buttonSize
        closeButton.frame = NSRect(
            x: Layout.buttonInset,
            y: buttonOriginY,
            width: Layout.buttonSize,
            height: Layout.buttonSize
        )
        trashButton.frame = NSRect(
            x: bounds.width - Layout.buttonInset - Layout.buttonSize,
            y: buttonOriginY,
            width: Layout.buttonSize,
            height: Layout.buttonSize
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
