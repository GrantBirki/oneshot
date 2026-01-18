import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var showMenuBarHiddenAlert = false
    @State private var selectionDimmingHexInput: String
    @FocusState private var selectionDimmingHexFocused: Bool

    init(settings: SettingsStore) {
        self.settings = settings
        _selectionDimmingHexInput = State(initialValue: settings.selectionDimmingColorHex)
    }

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.autoLaunchEnabled)
                Toggle("Hide menu bar icon", isOn: $settings.menuBarIconHidden)
                    .onChange(of: settings.menuBarIconHidden) { _, newValue in
                        if newValue {
                            showMenuBarHiddenAlert = true
                        }
                    }
                    .help("Hide the OneShot icon from the menu bar.")
            }

            Section("Selection") {
                Toggle("Show selection coordinates", isOn: $settings.showSelectionCoordinates)
                    .help("Show the selection size next to the cursor.")
                Picker("Selection dimming", selection: $settings.selectionDimmingMode) {
                    ForEach(SelectionDimmingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .help("Choose whether the overlay dims the full screen or only the selection.")
                LabeledContent("Selection color") {
                    HStack(spacing: 12) {
                        ColorPicker(
                            "",
                            selection: selectionDimmingColorBinding,
                            supportsOpacity: true,
                        )
                        .labelsHidden()
                        TextField("", text: $selectionDimmingHexInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .focused($selectionDimmingHexFocused)
                            .onChange(of: selectionDimmingHexInput) { _, newValue in
                                let sanitized = sanitizeHexInput(newValue)
                                if sanitized != newValue {
                                    selectionDimmingHexInput = sanitized
                                    return
                                }
                                let digitsCount = sanitized.filter(\.isHexDigit).count
                                guard digitsCount == 6 || digitsCount == 8 else { return }
                                guard let normalized = ColorHexCodec.normalized(sanitized) else { return }
                                if normalized != settings.selectionDimmingColorHex {
                                    settings.selectionDimmingColorHex = normalized
                                }
                                if digitsCount == 8, normalized != selectionDimmingHexInput {
                                    selectionDimmingHexInput = normalized
                                }
                            }
                        Button("Reset") {
                            resetSelectionDimmingColor()
                        }
                        .help("Reset to the default selection color.")
                    }
                }
                .help("Choose the selection-only fill color (RGBA hex).")
                Picker("Selection visual cue", selection: $settings.selectionVisualCue) {
                    ForEach(SelectionVisualCue.allCases) { cue in
                        Text(cue.title).tag(cue)
                    }
                }
                .help("Choose a visual cue shown when selection mode starts.")
            }

            Section("Output") {
                LabeledContent("Filename prefix") {
                    TextField("", text: $settings.filenamePrefix)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Copy to clipboard automatically", isOn: $settings.autoCopyToClipboard)
                    .help("Copy captures to the clipboard in addition to saving.")

                LabeledContent("Save location") {
                    Picker("", selection: $settings.saveLocationOption) {
                        ForEach(SaveLocationOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                }

                if settings.saveLocationOption == .custom {
                    LabeledContent("Custom folder") {
                        HStack(spacing: 8) {
                            TextField("", text: $settings.customSavePath)
                                .textFieldStyle(.roundedBorder)
                            Button("Choose...") {
                                chooseFolder()
                            }
                        }
                    }
                }

                if !settings.previewEnabled {
                    Picker("Default output", selection: $settings.previewDisabledOutputBehavior) {
                        ForEach(PreviewDisabledOutputBehavior.allCases) { behavior in
                            Text(behavior.title)
                                .tag(behavior)
                                .help(behavior.helpText)
                        }
                    }
                    .help("Choose what happens when previews are disabled.")
                }
            }

            Section("Preview") {
                Toggle("Show floating preview", isOn: $settings.previewEnabled)
                Toggle("Auto-dismiss preview", isOn: $settings.previewTimeoutEnabled)
                    .disabled(!settings.previewEnabled)
                if settings.previewEnabled {
                    LabeledContent("Save delay (seconds)") {
                        TextField("", value: $settings.saveDelaySeconds, formatter: numberFormatter)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 80)
                    }
                    Picker("On preview timeout", selection: $settings.previewAutoDismissBehavior) {
                        ForEach(PreviewAutoDismissBehavior.allCases) { behavior in
                            Text(behavior.title)
                                .tag(behavior)
                                .help(behavior.helpText)
                        }
                    }
                    .help("Choose what happens when the preview timer ends.")
                }
                Picker("On new screenshot", selection: $settings.previewReplacementBehavior) {
                    ForEach(PreviewReplacementBehavior.allCases) { behavior in
                        Text(behavior.title)
                            .tag(behavior)
                            .help(behavior.helpText)
                    }
                }
                .disabled(!settings.previewEnabled)
                .help(
                    "Choose what happens to the current preview when a new screenshot is taken " +
                        "and the old preview is still visible.",
                )
            }

            Section("Hotkeys") {
                HotkeyRecorderRow(
                    title: "Selection",
                    hotkey: $settings.hotkeySelection,
                    conflictMessage: conflictMessage(
                        for: settings.hotkeySelection,
                        against: [settings.hotkeyFullScreen, settings.hotkeyWindow],
                    ),
                )
                HotkeyRecorderRow(
                    title: "Full screen",
                    hotkey: $settings.hotkeyFullScreen,
                    conflictMessage: conflictMessage(
                        for: settings.hotkeyFullScreen,
                        against: [settings.hotkeySelection, settings.hotkeyWindow],
                    ),
                )
                HotkeyRecorderRow(
                    title: "Window",
                    hotkey: $settings.hotkeyWindow,
                    conflictMessage: conflictMessage(
                        for: settings.hotkeyWindow,
                        against: [settings.hotkeySelection, settings.hotkeyFullScreen],
                    ),
                )
                Text("Click a field and press the shortcut. Press Esc to cancel.")
                    .foregroundStyle(.secondary)
                Text("Many hotkey changes require quitting and reopening OneShot for changes to take effect.")
                    .foregroundStyle(.secondary)
            }

            Section {
                AboutInfoView()
            }
        }
        .formStyle(.grouped)
        .background(FocusClearView())
        .padding(20)
        .frame(minWidth: 560, minHeight: 480)
        .alert("Menu Bar Icon Hidden", isPresented: $showMenuBarHiddenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To bring it back, open OneShot from Spotlight and turn this setting off.")
        }
        .onChange(of: selectionDimmingHexFocused) { _, focused in
            if !focused {
                normalizeSelectionDimmingHexInput()
            }
        }
        .onChange(of: settings.selectionDimmingColorHex) { _, newValue in
            if !selectionDimmingHexFocused, selectionDimmingHexInput != newValue {
                selectionDimmingHexInput = newValue
            }
        }
    }
}

private extension SettingsView {
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        if panel.runModal() == .OK, let url = panel.url {
            settings.customSavePath = url.path
        }
    }

    func conflictMessage(for hotkey: Hotkey?, against others: [Hotkey?]) -> String? {
        guard let hotkey, hotkey.isValid else {
            return nil
        }

        if others.compactMap(\.self).contains(hotkey) {
            return "This shortcut is already used by OneShot."
        }

        if SettingsView.reservedSystemHotkeys.contains(hotkey) {
            return "This shortcut may conflict with system shortcuts."
        }

        return nil
    }

    static let reservedSystemHotkeys: Set<Hotkey> = [
        Hotkey(keyCode: UInt16(kVK_ANSI_3), modifiers: [.command, .shift]),
        Hotkey(keyCode: UInt16(kVK_ANSI_4), modifiers: [.command, .shift]),
        Hotkey(keyCode: UInt16(kVK_ANSI_5), modifiers: [.command, .shift]),
        Hotkey(keyCode: UInt16(kVK_ANSI_6), modifiers: [.command, .shift]),
        Hotkey(keyCode: UInt16(kVK_ANSI_3), modifiers: [.command, .shift, .control]),
        Hotkey(keyCode: UInt16(kVK_ANSI_4), modifiers: [.command, .shift, .control]),
    ]

    func sanitizeHexInput(_ value: String) -> String {
        let digits = value.filter(\.isHexDigit)
        guard !digits.isEmpty else { return "" }
        let limited = String(digits.prefix(8))
        return "#\(limited.uppercased())"
    }

    func normalizeSelectionDimmingHexInput() {
        let sanitized = sanitizeHexInput(selectionDimmingHexInput)
        guard let normalized = ColorHexCodec.normalized(sanitized) else {
            if selectionDimmingHexInput != settings.selectionDimmingColorHex {
                selectionDimmingHexInput = settings.selectionDimmingColorHex
            }
            return
        }
        if normalized != settings.selectionDimmingColorHex {
            settings.selectionDimmingColorHex = normalized
        }
        if normalized != selectionDimmingHexInput {
            selectionDimmingHexInput = normalized
        }
    }

    func resetSelectionDimmingColor() {
        let defaultHex = ColorHexCodec.defaultSelectionDimmingColorHex
        settings.selectionDimmingColorHex = defaultHex
        selectionDimmingHexInput = defaultHex
    }

    var selectionDimmingColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: settings.selectionDimmingColor) },
            set: { settings.selectionDimmingColor = NSColor($0) },
        )
    }
}

