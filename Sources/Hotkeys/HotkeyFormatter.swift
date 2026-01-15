import AppKit
import Carbon.HIToolbox

enum HotkeyFormatter {
    private static let modifierOrder: [NSEvent.ModifierFlags] = [
        .command,
        .control,
        .option,
        .shift,
    ]

    static func displayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String? {
        guard let key = keyString(for: keyCode) else {
            return nil
        }

        let normalized = Hotkey.normalizedModifiers(modifiers)
        var output = ""
        for modifier in modifierOrder where normalized.contains(modifier) {
            if let glyph = modifierGlyph(for: modifier) {
                output.append(glyph)
            }
        }
        output.append(key)
        return output
    }

    static func keyString(for keyCode: UInt16) -> String? {
        if let special = specialKeyNames[keyCode] {
            return special
        }
        guard let key = keyCodeToKey[keyCode] else {
            return nil
        }
        return key.uppercased()
    }

    static func keyCode(for key: String) -> UInt16? {
        keyToKeyCode[key.lowercased()]
    }

    static func keyEquivalent(for keyCode: UInt16) -> String? {
        if let special = specialKeyEquivalents[keyCode] {
            return special
        }
        return keyCodeToKey[keyCode]
    }

    static func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        modifierKeyCodes.contains(keyCode)
    }

    private static func modifierGlyph(for modifier: NSEvent.ModifierFlags) -> String? {
        switch modifier {
        case .command:
            "\u{2318}"
        case .option:
            "\u{2325}"
        case .control:
            "\u{2303}"
        case .shift:
            "\u{21E7}"
        default:
            nil
        }
    }

    private static let keyCodeToKey: [UInt16: String] = [
        UInt16(kVK_ANSI_A): "a",
        UInt16(kVK_ANSI_S): "s",
        UInt16(kVK_ANSI_D): "d",
        UInt16(kVK_ANSI_F): "f",
        UInt16(kVK_ANSI_H): "h",
        UInt16(kVK_ANSI_G): "g",
        UInt16(kVK_ANSI_Z): "z",
        UInt16(kVK_ANSI_X): "x",
        UInt16(kVK_ANSI_C): "c",
        UInt16(kVK_ANSI_V): "v",
        UInt16(kVK_ANSI_B): "b",
        UInt16(kVK_ANSI_Q): "q",
        UInt16(kVK_ANSI_W): "w",
        UInt16(kVK_ANSI_E): "e",
        UInt16(kVK_ANSI_R): "r",
        UInt16(kVK_ANSI_Y): "y",
        UInt16(kVK_ANSI_T): "t",
        UInt16(kVK_ANSI_1): "1",
        UInt16(kVK_ANSI_2): "2",
        UInt16(kVK_ANSI_3): "3",
        UInt16(kVK_ANSI_4): "4",
        UInt16(kVK_ANSI_6): "6",
        UInt16(kVK_ANSI_5): "5",
        UInt16(kVK_ANSI_Equal): "=",
        UInt16(kVK_ANSI_9): "9",
        UInt16(kVK_ANSI_7): "7",
        UInt16(kVK_ANSI_Minus): "-",
        UInt16(kVK_ANSI_8): "8",
        UInt16(kVK_ANSI_0): "0",
        UInt16(kVK_ANSI_RightBracket): "]",
        UInt16(kVK_ANSI_O): "o",
        UInt16(kVK_ANSI_U): "u",
        UInt16(kVK_ANSI_LeftBracket): "[",
        UInt16(kVK_ANSI_I): "i",
        UInt16(kVK_ANSI_P): "p",
        UInt16(kVK_ANSI_L): "l",
        UInt16(kVK_ANSI_J): "j",
        UInt16(kVK_ANSI_Quote): "'",
        UInt16(kVK_ANSI_K): "k",
        UInt16(kVK_ANSI_Semicolon): ";",
        UInt16(kVK_ANSI_Backslash): "\\",
        UInt16(kVK_ANSI_Comma): ",",
        UInt16(kVK_ANSI_Slash): "/",
        UInt16(kVK_ANSI_N): "n",
        UInt16(kVK_ANSI_M): "m",
        UInt16(kVK_ANSI_Period): ".",
        UInt16(kVK_ANSI_Grave): "`",
    ]

    private static let keyToKeyCode: [String: UInt16] = {
        var mapping = [String: UInt16]()
        for (keyCode, key) in keyCodeToKey {
            mapping[key] = keyCode
        }
        mapping["space"] = UInt16(kVK_Space)
        mapping["tab"] = UInt16(kVK_Tab)
        mapping["return"] = UInt16(kVK_Return)
        mapping["enter"] = UInt16(kVK_ANSI_KeypadEnter)
        mapping["esc"] = UInt16(kVK_Escape)
        mapping["escape"] = UInt16(kVK_Escape)
        mapping["delete"] = UInt16(kVK_Delete)
        mapping["forwarddelete"] = UInt16(kVK_ForwardDelete)
        mapping["left"] = UInt16(kVK_LeftArrow)
        mapping["right"] = UInt16(kVK_RightArrow)
        mapping["up"] = UInt16(kVK_UpArrow)
        mapping["down"] = UInt16(kVK_DownArrow)
        return mapping
    }()

    private static let specialKeyNames: [UInt16: String] = [
        UInt16(kVK_Space): "Space",
        UInt16(kVK_Tab): "Tab",
        UInt16(kVK_Return): "Return",
        UInt16(kVK_ANSI_KeypadEnter): "Enter",
        UInt16(kVK_Escape): "Esc",
        UInt16(kVK_Delete): "Delete",
        UInt16(kVK_ForwardDelete): "Forward Delete",
        UInt16(kVK_LeftArrow): "\u{2190}",
        UInt16(kVK_RightArrow): "\u{2192}",
        UInt16(kVK_UpArrow): "\u{2191}",
        UInt16(kVK_DownArrow): "\u{2193}",
        UInt16(kVK_Home): "Home",
        UInt16(kVK_End): "End",
        UInt16(kVK_PageUp): "Page Up",
        UInt16(kVK_PageDown): "Page Down",
        UInt16(kVK_Help): "Help",
        UInt16(kVK_F1): "F1",
        UInt16(kVK_F2): "F2",
        UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5",
        UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7",
        UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10",
        UInt16(kVK_F11): "F11",
        UInt16(kVK_F12): "F12",
    ]

    private static let specialKeyEquivalents: [UInt16: String] = [
        UInt16(kVK_Space): " ",
        UInt16(kVK_Tab): String(UnicodeScalar(NSTabCharacter)!),
        UInt16(kVK_Return): String(UnicodeScalar(NSCarriageReturnCharacter)!),
        UInt16(kVK_ANSI_KeypadEnter): String(UnicodeScalar(NSEnterCharacter)!),
        UInt16(kVK_Escape): String(UnicodeScalar(0x1B)!),
        UInt16(kVK_Delete): String(UnicodeScalar(NSDeleteCharacter)!),
        UInt16(kVK_ForwardDelete): String(UnicodeScalar(NSDeleteFunctionKey)!),
        UInt16(kVK_LeftArrow): String(UnicodeScalar(NSLeftArrowFunctionKey)!),
        UInt16(kVK_RightArrow): String(UnicodeScalar(NSRightArrowFunctionKey)!),
        UInt16(kVK_UpArrow): String(UnicodeScalar(NSUpArrowFunctionKey)!),
        UInt16(kVK_DownArrow): String(UnicodeScalar(NSDownArrowFunctionKey)!),
        UInt16(kVK_Home): String(UnicodeScalar(NSHomeFunctionKey)!),
        UInt16(kVK_End): String(UnicodeScalar(NSEndFunctionKey)!),
        UInt16(kVK_PageUp): String(UnicodeScalar(NSPageUpFunctionKey)!),
        UInt16(kVK_PageDown): String(UnicodeScalar(NSPageDownFunctionKey)!),
        UInt16(kVK_F1): String(UnicodeScalar(NSF1FunctionKey)!),
        UInt16(kVK_F2): String(UnicodeScalar(NSF2FunctionKey)!),
        UInt16(kVK_F3): String(UnicodeScalar(NSF3FunctionKey)!),
        UInt16(kVK_F4): String(UnicodeScalar(NSF4FunctionKey)!),
        UInt16(kVK_F5): String(UnicodeScalar(NSF5FunctionKey)!),
        UInt16(kVK_F6): String(UnicodeScalar(NSF6FunctionKey)!),
        UInt16(kVK_F7): String(UnicodeScalar(NSF7FunctionKey)!),
        UInt16(kVK_F8): String(UnicodeScalar(NSF8FunctionKey)!),
        UInt16(kVK_F9): String(UnicodeScalar(NSF9FunctionKey)!),
        UInt16(kVK_F10): String(UnicodeScalar(NSF10FunctionKey)!),
        UInt16(kVK_F11): String(UnicodeScalar(NSF11FunctionKey)!),
        UInt16(kVK_F12): String(UnicodeScalar(NSF12FunctionKey)!),
    ]

    private static let modifierKeyCodes: Set<UInt16> = [
        UInt16(kVK_Shift),
        UInt16(kVK_RightShift),
        UInt16(kVK_Control),
        UInt16(kVK_RightControl),
        UInt16(kVK_Option),
        UInt16(kVK_RightOption),
        UInt16(kVK_Command),
        UInt16(kVK_RightCommand),
        UInt16(kVK_CapsLock),
        UInt16(kVK_Function),
    ]
}
