import AppKit
import os.log

final class SelectionOverlayView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    var onSelectionChanged: (() -> Void)?
    private let state: SelectionOverlayState
    private let dimmingLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let metricsBackgroundLayer = CAShapeLayer()
    private let metricsTextLayer = CATextLayer()
    private let metricsFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    private let log = OSLog(subsystem: "com.grantbirki.oneshot", category: "SelectionOverlayView")

    init(frame frameRect: NSRect, state: SelectionOverlayState) {
        self.state = state
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
        configureLayers()
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLayerScale()
        updateOverlay()
        #if DEBUG
            os_log(
                "viewDidMoveToWindow window=%{public}@ key=%{public}@ main=%{public}@",
                log: log,
                type: .debug,
                window?.description ?? "nil",
                "\(window?.isKeyWindow ?? false)",
                "\(window?.isMainWindow ?? false)",
            )
        #endif
    }

    override func layout() {
        super.layout()
        updateOverlay()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let point = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: point)
        state.start = screenPoint
        state.current = screenPoint
        onSelectionChanged?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let point = convert(event.locationInWindow, from: nil)
        let screenPoint = window.convertPoint(toScreen: point)
        state.current = screenPoint
        onSelectionChanged?()
    }

    override func mouseUp(with event: NSEvent) {
        guard let window else {
            onCancel?()
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        state.current = window.convertPoint(toScreen: point)
        onSelectionChanged?()
        guard let rect = state.rect else {
            onCancel?()
            return
        }
        if rect.width < 2 || rect.height < 2 {
            onCancel?()
        } else {
            onSelection?(rect)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }

    func updateOverlay() {
        guard layer != nil else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        dimmingLayer.frame = bounds
        borderLayer.frame = bounds
        metricsBackgroundLayer.frame = bounds

        let selection = selectionRect()
        dimmingLayer.fillRule = state.dimmingMode == .fullScreen ? .evenOdd : .nonZero
        dimmingLayer.fillColor = dimmingFillColor(for: state.dimmingMode)
        if let dimmingPath = OverlayPathBuilder.dimmingPath(for: selection, in: bounds, mode: state.dimmingMode) {
            dimmingLayer.path = dimmingPath
            dimmingLayer.isHidden = false
        } else {
            dimmingLayer.path = nil
            dimmingLayer.isHidden = true
        }
        if let selection {
            borderLayer.path = CGPath(rect: selection, transform: nil)
            borderLayer.isHidden = false
        } else {
            borderLayer.path = nil
            borderLayer.isHidden = true
        }

        updateMetrics()

        CATransaction.commit()
    }

    func showSelectionPulse(at screenPoint: CGPoint) {
        guard let window else { return }
        let point = window.convertPoint(fromScreen: screenPoint)
        guard bounds.contains(point), let layer else { return }

        let size: CGFloat = 18
        let rect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size,
        )

        let circle = CAShapeLayer()
        circle.frame = rect
        circle.path = CGPath(ellipseIn: CGRect(origin: .zero, size: CGSize(width: size, height: size)), transform: nil)
        circle.fillColor = NSColor.systemRed.withAlphaComponent(0.22).cgColor
        circle.strokeColor = NSColor.systemRed.cgColor
        circle.lineWidth = 1.5

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.7
        scale.toValue = 1.4

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.3
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        layer.addSublayer(circle)
        circle.add(group, forKey: "pulse")

        DispatchQueue.main.asyncAfter(deadline: .now() + group.duration) {
            circle.removeFromSuperlayer()
        }
    }

    private func configureLayers() {
        dimmingLayer.fillColor = dimmingFillColor(for: state.dimmingMode)

        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor(calibratedWhite: 0.92, alpha: 1).cgColor
        borderLayer.lineWidth = 1
        borderLayer.isHidden = true

        metricsBackgroundLayer.fillColor = NSColor.black.withAlphaComponent(0.75).cgColor
        metricsBackgroundLayer.isHidden = true

        metricsTextLayer.font = metricsFont
        metricsTextLayer.fontSize = metricsFont.pointSize
        metricsTextLayer.foregroundColor = NSColor.white.cgColor
        metricsTextLayer.alignmentMode = .left
        metricsTextLayer.isWrapped = false
        metricsTextLayer.isHidden = true

        layer?.addSublayer(dimmingLayer)
        layer?.addSublayer(borderLayer)
        layer?.addSublayer(metricsBackgroundLayer)
        layer?.addSublayer(metricsTextLayer)
    }

    private func dimmingFillColor(for mode: SelectionDimmingMode) -> CGColor {
        switch mode {
        case .fullScreen:
            NSColor.black.withAlphaComponent(0.35).cgColor
        case .selectionOnly:
            state.selectionDimmingColor.cgColor
        }
    }

    private func updateLayerScale() {
        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0
        dimmingLayer.contentsScale = scale
        borderLayer.contentsScale = scale
        metricsBackgroundLayer.contentsScale = scale
        metricsTextLayer.contentsScale = scale
    }

    private func updateMetrics() {
        guard let window,
              let current = state.current,
              let text = state.selectionSizeText
        else {
            metricsBackgroundLayer.isHidden = true
            metricsTextLayer.isHidden = true
            metricsTextLayer.string = nil
            return
        }

        let anchor = window.convertPoint(fromScreen: current)
        guard bounds.contains(anchor) else {
            metricsBackgroundLayer.isHidden = true
            metricsTextLayer.isHidden = true
            metricsTextLayer.string = nil
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: metricsFont, .foregroundColor: NSColor.white]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        let padding = CGSize(width: 6, height: 4)
        let offset = CGPoint(x: 12, y: 12)
        var bubbleRect = CGRect(
            x: anchor.x + offset.x,
            y: anchor.y + offset.y,
            width: textSize.width + padding.width * 2,
            height: textSize.height + padding.height * 2,
        )
        bubbleRect = clamp(bubbleRect, to: bounds, margin: 8)

        metricsBackgroundLayer.path = CGPath(
            roundedRect: bubbleRect,
            cornerWidth: 6,
            cornerHeight: 6,
            transform: nil,
        )
        metricsBackgroundLayer.isHidden = false

        metricsTextLayer.string = attributedText
        metricsTextLayer.frame = CGRect(
            x: bubbleRect.minX + padding.width,
            y: bubbleRect.minY + padding.height,
            width: textSize.width,
            height: textSize.height,
        )
        metricsTextLayer.isHidden = false
    }

    private func clamp(_ rect: CGRect, to bounds: CGRect, margin: CGFloat) -> CGRect {
        var rect = rect
        rect.origin.x = min(max(rect.origin.x, bounds.minX + margin), bounds.maxX - rect.width - margin)
        rect.origin.y = min(max(rect.origin.y, bounds.minY + margin), bounds.maxY - rect.height - margin)
        return rect
    }

    private func selectionRect() -> CGRect? {
        guard let rect = state.rect, let window else { return nil }
        return window.convertFromScreen(rect)
    }
}
