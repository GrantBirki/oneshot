import AppKit

struct PreviewContentConfiguration {
    let image: NSImage
    let pngData: Data
    let filenamePrefix: String
    let onClose: () -> Void
    let onTrash: () -> Void
    let onOpen: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onDragChanged: (Bool) -> Void
}

@MainActor
final class PreviewContentView: NSView {
    private enum Layout {
        static let cornerRadius: CGFloat = 12
        static let buttonSize: CGFloat = 28
        static let cornerButtonInsetX: CGFloat = 0
        static let cornerButtonInsetY: CGFloat = 0
        static let buttonOverlap: CGFloat = 4
        static let buttonSymbolPointSize: CGFloat = 12
        static let hoverFadeDuration: TimeInterval = 0.12
        static let hoverScale: CGFloat = 0.95
    }

    #if DEBUG
        private enum Debug {
            static let logHitTesting = true
            static let logActions = true
            static let logViewHierarchy = true
            @MainActor
            static var didLogViewHierarchy = false
        }
    #endif

    private static var transparentBackgroundColor: NSColor {
        .clear
    }

    private let backgroundView = NSGlassEffectView()
    private let imageView = PreviewImageView()
    private let actionContainerView = NSGlassEffectContainerView()
    private let actionOverlayView = PreviewActionOverlayView()
    private let closeGlassView = NSGlassEffectView()
    private let trashGlassView = NSGlassEffectView()
    private let closeButton = PreviewActionButton(
        symbolName: "checkmark",
        symbolPointSize: Layout.buttonSymbolPointSize,
        tintColor: .labelColor,
        backgroundColor: PreviewContentView.transparentBackgroundColor,
        hoverBackgroundColor: PreviewContentView.transparentBackgroundColor,
        accessibilityLabel: "Save screenshot",
        identifier: "preview-close",
    )
    private let trashButton = PreviewActionButton(
        symbolName: "trash",
        symbolPointSize: Layout.buttonSymbolPointSize,
        tintColor: .white,
        backgroundColor: PreviewContentView.transparentBackgroundColor,
        hoverBackgroundColor: PreviewContentView.transparentBackgroundColor,
        accessibilityLabel: "Delete screenshot",
        identifier: "preview-trash",
    )
    private var dragPayload: PreviewDragPayload?
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false
    private var onClose: (() -> Void)?
    private var onTrash: (() -> Void)?
    private var onHoverChanged: ((Bool) -> Void)?
    private var onDragChanged: ((Bool) -> Void)?
    private var isActionOverlayActive: Bool {
        !actionOverlayView.isHidden
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        backgroundView.style = .regular
        backgroundView.cornerRadius = Layout.cornerRadius
        backgroundView.clipsToBounds = true
        addSubview(backgroundView)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        backgroundView.contentView = imageView

        closeButton.target = self
        closeButton.action = #selector(handleClose)
        closeButton.autoresizingMask = [.width, .height]

        trashButton.target = self
        trashButton.action = #selector(handleTrash)
        trashButton.autoresizingMask = [.width, .height]

        closeGlassView.style = .regular
        closeGlassView.cornerRadius = Layout.buttonSize / 2
        closeGlassView.contentView = closeButton

        trashGlassView.style = .regular
        trashGlassView.cornerRadius = Layout.buttonSize / 2
        trashGlassView.tintColor = .systemRed
        trashGlassView.contentView = trashButton

        actionContainerView.spacing = 8
        actionContainerView.contentView = actionOverlayView

        actionOverlayView.wantsLayer = true
        actionOverlayView.alphaValue = 0
        actionOverlayView.isHidden = true
        actionOverlayView.addSubview(closeGlassView)
        actionOverlayView.addSubview(trashGlassView)
        addSubview(actionContainerView, positioned: .above, relativeTo: backgroundView)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateHoverState(animated: false)
        logViewHierarchyIfNeeded()
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isActionOverlayActive {
            let overlayPoint = actionOverlayView.convert(point, from: self)
            if closeGlassView.frame.contains(overlayPoint) {
                logHitTest(closeButton)
                return closeButton
            }
            if trashGlassView.frame.contains(overlayPoint) {
                logHitTest(trashButton)
                return trashButton
            }
        }

        if bounds.contains(point) {
            logHitTest(imageView)
            return imageView
        }

        let hit = super.hitTest(point)
        logHitTest(hit)
        return hit
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        setHoverState(true, animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHoverState(false, animated: true)
    }

    override func layout() {
        super.layout()
        let overlap = Layout.buttonOverlap
        backgroundView.frame = bounds.insetBy(dx: overlap, dy: overlap)
        imageView.frame = backgroundView.bounds
        actionContainerView.frame = bounds
        actionOverlayView.frame = actionContainerView.bounds
        let buttonSize = Layout.buttonSize
        let insetX = Layout.cornerButtonInsetX
        let insetY = Layout.cornerButtonInsetY
        let buttonOriginY = bounds.height - buttonSize - insetY
        closeGlassView.frame = NSRect(
            x: insetX,
            y: buttonOriginY,
            width: buttonSize,
            height: buttonSize,
        )
        trashGlassView.frame = NSRect(
            x: bounds.width - buttonSize - insetX,
            y: buttonOriginY,
            width: buttonSize,
            height: buttonSize,
        )
        closeButton.frame = closeGlassView.bounds
        trashButton.frame = trashGlassView.bounds
    }
}

extension PreviewContentView {
    func configure(with configuration: PreviewContentConfiguration) {
        onClose = configuration.onClose
        onTrash = configuration.onTrash
        onHoverChanged = configuration.onHoverChanged
        onDragChanged = configuration.onDragChanged

        imageView.image = configuration.image
        let payload = PreviewDragPayload(
            image: configuration.image,
            pngData: configuration.pngData,
            filenamePrefix: configuration.filenamePrefix,
        )
        dragPayload = payload
        imageView.dragPayload = payload
        imageView.onOpen = { [weak self] in
            #if DEBUG
                if let self, Debug.logActions {
                    logDebug("Tile clicked -> open")
                }
            #endif
            configuration.onOpen()
        }
        imageView.onDragStateChanged = { [weak self] dragging in
            guard let self else { return }
            onDragChanged?(dragging)
            if !dragging {
                updateHoverState(animated: false)
            }
        }
        imageView.shouldIgnoreEvent = { [weak self] event in
            guard let self else { return false }
            let point = convert(event.locationInWindow, from: nil)
            return isPointInActionButtons(point)
        }
    }

