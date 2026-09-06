import AppKit
import Carbon.HIToolbox
@testable import OneShot
import XCTest

final class HotkeyParserTests: XCTestCase {
    func testParsesControlKey() {
        let hotkey = HotkeyParser.parse("ctrl+p")
        XCTAssertNotNil(hotkey)
        XCTAssertEqual(hotkey?.keyCode, UInt16(kVK_ANSI_P))
        XCTAssertTrue(hotkey?.modifiers.contains(.control) ?? false)
    }

    func testParsesMultipleModifiers() {
        let hotkey = HotkeyParser.parse("ctrl+shift+p")
        XCTAssertNotNil(hotkey)
        XCTAssertTrue(hotkey?.modifiers.contains(.shift) ?? false)
        XCTAssertTrue(hotkey?.modifiers.contains(.control) ?? false)
    }

    func testInvalidHotkeyReturnsNil() {
        XCTAssertNil(HotkeyParser.parse("ctrl+"))
        XCTAssertNil(HotkeyParser.parse("d"))
        XCTAssertNil(HotkeyParser.parse(""))
        XCTAssertNil(HotkeyParser.parse("ctrl+?"))
        XCTAssertNil(HotkeyParser.parse("ctrl+p+?"))
    }

    func testParsesSpacesAndMixedCase() {
        XCTAssertEqual(
            HotkeyParser.parse(" Ctrl + Shift + P "),
            Hotkey(keyCode: UInt16(kVK_ANSI_P), modifiers: [.control, .shift]),
        )
    }

    func testParsesModifierAliases() {
        let aliases: [(String, NSEvent.ModifierFlags)] = [
            ("ctrl", .control), ("control", .control),
            ("shift", .shift),
            ("alt", .option), ("option", .option),
            ("cmd", .command), ("command", .command),
        ]
        for (alias, modifier) in aliases {
            XCTAssertEqual(
                HotkeyParser.parse("\(alias)+p"),
                Hotkey(keyCode: UInt16(kVK_ANSI_P), modifiers: modifier),
                alias,
            )
        }
    }

    func testParsesNamedKeys() {
        let keys = [
            ("space", kVK_Space), ("tab", kVK_Tab),
            ("return", kVK_Return), ("enter", kVK_ANSI_KeypadEnter),
            ("esc", kVK_Escape), ("escape", kVK_Escape),
            ("delete", kVK_Delete), ("forward delete", kVK_ForwardDelete),
            ("left", kVK_LeftArrow), ("right", kVK_RightArrow),
            ("up", kVK_UpArrow), ("down", kVK_DownArrow),
        ]
        for (name, keyCode) in keys {
            XCTAssertEqual(
                HotkeyParser.parse("cmd+\(name)"),
                Hotkey(keyCode: UInt16(keyCode), modifiers: .command),
                name,
            )
        }
    }

    func testPreservesLegacyTokenHandling() {
        let expected = Hotkey(keyCode: UInt16(kVK_ANSI_P), modifiers: [.control, .shift])
        for value in ["p+shift+ctrl", "ctrl+ctrl+shift+p", "ctrl++shift+p+", "ctrl+shift+?+p"] {
            XCTAssertEqual(HotkeyParser.parse(value), expected, value)
        }
    }
}
