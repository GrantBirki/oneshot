import AppKit
import Carbon.HIToolbox
import Foundation

struct Hotkey: Codable, Equatable, Hashable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = Hotkey.normalizedModifiers(modifiers)
    }

    var displayString: String {
        HotkeyFormatter.displayString(keyCode: keyCode, modifiers: modifiers) ?? "?"
    }

    var isValid: Bool {
        HotkeyFormatter.keyString(for: keyCode) != nil && !modifiers.isEmpty
    }

    var carbonKeyCode: UInt32 {
        UInt32(keyCode)
    }

    var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if modifiers.contains(.control) {
            mask |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            mask |= UInt32(shiftKey)
        }
        if modifiers.contains(.option) {
            mask |= UInt32(optionKey)
        }
        if modifiers.contains(.command) {
            mask |= UInt32(cmdKey)
        }
        return mask
    }

    static func normalizedModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.command, .control, .option, .shift])
    }

    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let rawValue = try container.decode(UInt.self, forKey: .modifiers)
        modifiers = Hotkey.normalizedModifiers(NSEvent.ModifierFlags(rawValue: rawValue))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
    }

    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers.rawValue == rhs.modifiers.rawValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers.rawValue)
    }
}

enum HotkeyParser {
    static func parse(_ string: String) -> Hotkey? {
        let normalized = string.lowercased().replacingOccurrences(of: " ", with: "")
        var modifiers: NSEvent.ModifierFlags = []
        var key: String?

        for part in normalized.split(separator: "+") {
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
                key = String(part)
            }
        }

        guard let key, !modifiers.isEmpty,
              let keyCode = HotkeyFormatter.keyCode(for: key)
        else {
            return nil
        }

        return Hotkey(keyCode: keyCode, modifiers: modifiers)
    }
}
