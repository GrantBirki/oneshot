import AppKit

final class PreviewPanel: NSPanel {
    private let content: PreviewContentView
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?

    private enum Layout {
        static let padding: CGFloat = 16
        static let desiredPixelSize = CGSize(width: 600, height: 500)
    }

    private enum KeyCodes {
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51
    }

    init(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        onClose: @escaping () -> Void,
        onTrash: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onDragChanged: @escaping (Bool) -> Void,
    ) {
        let size = PreviewPanel.defaultSize()
        content = PreviewContentView(frame: NSRect(origin: .zero, size: size))
        content.autoresizingMask = [.width, .height]
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
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
            onTrash: onTrash,
            onOpen: onOpen,
            onHoverChanged: onHoverChanged,
            onDragChanged: onDragChanged,
        )
        contentView = content
    }

    func show(on screen: NSScreen?) {
        guard let screen = screen ?? PreviewPanel.targetScreen() else {
            center()
            makeKeyAndOrderFront(nil)
            startKeyMonitor()
            return
        }

        let safeFrame = PreviewPanel.safeFrame(for: screen)
        let padding = Layout.padding
        let availableSize = NSSize(
            width: max(safeFrame.width - padding * 2, 1),
            height: max(safeFrame.height - padding * 2, 1),
        )
        let desiredSize = PreviewPanel.desiredSize(for: screen)
        let targetSize = NSSize(
            width: min(desiredSize.width, availableSize.width),
            height: min(desiredSize.height, availableSize.height),
        )
        let contentRect = NSRect(origin: .zero, size: targetSize)
        content.frame = contentRect
        setContentSize(targetSize)

        let frame = frameRect(forContentRect: contentRect)
        var origin = CGPoint(
            x: safeFrame.maxX - frame.width - padding,
            y: safeFrame.minY + padding,
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
        startKeyMonitor()
    }

    override func close() {
        stopKeyMonitor()
        super.close()
    }

    private func startKeyMonitor() {
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                if handleKeyEvent(event) {
                    return nil
                }
                return event
            }
        }

        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard !NSApp.isActive else { return }
                    _ = handleKeyEvent(event)
                }
            }
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil

        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalKeyMonitor = nil
    }

    deinit {
        stopKeyMonitor()
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }
        if event.keyCode == KeyCodes.escape {
            content.performClose()
            return true
        }
        if event.keyCode == KeyCodes.delete, event.modifierFlags.contains(.command) {
            content.performTrash()
            return true
        }
        return false
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
            height: Layout.desiredPixelSize.height,
        )
    }

    static func screen(for rect: CGRect?) -> NSScreen? {
        guard let rect else {
            return targetScreen()
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let best = screens.max { lhs, rhs in
            rect.intersection(lhs.frame).area < rect.intersection(rhs.frame).area
        }

        if let best, rect.intersection(best.frame).area > 0 {
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
            static var didLogViewHierarchy = false
        }
    #endif

    private static var closeBackgroundColor: NSColor {
        NSColor.controlBackgroundColor.withAlphaComponent(0.8)
    }

    private static var closeHoverBackgroundColor: NSColor {
        NSColor.controlBackgroundColor.withAlphaComponent(0.95)
    }

    private static var deleteBackgroundColor: NSColor {
        NSColor.systemRed.withAlphaComponent(0.8)
    }

    private static var deleteHoverBackgroundColor: NSColor {
        NSColor.systemRed.withAlphaComponent(1.0)
    }

    private let backgroundView = NSVisualEffectView()
    private let imageView = PreviewImageView()
    private let actionOverlayView = PreviewActionOverlayView()
    private let closeButton = PreviewActionButton(
        symbolName: "checkmark",
        symbolPointSize: Layout.buttonSymbolPointSize,
        tintColor: .labelColor,
        backgroundColor: PreviewContentView.closeBackgroundColor,
        hoverBackgroundColor: PreviewContentView.closeHoverBackgroundColor,
        accessibilityLabel: "Save screenshot",
        identifier: "preview-close",
    )
    private let trashButton = PreviewActionButton(
        symbolName: "trash",
        symbolPointSize: Layout.buttonSymbolPointSize,
        tintColor: .white,
        backgroundColor: PreviewContentView.deleteBackgroundColor,
        hoverBackgroundColor: PreviewContentView.deleteHoverBackgroundColor,
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
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = Layout.cornerRadius
        backgroundView.layer?.masksToBounds = true
        addSubview(backgroundView)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        backgroundView.addSubview(imageView)

        closeButton.target = self
        closeButton.action = #selector(handleClose)

        trashButton.target = self
        trashButton.action = #selector(handleTrash)

        actionOverlayView.wantsLayer = true
        actionOverlayView.alphaValue = 0
        actionOverlayView.isHidden = true
        actionOverlayView.addSubview(closeButton)
        actionOverlayView.addSubview(trashButton)
        addSubview(actionOverlayView, positioned: .above, relativeTo: backgroundView)
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
            if closeButton.frame.contains(overlayPoint) {
                logHitTest(closeButton)
                return closeButton
            }
            if trashButton.frame.contains(overlayPoint) {
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
        actionOverlayView.frame = bounds
        let buttonSize = Layout.buttonSize
        let insetX = Layout.cornerButtonInsetX
        let insetY = Layout.cornerButtonInsetY
        let buttonOriginY = bounds.height - buttonSize - insetY
        closeButton.frame = NSRect(
            x: insetX,
            y: buttonOriginY,
            width: buttonSize,
            height: buttonSize,
        )
        trashButton.frame = NSRect(
            x: bounds.width - buttonSize - insetX,
            y: buttonOriginY,
            width: buttonSize,
            height: buttonSize,
        )
    }

    func configure(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        onClose: @escaping () -> Void,
        onTrash: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onDragChanged: @escaping (Bool) -> Void,
    ) {
        self.onClose = onClose
        self.onTrash = onTrash
        self.onHoverChanged = onHoverChanged
        self.onDragChanged = onDragChanged

        imageView.image = image
        let payload = PreviewDragPayload(
            image: image,
            pngData: pngData,
            filenamePrefix: filenamePrefix,
        )
        dragPayload = payload
        imageView.dragPayload = payload
        imageView.onOpen = { [weak self] in
            #if DEBUG
                if let self, Debug.logActions {
                    logDebug("Tile clicked -> open")
                }
            #endif
            onOpen()
        }
        imageView.onDragStateChanged = { [weak self] dragging in
            guard let self else { return }
            self.onDragChanged?(dragging)
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
        return closeButton.frame.contains(overlayPoint) || trashButton.frame.contains(overlayPoint)
    }

    private func logHitTest(_ view: NSView?) {
        #if DEBUG
            guard Debug.logHitTesting else { return }
            let name = view.map { String(describing: type(of: $0)) } ?? "nil"
            logDebug("hitTest -> \(name)")
        #endif
    }

    private func logViewHierarchyIfNeeded() {
        #if DEBUG
            guard Debug.logViewHierarchy, !Debug.didLogViewHierarchy else { return }
            Debug.didLogViewHierarchy = true
            let description = viewHierarchyDescription(for: self, indent: "")
            logDebug("View hierarchy:\n\(description)")
        #endif
    }

    private func logDebug(_ message: String) {
        #if DEBUG
            NSLog("PreviewTile: \(message)")
        #endif
    }

    #if DEBUG
        private func viewHierarchyDescription(for view: NSView, indent: String) -> String {
            var lines = ["\(indent)\(type(of: view)) frame=\(view.frame) hidden=\(view.isHidden)"]
            for subview in view.subviews {
                lines.append(viewHierarchyDescription(for: subview, indent: indent + "  "))
            }
            return lines.joined(separator: "\n")
        }
    #endif

    private func updateHoverState(animated: Bool) {
        guard let window else { return }
        let location = window.mouseLocationOutsideOfEventStream
        let local = convert(location, from: nil)
        setHoverState(bounds.contains(local), animated: animated)
    }

    private func setHoverState(_ hovered: Bool, animated: Bool) {
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
            guard let self else { return }
            if !isHovered {
                actionOverlayView.isHidden = true
            }
        }

        let targetScale: CGFloat = hovered ? 1 : Layout.hoverScale
        closeButton.setBaseScale(targetScale, duration: duration)
        trashButton.setBaseScale(targetScale, duration: duration)
    }
}

final class PreviewActionOverlayView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        for subview in subviews.reversed() {
            let converted = subview.convert(point, from: self)
            if let hit = subview.hitTest(converted) {
                return hit
            }
        }
        return nil
    }
}

