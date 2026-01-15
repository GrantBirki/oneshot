import XCTest
@testable import OneShot

final class HotkeyStringParserTests: XCTestCase {
    func testParsesAndNormalizesHotkey() {
        let parsed = HotkeyStringParser.parse(" Ctrl + Shift + P ")

        XCTAssertEqual(parsed?.normalized, "ctrl+shift+p")
        XCTAssertEqual(parsed?.key, "p")
        XCTAssertTrue(parsed?.modifiers.contains(.control) ?? false)
        XCTAssertTrue(parsed?.modifiers.contains(.shift) ?? false)
    }

    func testRejectsMissingKey() {
        XCTAssertNil(HotkeyStringParser.parse("ctrl+"))
    }

    func testRejectsUnknownKey() {
        XCTAssertNil(HotkeyStringParser.parse("ctrl+?"))
    }
}
