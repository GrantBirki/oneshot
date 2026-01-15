import AppKit

final class PreviewPanel: NSPanel {
    private let content: PreviewContentView
    private enum Layout {
        static let padding: CGFloat = 16
        static let desiredPixelSize = CGSize(width: 600, height: 500)
    }

    init(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        onClose: @escaping () -> Void,
        onTrash: @escaping () -> Void
    ) {
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

        content.configure(
            image: image,
            pngData: pngData,
            filenamePrefix: filenamePrefix,
            onClose: onClose,
            onTrash: onTrash
        )
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
        static let actionBarHeight: CGFloat = 28
        static let actionFontSize: CGFloat = 12
        static let cornerRadius: CGFloat = 12
    }

    private static let tempFileCleanupDelay: TimeInterval = 60

    private let backgroundView = NSVisualEffectView()
    private let imageView = PreviewImageView()
    private let closeButton = NSButton()
    private let trashButton = NSButton()
    private var dragPayload: PreviewDragPayload?
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

        configureActionButton(
            closeButton,
            title: "X",
            textColor: .labelColor,
            backgroundColor: .windowBackgroundColor,
            accessibilityLabel: "Dismiss preview",
            identifier: "preview-close"
        )
        closeButton.target = self
        closeButton.action = #selector(handleClose)
        backgroundView.addSubview(closeButton)

        configureActionButton(
            trashButton,
            title: "Del",
            textColor: .white,
            backgroundColor: .systemRed,
            accessibilityLabel: "Delete screenshot",
            identifier: "preview-trash"
        )
        trashButton.target = self
        trashButton.action = #selector(handleTrash)
        backgroundView.addSubview(trashButton)
    }

    required init?(coder _: NSCoder) {
        return nil
    }

    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        let actionBarHeight = Layout.actionBarHeight
        let imageHeight = max(bounds.height - actionBarHeight, 0)
        imageView.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: imageHeight
        )
        let buttonOriginY = imageHeight
        let buttonWidth = bounds.width / 2
        closeButton.frame = NSRect(
            x: 0,
            y: buttonOriginY,
            width: buttonWidth,
            height: actionBarHeight
        )
        trashButton.frame = NSRect(
            x: buttonWidth,
            y: buttonOriginY,
            width: bounds.width - buttonWidth,
            height: actionBarHeight
        )
    }

    func configure(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        onClose: @escaping () -> Void,
        onTrash: @escaping () -> Void
    ) {
        imageView.image = image
        let payload = PreviewDragPayload(
            image: image,
            pngData: pngData,
            filenamePrefix: filenamePrefix
        )
        dragPayload = payload
        imageView.dragPayload = payload
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
            let opened = NSWorkspace.shared.open(tempURL)
            if !opened {
                NSLog("Failed to open preview image at \(tempURL.path)")
            }
            scheduleTempCleanup(for: tempURL)
        } catch {
            NSLog("Failed to open preview image: \(error)")
        }
    }

    private func scheduleTempCleanup(for url: URL) {
        let delay = PreviewContentView.tempFileCleanupDelay
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @objc private func handleClose() {
        onClose?()
    }

    @objc private func handleTrash() {
        onTrash?()
    }

    private func configureActionButton(
        _ button: NSButton,
        title: String,
        textColor: NSColor,
        backgroundColor: NSColor,
        accessibilityLabel: String,
        identifier: String
    ) {
        button.bezelStyle = .inline
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = backgroundColor.cgColor
        button.layer?.masksToBounds = true
        button.attributedTitle = actionTitle(title, textColor: textColor)
        button.setAccessibilityLabel(accessibilityLabel)
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
    }

    private func actionTitle(_ title: String, textColor: NSColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Layout.actionFontSize, weight: .semibold),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]
        return NSAttributedString(string: title, attributes: attributes)
    }
}

final class PreviewImageView: NSImageView, NSDraggingSource {
    var onOpen: (() -> Void)?
    var dragPayload: PreviewDragPayload?
    private var didDrag = false
    private var draggingSessionStarted = false

    override func mouseDown(with _: NSEvent) {
        didDrag = false
        draggingSessionStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !draggingSessionStarted, let payload = dragPayload else { return }
        guard let draggingItem = payload.makeDraggingItem(dragFrame: bounds) else { return }
        didDrag = true
        draggingSessionStarted = true

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with _: NSEvent) {
        if !didDrag {
            onOpen?()
        }
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        draggingSessionStarted = false
        dragPayload?.rescheduleCleanup()
    }
}
