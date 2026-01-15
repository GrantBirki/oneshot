import AppKit
import Carbon.HIToolbox

final class HotkeyRecorderView: NSControl {
    var hotkey: Hotkey? {
        didSet {
            updateDisplay()
        }
    }

    var placeholderText: String = "Type shortcut..." {
        didSet {
            updateDisplay()
        }
    }

    var onChange: ((Hotkey?) -> Void)?

    var showsConflict: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    private let label = NSTextField(labelWithString: "")
    private let clearButton: NSButton
    private var isRecording = false
    private var recordingInitialHotkey: Hotkey?
    private var didCapture = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        if let image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear") {
            clearButton = NSButton(image: image, target: nil, action: nil)
        } else {
            clearButton = NSButton(title: "Clear", target: nil, action: nil)
        }
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        if let image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear") {
            clearButton = NSButton(image: image, target: nil, action: nil)
        } else {
            clearButton = NSButton(title: "Clear", target: nil, action: nil)
        }
        super.init(coder: coder)
        setupView()
    }

    override func mouseDown(with _: NSEvent) {
        window?.makeFirstResponder(self)
        startRecording()
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            startRecording()
        }
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        stopRecording(restoreIfNeeded: true)
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if isRecording {
            handleKeyEvent(event)
            return
        }

        switch event.keyCode {
        case UInt16(kVK_Space), UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
            startRecording()
        case UInt16(kVK_Tab):
            if event.modifierFlags.contains(.shift) {
                window?.selectPreviousKeyView(self)
            } else {
                window?.selectNextKeyView(self)
            }
        default:
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isRecording {
            handleKeyEvent(event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        if isRecording {
            updateDisplay()
        } else {
            super.flagsChanged(with: event)
        }
    }

    override func layout() {
        super.layout()
        let paddingX: CGFloat = 8
        let paddingY: CGFloat = 4
        let buttonSize: CGFloat = 14
        let buttonPadding: CGFloat = 6

        var contentRect = bounds.insetBy(dx: paddingX, dy: paddingY)
        if clearButton.isHidden {
            label.frame = contentRect
        } else {
            let buttonX = bounds.maxX - paddingX - buttonSize
            clearButton.frame = NSRect(
                x: buttonX,
                y: bounds.midY - (buttonSize / 2),
                width: buttonSize,
                height: buttonSize,
            )
            contentRect.size.width = max(0, contentRect.width - buttonSize - buttonPadding)
            label.frame = contentRect
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 220, height: 26)
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.masksToBounds = true

        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        addSubview(label)

        clearButton.isBordered = false
        clearButton.target = self
        clearButton.action = #selector(clearHotkey)
        clearButton.toolTip = "Clear"
        clearButton.setButtonType(.momentaryChange)
        if clearButton.image != nil {
            clearButton.imagePosition = .imageOnly
        } else {
            clearButton.imagePosition = .noImage
        }
        addSubview(clearButton)

        setAccessibilityLabel("Hotkey")
        updateDisplay()
        updateAppearance()
    }

    @objc private func clearHotkey() {
        commitHotkey(nil)
        announce("Shortcut cleared")
        stopRecording(restoreIfNeeded: false)
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        didCapture = false
        recordingInitialHotkey = hotkey
        updateDisplay()
        updateAppearance()
        announce("Recording shortcut")
    }

    private func stopRecording(restoreIfNeeded: Bool) {
        guard isRecording else { return }
        isRecording = false
        if restoreIfNeeded, !didCapture {
            hotkey = recordingInitialHotkey
        }
        updateDisplay()
        updateAppearance()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording(restoreIfNeeded: true)
            announce("Recording canceled")
            return
        }

        let modifiers = Hotkey.normalizedModifiers(event.modifierFlags)
        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete),
           modifiers.isEmpty
        {
            commitHotkey(nil)
            didCapture = true
            stopRecording(restoreIfNeeded: false)
            announce("Shortcut cleared")
            return
        }

        if HotkeyFormatter.isModifierKeyCode(event.keyCode) {
            return
        }

        guard HotkeyFormatter.keyString(for: event.keyCode) != nil else {
            NSSound.beep()
            return
        }

        let newHotkey = Hotkey(keyCode: event.keyCode, modifiers: modifiers)
        commitHotkey(newHotkey)
        didCapture = true
        stopRecording(restoreIfNeeded: false)
        announce("Shortcut set to \(newHotkey.displayString)")
    }

    private func commitHotkey(_ newValue: Hotkey?) {
        if newValue == hotkey {
            return
        }
        hotkey = newValue
        onChange?(newValue)
    }

    private func updateDisplay() {
        if isRecording {
            label.stringValue = placeholderText
            label.textColor = NSColor.secondaryLabelColor
        } else if let hotkey, hotkey.isValid {
            label.stringValue = hotkey.displayString
            label.textColor = NSColor.labelColor
        } else {
            label.stringValue = "None"
            label.textColor = NSColor.secondaryLabelColor
        }

        clearButton.isHidden = isRecording || hotkey == nil
        setAccessibilityValue(label.stringValue)
        needsLayout = true
    }

    private func updateAppearance() {
        guard let layer else { return }

        if isRecording {
            layer.borderColor = NSColor.controlAccentColor.cgColor
            layer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        } else if showsConflict {
            layer.borderColor = NSColor.systemOrange.cgColor
            layer.backgroundColor = NSColor.controlBackgroundColor.cgColor
        } else {
            layer.borderColor = NSColor.separatorColor.cgColor
            layer.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }

    private func announce(_ message: String) {
        NSAccessibility.post(
            element: self,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ],
        )
    }
}
