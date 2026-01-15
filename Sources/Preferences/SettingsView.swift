import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

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
            }

            Section("Output") {
                LabeledContent("Filename prefix") {
                    TextField("", text: $settings.filenamePrefix)
                        .textFieldStyle(.roundedBorder)
                }

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
        }
        .formStyle(.grouped)
        .background(FocusClearView())
        .padding(20)
        .frame(minWidth: 560, minHeight: 480)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        if panel.runModal() == .OK, let url = panel.url {
            settings.customSavePath = url.path
        }
    }

    private func conflictMessage(for hotkey: Hotkey?, against others: [Hotkey?]) -> String? {
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

    private static let reservedSystemHotkeys: Set<Hotkey> = [
        Hotkey(keyCode: UInt16(kVK_ANSI_3), modifiers: [.command, .shift]),
        Hotkey(keyCode: UInt16(kVK_ANSI_4), modifiers: [.command, .shift]),
        Hotkey(keyCode: UInt16(kVK_ANSI_5), modifiers: [.command, .shift]),
        Hotkey(keyCode: UInt16(kVK_ANSI_6), modifiers: [.command, .shift]),
        Hotkey(keyCode: UInt16(kVK_ANSI_3), modifiers: [.command, .shift, .control]),
        Hotkey(keyCode: UInt16(kVK_ANSI_4), modifiers: [.command, .shift, .control]),
    ]
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