private struct HotkeyRecorderRow: View {
    let title: String
    @Binding var hotkey: Hotkey?
    let conflictMessage: String?

    var body: some View {
        LabeledContent(title) {
            VStack(alignment: .leading, spacing: 4) {
                HotkeyRecorder(
                    hotkey: $hotkey,
                    placeholder: "Type shortcut...",
                    accessibilityLabel: "\(title) hotkey",
                    showsConflict: conflictMessage != nil,
                )
                .frame(maxWidth: 200)

                if let conflictMessage {
                    Text(conflictMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct FocusClearView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private weak var view: NSView?
        private var monitor: Any?

        func attach(to view: NSView) {
            self.view = view
            if monitor != nil {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                guard let self,
                      let view = self.view,
                      let window = view.window,
                      window == event.window,
                      let contentView = window.contentView
                else {
                    return event
                }

                let point = contentView.convert(event.locationInWindow, from: nil)
                if let hitView = contentView.hitTest(point), isTextInput(view: hitView) {
                    return event
                }

                window.makeFirstResponder(nil)
                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func isTextInput(view: NSView) -> Bool {
            if view is NSTextView || view is NSTextField || view is HotkeyRecorderView {
                return true
            }

            var current = view.superview
            while let currentView = current {
                if currentView is NSTextField || currentView is HotkeyRecorderView {
                    return true
                }
                current = currentView.superview
            }

            return false
        }
    }
}
