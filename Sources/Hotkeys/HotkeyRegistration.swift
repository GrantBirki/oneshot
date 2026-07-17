import Carbon.HIToolbox
import Foundation

enum HotkeyAction: String, CaseIterable, Hashable {
    case selection
    case scrolling
    case window
    case fullScreen

    var title: String {
        switch self {
        case .selection:
            "Selection"
        case .scrolling:
            "Scrolling"
        case .window:
            "Window"
        case .fullScreen:
            "Full screen"
        }
    }

    var registrationID: UInt32 {
        switch self {
        case .selection: 1
        case .scrolling: 2
        case .window: 3
        case .fullScreen: 4
        }
    }
}

struct HotkeyConfiguration: Equatable {
    let selection: Hotkey?
    let scrolling: Hotkey?
    let window: Hotkey?
    let fullScreen: Hotkey?

    subscript(action: HotkeyAction) -> Hotkey? {
        switch action {
        case .selection: selection
        case .scrolling: scrolling
        case .window: window
        case .fullScreen: fullScreen
        }
    }
}

struct HotkeyHandlers {
    let selection: () -> Void
    let scrolling: () -> Void
    let window: () -> Void
    let fullScreen: () -> Void

    subscript(action: HotkeyAction) -> () -> Void {
        switch action {
        case .selection: selection
        case .scrolling: scrolling
        case .window: window
        case .fullScreen: fullScreen
        }
    }
}

enum HotkeyRegistrationStatus: Equatable {
    case notConfigured
    case invalid
    case registered
    case duplicate(HotkeyAction)
    case unavailable(OSStatus)

    var message: String? {
        switch self {
        case .notConfigured,
             .registered:
            nil
        case .invalid:
            "This shortcut is invalid."
        case let .duplicate(action):
            "This shortcut is already used for \(action.title.lowercased())."
        case let .unavailable(status):
            if status == eventHotKeyExistsErr {
                "Couldn’t register; this shortcut is already in use."
            } else {
                "Couldn’t register this shortcut."
            }
        }
    }
}

enum HotkeyAssignmentResult: Equatable {
    case accepted
    case duplicate(HotkeyAction)
}

extension HotkeyConfiguration {
    func duplicateAction(for hotkey: Hotkey, excluding action: HotkeyAction) -> HotkeyAction? {
        HotkeyAction.allCases.first { candidate in
            candidate != action && self[candidate] == hotkey
        }
    }
}

extension HotkeyAction {
    static let registrationOrder: [HotkeyAction] = [.selection, .scrolling, .window, .fullScreen]
}
