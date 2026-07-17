import Carbon.HIToolbox
import SwiftUI

struct HotkeySettingsPane: View {
    @ObservedObject var settings: SettingsStore
    @StateObject private var keyboardInputSourceObserver = KeyboardInputSourceObserver()

    private let actions = HotkeyAction.registrationOrder

    var body: some View {
        SettingsForm {
            Section("Hotkeys") {
                ForEach(actions, id: \.self) { action in
                    HotkeyRecorderRow(
                        title: action.title,
                        hotkey: hotkeyBinding(for: action),
                        conflictMessage: conflictMessage(for: action),
                    )
                }
                Text("Click a field and press the shortcut. Press Esc to cancel.")
                    .foregroundStyle(.secondary)
                Text("Shortcuts must include at least one modifier key and take effect immediately.")
                    .foregroundStyle(.secondary)
            }
        }
        .id(keyboardInputSourceObserver.generation)
    }
}

@MainActor
private final class KeyboardInputSourceObserver: ObservableObject {
    @Published private(set) var generation = 0
    private nonisolated(unsafe) var token: NSObjectProtocol?

    init(center: DistributedNotificationCenter = .default()) {
        token = center.addObserver(
            forName: .keyboardInputSourceChanged,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.generation += 1
            }
        }
    }

    deinit {
        if let token {
            DistributedNotificationCenter.default().removeObserver(token)
        }
    }
}

extension HotkeySettingsPane {
    func hotkeyBinding(for action: HotkeyAction) -> Binding<Hotkey?> {
        Binding(
            get: { settings.hotkeyConfiguration[action] },
            set: { hotkey in
                if case let .duplicate(duplicate) = settings.setHotkey(hotkey, for: action) {
                    AccessibilityAnnouncer.announce(
                        "That shortcut is already used for \(duplicate.title.lowercased()).",
                    )
                }
            },
        )
    }

    func conflictMessage(for action: HotkeyAction) -> String? {
        if let message = settings.hotkeyMessage(for: action) {
            return message
        }

        let hotkey = settings.hotkeyConfiguration[action]
        let otherHotkeys = HotkeyAction.allCases
            .filter { $0 != action }
            .map { settings.hotkeyConfiguration[$0] }
        return conflictMessage(for: hotkey, against: otherHotkeys)
    }

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
