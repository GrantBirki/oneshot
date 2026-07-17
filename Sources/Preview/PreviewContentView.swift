import AppKit

struct PreviewContentConfiguration {
    let image: NSImage
    let pngData: Data
    let filenamePrefix: String
    let onSave: () -> Void
    let onDiscard: () -> Void
    let onOpen: () -> Void
    let onSaveAs: () -> Void
    let onCopy: () -> Void
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
        static let actionButtonScale: CGFloat = 1
    }

    #if DEBUG
        private enum Debug {
            static let logHitTesting = ProcessInfo.processInfo.environment["ONESHOT_DEBUG_PREVIEW_HIT_TESTING"] == "1"
            static let logActions = ProcessInfo.processInfo.environment["ONESHOT_DEBUG_PREVIEW_ACTIONS"] == "1"
            static let logViewHierarchy = ProcessInfo.processInfo.environment["ONESHOT_DEBUG_PREVIEW_HIERARCHY"] == "1"
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
        tintColor: .systemRed,
        backgroundColor: PreviewContentView.transparentBackgroundColor,
        hoverBackgroundColor: PreviewContentView.transparentBackgroundColor,
        accessibilityLabel: "Don't save screenshot",
        identifier: "preview-trash",
    )
    private let recoveryGlassView = NSGlassEffectView()
    private let recoveryLabel = NSTextField(wrappingLabelWithString: "")
    private let recoveryActions = NSStackView()
    private let recoveryPrimaryActions = NSStackView()
    private let recoverySecondaryActions = NSStackView()
    private let retryButton = NSButton(title: "Retry", target: nil, action: nil)
    private let saveAsButton = NSButton(title: "Save As…", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let recoveryDiscardButton = NSButton(title: "Don’t Save", target: nil, action: nil)
    private var dragPayload: PreviewDragPayload?
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false
    private var isFocused = false
    private var areActionsVisible = false
    private var onSave: (() -> Void)?
    private var onDiscard: (() -> Void)?
    private var onOpen: (() -> Void)?
    private var onSaveAs: (() -> Void)?
    private var onCopy: (() -> Void)?
    private var onRetry: (() -> Void)?
    private var onRecoverySecondary: (() -> Void)?
    private var onRecoveryTertiary: (() -> Void)?
    private var isOutputSaved = false
    private var onHoverChanged: ((Bool) -> Void)?
    private var onDragChanged: ((Bool) -> Void)?
    private var isActionOverlayActive: Bool {
        !actionOverlayView.isHidden
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        backgroundView.style = .clear
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

        recoveryLabel.maximumNumberOfLines = 3
        recoveryLabel.lineBreakMode = .byWordWrapping
        recoveryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for button in [retryButton, saveAsButton, copyButton, recoveryDiscardButton] {
            button.controlSize = .small
        }
        for row in [recoveryPrimaryActions, recoverySecondaryActions] {
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fillEqually
            row.spacing = 6
        }
        recoveryPrimaryActions.addArrangedSubview(retryButton)
        recoveryPrimaryActions.addArrangedSubview(saveAsButton)
        recoverySecondaryActions.addArrangedSubview(copyButton)
        recoverySecondaryActions.addArrangedSubview(recoveryDiscardButton)
        recoveryActions.orientation = .vertical
        recoveryActions.alignment = .width
        recoveryActions.spacing = 4
        recoveryActions.addArrangedSubview(recoveryPrimaryActions)
        recoveryActions.addArrangedSubview(recoverySecondaryActions)
        let recoveryStack = NSStackView(views: [recoveryLabel, recoveryActions])
        recoveryStack.orientation = .vertical
        recoveryStack.alignment = .leading
        recoveryStack.spacing = 8
        recoveryStack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        recoveryStack.autoresizingMask = [.width, .height]
        recoveryGlassView.style = .regular
        recoveryGlassView.cornerRadius = 10
        recoveryGlassView.contentView = recoveryStack
        recoveryGlassView.isHidden = true
        addSubview(recoveryGlassView, positioned: .above, relativeTo: actionContainerView)

        retryButton.target = self
        retryButton.action = #selector(handleRetry)
        saveAsButton.target = self
        saveAsButton.action = #selector(handleRecoverySecondary)
        copyButton.target = self
        copyButton.action = #selector(handleRecoveryTertiary)
        recoveryDiscardButton.target = self
        recoveryDiscardButton.action = #selector(handleTrash)
        closeButton.toolTip = "Save the screenshot to disk"
        trashButton.toolTip = "Do not save the screenshot, or delete its saved file. Clipboard copies are kept."
        recoveryDiscardButton.toolTip = "Clipboard copies are kept."
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
        if !recoveryGlassView.isHidden {
            let recoveryPoint = recoveryGlassView.convert(point, from: self)
            if recoveryGlassView.bounds.contains(recoveryPoint) {
                let hit = super.hitTest(point)
                logHitTest(hit)
                return hit
            }
        }

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
        let recoveryHeight = min(max(bounds.height * 0.8, 108), 190)
        recoveryGlassView.frame = NSRect(
            x: 6,
            y: 6,
            width: max(bounds.width - 12, 1),
            height: min(recoveryHeight, max(bounds.height - 12, 1)),
        )
        recoveryGlassView.contentView?.frame = recoveryGlassView.bounds
    }
}

