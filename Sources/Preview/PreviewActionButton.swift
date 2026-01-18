import AppKit

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
