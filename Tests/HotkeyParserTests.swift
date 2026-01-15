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
        XCTAssertNil(HotkeyParser.parse(""))
    }
}
