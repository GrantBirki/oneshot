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
        HotkeyFormatter.keyString(for: keyCode) != nil
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
        var normalized: NSEvent.ModifierFlags = []
        if flags.contains(.command) {
            normalized.insert(.command)
        }
        if flags.contains(.control) {
            normalized.insert(.control)
        }
        if flags.contains(.option) {
            normalized.insert(.option)
        }
        if flags.contains(.shift) {
            normalized.insert(.shift)
        }
        return normalized
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
        guard let parsed = HotkeyStringParser.parse(string),
              let keyCode = HotkeyFormatter.keyCode(for: parsed.key)
        else {
            return nil
        }

        var modifiers: NSEvent.ModifierFlags = []
        if parsed.modifiers.contains(.control) {
            modifiers.insert(.control)
        }
        if parsed.modifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        if parsed.modifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if parsed.modifiers.contains(.command) {
            modifiers.insert(.command)
        }

        return Hotkey(keyCode: keyCode, modifiers: modifiers)
    }
}
