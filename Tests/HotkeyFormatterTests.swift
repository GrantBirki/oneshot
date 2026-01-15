import AppKit
import Carbon.HIToolbox
@testable import OneShot
import XCTest

final class HotkeyFormatterTests: XCTestCase {
    func testModifierOrderingUsesCommandControlOptionShift() {
        let hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_4), modifiers: [.command, .shift])
        XCTAssertEqual(hotkey.displayString, "\u{2318}\u{21E7}4")

        let controlOptionHotkey = Hotkey(keyCode: UInt16(kVK_ANSI_P), modifiers: [.control, .option])
        XCTAssertEqual(controlOptionHotkey.displayString, "\u{2303}\u{2325}P")
    }

    func testKeyCodeMappingHandlesSpecialKeys() {
        XCTAssertEqual(HotkeyFormatter.keyString(for: UInt16(kVK_Return)), "Return")
        XCTAssertEqual(HotkeyFormatter.keyString(for: UInt16(kVK_LeftArrow)), "\u{2190}")
    }
}
