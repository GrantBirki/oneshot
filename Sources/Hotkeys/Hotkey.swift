import Foundation
import Carbon.HIToolbox

struct Hotkey: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let display: String
}

enum HotkeyParser {
    static func parse(_ string: String) -> Hotkey? {
        let cleaned = string
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        if cleaned.isEmpty {
            return nil
        }

        let parts = cleaned.split(separator: "+").map(String.init)
        var modifiers: UInt32 = 0
        var key: String?

        for part in parts {
            switch part {
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "alt", "option":
                modifiers |= UInt32(optionKey)
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            default:
                key = part
            }
        }

        guard let key = key, let keyCode = KeyCodeMapper.keyCode(for: key) else {
            return nil
        }

        return Hotkey(keyCode: keyCode, modifiers: modifiers, display: cleaned)
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
        "n": 45, "m": 46, ".": 47, "`": 50
    ]

    static func keyCode(for key: String) -> UInt32? {
        mapping[key]
    }
}
