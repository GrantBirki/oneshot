import Carbon.HIToolbox
import SwiftUI

struct HotkeySettingsPane: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        SettingsForm {
            Section("Hotkeys") {
                HotkeyRecorderRow(
                    title: "Selection",
                    hotkey: $settings.hotkeySelection,
                    conflictMessage: conflictMessage(
                        for: settings.hotkeySelection,
                        against: [settings.hotkeyScrolling, settings.hotkeyFullScreen, settings.hotkeyWindow],
                    ),
                )
                HotkeyRecorderRow(
                    title: "Scrolling",
                    hotkey: $settings.hotkeyScrolling,
                    conflictMessage: conflictMessage(
                        for: settings.hotkeyScrolling,
                        against: [settings.hotkeySelection, settings.hotkeyFullScreen, settings.hotkeyWindow],
                    ),
                )
                HotkeyRecorderRow(
                    title: "Window",
                    hotkey: $settings.hotkeyWindow,
                    conflictMessage: conflictMessage(
                        for: settings.hotkeyWindow,
                        against: [settings.hotkeySelection, settings.hotkeyFullScreen, settings.hotkeyScrolling],
                    ),
                )
                HotkeyRecorderRow(
                    title: "Full screen",
                    hotkey: $settings.hotkeyFullScreen,
                    conflictMessage: conflictMessage(
                        for: settings.hotkeyFullScreen,
                        against: [settings.hotkeySelection, settings.hotkeyWindow, settings.hotkeyScrolling],
                    ),
                )
                Text("Click a field and press the shortcut. Press Esc to cancel.")
                    .foregroundStyle(.secondary)
                Text("Shortcuts must include at least one modifier key and take effect immediately.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension HotkeySettingsPane {
    func conflictMessage(for hotkey: Hotkey?, against others: [Hotkey?]) -> String? {
        guard let hotkey, hotkey.isValid else {
            return nil
        }

        if others.compactMap(\.self).contains(hotkey) {
            return "This shortcut is already used by OneShot."
        }

        if Self.reservedSystemHotkeys.contains(hotkey) {
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
}