final class PreviewActionButton: NSButton {
    private enum Scale {
        static let hover: CGFloat = 1.06
        static let press: CGFloat = 0.95
    }

    private enum Animation {
        static let hoverDuration: TimeInterval = 0.08
        static let pressDuration: TimeInterval = 0.06
    }

    private let normalBackgroundColor: NSColor
    private let hoverBackgroundColor: NSColor
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false
    private var baseScale: CGFloat = 1

    init(
        symbolName: String,
        symbolPointSize: CGFloat,
        tintColor: NSColor,
        backgroundColor: NSColor,
        hoverBackgroundColor: NSColor,
        accessibilityLabel: String,
        identifier: String,
    ) {
        normalBackgroundColor = backgroundColor
        self.hoverBackgroundColor = hoverBackgroundColor
        super.init(frame: .zero)
        setButtonType(.momentaryChange)
        bezelStyle = .regularSquare
        isBordered = false
        imagePosition = .imageOnly
        wantsLayer = true
        layer?.masksToBounds = true
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        contentTintColor = tintColor
        setAccessibilityLabel(accessibilityLabel)
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        updateAppearance(duration: 0)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            updateAppearance(duration: Animation.pressDuration)
        }
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
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
        isHovering = true
        updateAppearance(duration: Animation.hoverDuration)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        updateAppearance(duration: Animation.hoverDuration)
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    func setBaseScale(_ scale: CGFloat, duration: TimeInterval) {
        baseScale = scale
        applyScale(duration: duration)
    }

