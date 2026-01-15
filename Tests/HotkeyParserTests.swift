import XCTest
import Carbon.HIToolbox
@testable import OneShot

final class HotkeyParserTests: XCTestCase {
    func testParsesControlKey() {
        let hotkey = HotkeyParser.parse("ctrl+p")
        XCTAssertNotNil(hotkey)
        XCTAssertEqual(hotkey?.keyCode, 35)
        guard let modifiers = hotkey?.modifiers else {
            XCTFail("Missing modifiers")
            return
        }
        XCTAssertEqual(modifiers & UInt32(controlKey), UInt32(controlKey))
    }

    func testParsesMultipleModifiers() {
        let hotkey = HotkeyParser.parse("ctrl+shift+p")
        XCTAssertNotNil(hotkey)
        guard let modifiers = hotkey?.modifiers else {
            XCTFail("Missing modifiers")
            return
        }
        XCTAssertEqual(modifiers & UInt32(shiftKey), UInt32(shiftKey))
        XCTAssertEqual(modifiers & UInt32(controlKey), UInt32(controlKey))
    }

    func testInvalidHotkeyReturnsNil() {
        XCTAssertNil(HotkeyParser.parse("ctrl+"))
        XCTAssertNil(HotkeyParser.parse(""))
    }
}
