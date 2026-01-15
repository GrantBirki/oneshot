import Carbon.HIToolbox
import Foundation

struct Hotkey: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let display: String
}

enum HotkeyParser {
    static func parse(_ string: String) -> Hotkey? {
        guard let parsed = HotkeyStringParser.parse(string),
              let keyCode = KeyCodeMapper.keyCode(for: parsed.key)
        else {
            return nil
        }

        var modifiers: UInt32 = 0
        if parsed.modifiers.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if parsed.modifiers.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if parsed.modifiers.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if parsed.modifiers.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        return Hotkey(keyCode: keyCode, modifiers: modifiers, display: parsed.normalized)
    }
}

enum KeyCodeMapper {
    private static let mapping: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
        "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50,
    ]

    static func keyCode(for key: String) -> UInt32? {
        mapping[key]
    }
}