    #if DEBUG
        func setActionsVisibleForTesting(_ visible: Bool) {
            setHoverState(visible, animated: false)
        }
    #endif

    func performClose() {
        handleClose()
    }

    func performTrash() {
        handleTrash()
    }

    @objc private func handleClose() {
        #if DEBUG
            if Debug.logActions {
                logDebug("Save clicked")
            }
        #endif
        onClose?()
    }

    @objc private func handleTrash() {
        #if DEBUG
            if Debug.logActions {
                logDebug("Trash clicked")
            }
        #endif
        onTrash?()
    }

    private func isPointInActionButtons(_ point: NSPoint) -> Bool {
        guard isActionOverlayActive else { return false }
        let overlayPoint = actionOverlayView.convert(point, from: self)
        return closeGlassView.frame.contains(overlayPoint) || trashGlassView.frame.contains(overlayPoint)
    }
}

private extension PreviewContentView {
    func updateHoverState(animated: Bool) {
        guard let window else { return }
        let location = window.mouseLocationOutsideOfEventStream
        let local = convert(location, from: nil)
        setHoverState(bounds.contains(local), animated: animated)
    }

    func setHoverState(_ hovered: Bool, animated: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        onHoverChanged?(hovered)
        let duration = animated ? Layout.hoverFadeDuration : 0

        if hovered {
            actionOverlayView.isHidden = false
            actionOverlayView.alphaValue = 0
            closeButton.setBaseScale(Layout.hoverScale, duration: 0)
            trashButton.setBaseScale(Layout.hoverScale, duration: 0)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            actionOverlayView.animator().alphaValue = hovered ? 1 : 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !isHovered {
                    actionOverlayView.isHidden = true
                }
            }
        }

        let targetScale: CGFloat = hovered ? 1 : Layout.hoverScale
        closeButton.setBaseScale(targetScale, duration: duration)
        trashButton.setBaseScale(targetScale, duration: duration)
    }
}

private extension PreviewContentView {
    func logHitTest(_ view: NSView?) {
        #if DEBUG
            guard Debug.logHitTesting else { return }
            let name = view.map { String(describing: type(of: $0)) } ?? "nil"
            logDebug("hitTest -> \(name)")
        #endif
    }

    func logViewHierarchyIfNeeded() {
        #if DEBUG
            guard Debug.logViewHierarchy, !Debug.didLogViewHierarchy else { return }
            Debug.didLogViewHierarchy = true
            let description = viewHierarchyDescription(for: self, indent: "")
            logDebug("View hierarchy:\n\(description)")
        #endif
    }

    func logDebug(_ message: String) {
        #if DEBUG
            AppLog.preview.debug("PreviewTile: \(message, privacy: .public)")
        #endif
    }

    #if DEBUG
        func viewHierarchyDescription(for view: NSView, indent: String) -> String {
            var lines = ["\(indent)\(type(of: view)) frame=\(view.frame) hidden=\(view.isHidden)"]
            for subview in view.subviews {
                lines.append(viewHierarchyDescription(for: subview, indent: indent + "  "))
            }
            return lines.joined(separator: "\n")
        }
    #endif
}
