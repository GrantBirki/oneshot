import Foundation

struct ParsedHotkey {
    let normalized: String
    let key: String
    let modifiers: Set<HotkeyModifier>
}

enum HotkeyModifier: Hashable {
    case control
    case shift
    case option
    case command
}

enum HotkeyStringParser {
    static func parse(_ string: String) -> ParsedHotkey? {
        let normalized = string
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        if normalized.isEmpty {
            return nil
        }

        let parts = normalized.split(separator: "+").map(String.init)
        var modifiers: Set<HotkeyModifier> = []
        var key: String?

        for part in parts {
            switch part {
            case "ctrl", "control":
                modifiers.insert(.control)
            case "shift":
                modifiers.insert(.shift)
            case "alt", "option":
                modifiers.insert(.option)
            case "cmd", "command":
                modifiers.insert(.command)
            default:
                key = part
            }
        }

        guard let key, HotkeyFormatter.keyCode(for: key) != nil else {
            return nil
        }

        return ParsedHotkey(normalized: normalized, key: key, modifiers: modifiers)
    }
}