extension PreviewContentView {
    func configure(with configuration: PreviewContentConfiguration) {
        onSave = configuration.onSave
        onDiscard = configuration.onDiscard
        onOpen = configuration.onOpen
        onSaveAs = configuration.onSaveAs
        onCopy = configuration.onCopy
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
            self?.onOpen?()
        }
        imageView.onSave = { [weak self] in self?.onSave?() }
        imageView.onDiscard = { [weak self] in self?.onDiscard?() }
        imageView.onFocusChanged = { [weak self] focused in
            self?.setFocusState(focused)
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

    func performSave() {
        handleClose()
    }

    func performDiscard() {
        handleTrash()
    }

    func performOpen() {
        onOpen?()
    }

    @objc private func handleClose() {
        #if DEBUG
            if Debug.logActions {
                logDebug("Save clicked")
            }
        #endif
        onSave?()
    }

    @objc private func handleTrash() {
        #if DEBUG
            if Debug.logActions {
                logDebug("Trash clicked")
            }
        #endif
        onDiscard?()
    }

    @objc private func handleRetry() {
        onRetry?()
    }

    @objc private func handleRecoverySecondary() {
        onRecoverySecondary?()
    }

    @objc private func handleRecoveryTertiary() {
        onRecoveryTertiary?()
    }

    func showRecovery(message: String, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        onRecoverySecondary = onSaveAs
        onRecoveryTertiary = onCopy
        retryButton.title = "Retry"
        saveAsButton.title = "Save As…"
        copyButton.title = "Copy"
        recoveryDiscardButton.isHidden = false
        recoveryDiscardButton.title = isOutputSaved ? "Delete File" : "Don’t Save"
        recoveryActions.isHidden = false
        recoveryLabel.stringValue = message
        recoveryGlassView.isHidden = false
        recoveryGlassView.setAccessibilityLabel("Screenshot recovery")
        recoveryGlassView.setAccessibilityHelp(message)
    }

    func showOpenRecovery(
        message: String,
        onRetryOpen: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
    ) {
        onRetry = onRetryOpen
        onRecoverySecondary = onReveal
        onRecoveryTertiary = onDismiss
        retryButton.title = "Retry Open"
        saveAsButton.title = "Reveal in Finder"
        copyButton.title = "Dismiss"
        recoveryDiscardButton.isHidden = true
        recoveryActions.isHidden = false
        recoveryLabel.stringValue = message
        recoveryGlassView.isHidden = false
        recoveryGlassView.setAccessibilityLabel("Screenshot open recovery")
        recoveryGlassView.setAccessibilityHelp(message)
    }

    func showStatus(message: String) {
        onRetry = nil
        onRecoverySecondary = nil
        onRecoveryTertiary = nil
        recoveryActions.isHidden = true
        recoveryLabel.stringValue = message
        recoveryGlassView.isHidden = false
        recoveryGlassView.setAccessibilityLabel("Screenshot status")
        recoveryGlassView.setAccessibilityHelp(message)
    }

    func clearRecovery() {
        onRetry = nil
        onRecoverySecondary = nil
        onRecoveryTertiary = nil
        recoveryActions.isHidden = false
        recoveryDiscardButton.isHidden = false
        recoveryGlassView.isHidden = true
        recoveryLabel.stringValue = ""
    }

    func setBusy(_ busy: Bool) {
        closeButton.isEnabled = !busy
        trashButton.isEnabled = !busy
        retryButton.isEnabled = !busy
        saveAsButton.isEnabled = !busy
        copyButton.isEnabled = !busy
        recoveryDiscardButton.isEnabled = !busy
        imageView.isEnabled = !busy
    }

    func setSavedState(_ saved: Bool) {
        isOutputSaved = saved
        imageView.setSavedState(saved)
        let label = saved ? "Delete saved screenshot" : "Don't save screenshot"
        trashButton.setAccessibilityLabel(label)
        trashButton.toolTip = saved
            ? "Delete the saved screenshot. Clipboard copies are kept."
            : "Do not save the screenshot. Clipboard copies are kept."
        recoveryDiscardButton.title = saved ? "Delete File" : "Don’t Save"
    }

    private func isPointInActionButtons(_ point: NSPoint) -> Bool {
        guard isActionOverlayActive else { return false }
        let overlayPoint = actionOverlayView.convert(point, from: self)
        return closeGlassView.frame.contains(overlayPoint) || trashGlassView.frame.contains(overlayPoint)
    }
}

private extension PreviewContentView {
    func setFocusState(_ focused: Bool) {
        guard isFocused != focused else { return }
        isFocused = focused
        if !focused {
            updateHoverState(animated: false)
        }
        updateActionVisibility(animated: false)
    }

    func updateHoverState(animated: Bool) {
        guard let window else { return }
        let location = window.mouseLocationOutsideOfEventStream
        let local = convert(location, from: nil)
        setHoverState(bounds.contains(local), animated: animated)
    }

    func setHoverState(_ hovered: Bool, animated: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        updateActionVisibility(animated: animated)
    }

    func updateActionVisibility(animated: Bool) {
        let visible = isHovered || isFocused
        guard areActionsVisible != visible else { return }
        areActionsVisible = visible
        onHoverChanged?(visible)
        let duration = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? Layout.hoverFadeDuration
            : 0

        if visible {
            actionOverlayView.isHidden = false
            actionOverlayView.alphaValue = 0
            closeButton.setBaseScale(Layout.actionButtonScale, duration: 0)
            trashButton.setBaseScale(Layout.actionButtonScale, duration: 0)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            actionOverlayView.animator().alphaValue = visible ? 1 : 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !areActionsVisible {
                    actionOverlayView.isHidden = true
                }
            }
        }

        closeButton.setBaseScale(Layout.actionButtonScale, duration: duration)
        trashButton.setBaseScale(Layout.actionButtonScale, duration: duration)
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