    private func updateAppearance(duration: TimeInterval) {
        let background = (isHovering || isHighlighted) ? hoverBackgroundColor : normalBackgroundColor
        layer?.backgroundColor = background.cgColor
        let targetAlpha: CGFloat = isHighlighted ? 0.85 : 1

        if duration == 0 {
            alphaValue = targetAlpha
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().alphaValue = targetAlpha
            }
        }

        applyScale(duration: duration)
    }

    private func applyScale(duration: TimeInterval) {
        guard let layer else { return }
        let scale: CGFloat = if isHighlighted {
            baseScale * Scale.press
        } else if isHovering {
            baseScale * Scale.hover
        } else {
            baseScale
        }

        CATransaction.begin()
        if duration == 0 {
            CATransaction.setDisableActions(true)
        } else {
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        }
        layer.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }
}

final class PreviewImageView: NSImageView, NSDraggingSource {
    var onOpen: (() -> Void)?
    var dragPayload: PreviewDragPayload?
    var shouldIgnoreEvent: ((NSEvent) -> Bool)?
    var onDragStateChanged: ((Bool) -> Void)?
    private var didDrag = false
    private var draggingSessionStarted = false

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        draggingSessionStarted = false
        guard !shouldIgnore(event) else { return }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !shouldIgnore(event) else { return }
        guard !draggingSessionStarted, let payload = dragPayload else { return }
        guard let draggingItem = payload.makeDraggingItem(dragFrame: bounds) else { return }
        didDrag = true
        draggingSessionStarted = true
        onDragStateChanged?(true)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard !shouldIgnore(event) else { return }
        if !didDrag {
            onOpen?()
        }
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        draggingSessionStarted = false
        onDragStateChanged?(false)
        dragPayload?.rescheduleCleanup()
    }

    private func shouldIgnore(_ event: NSEvent) -> Bool {
        shouldIgnoreEvent?(event) ?? false
    }
}
