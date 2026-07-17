import AppKit
import Carbon.HIToolbox
@testable import OneShot
import XCTest

final class HotkeyFormatterTests: XCTestCase {
    func testModifierOrderingUsesCommandControlOptionShift() {
        let hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_4), modifiers: [.command, .shift])
        XCTAssertTrue(hotkey.displayString.hasPrefix("\u{2318}\u{21E7}"))
        XCTAssertGreaterThan(hotkey.displayString.count, 2)

        let controlOptionHotkey = Hotkey(keyCode: UInt16(kVK_ANSI_P), modifiers: [.control, .option])
        XCTAssertTrue(controlOptionHotkey.displayString.hasPrefix("\u{2303}\u{2325}"))
        XCTAssertGreaterThan(controlOptionHotkey.displayString.count, 2)
    }

    func testKeyCodeMappingHandlesSpecialKeys() {
        XCTAssertEqual(HotkeyFormatter.keyString(for: UInt16(kVK_Return)), "Return")
        XCTAssertEqual(HotkeyFormatter.keyString(for: UInt16(kVK_LeftArrow)), "\u{2190}")
    }
}
