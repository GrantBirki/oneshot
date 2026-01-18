import AppKit
@testable import OneShot
import XCTest

final class ColorHexCodecTests: XCTestCase {
    func testNormalizedAcceptsSixDigitHex() {
        XCTAssertEqual(ColorHexCodec.normalized("a1b2c3"), "#A1B2C3FF")
        XCTAssertEqual(ColorHexCodec.normalized("#a1b2c3"), "#A1B2C3FF")
    }

    func testNormalizedAcceptsEightDigitHex() {
        XCTAssertEqual(ColorHexCodec.normalized("A1B2C3D4"), "#A1B2C3D4")
        XCTAssertEqual(ColorHexCodec.normalized("#a1b2c3d4"), "#A1B2C3D4")
    }

    func testNormalizedRejectsInvalidHex() {
        XCTAssertNil(ColorHexCodec.normalized(""))
        XCTAssertNil(ColorHexCodec.normalized("#12345"))
        XCTAssertNil(ColorHexCodec.normalized("GGHHII"))
    }

    func testNSColorFromHexMatchesComponents() {
        let color = ColorHexCodec.nsColor(from: "#33669980")
        XCTAssertNotNil(color)
        XCTAssertEqual(Double(color?.redComponent ?? 0), 0x33 / 255.0, accuracy: 0.001)
        XCTAssertEqual(Double(color?.greenComponent ?? 0), 0x66 / 255.0, accuracy: 0.001)
        XCTAssertEqual(Double(color?.blueComponent ?? 0), 0x99 / 255.0, accuracy: 0.001)
        XCTAssertEqual(Double(color?.alphaComponent ?? 0), 0x80 / 255.0, accuracy: 0.001)
    }

    func testHexFromColorRoundsToExpectedValue() {
        let color = NSColor(srgbRed: 1, green: 0.5, blue: 0, alpha: 0.25)
        XCTAssertEqual(ColorHexCodec.hex(from: color), "#FF800040")
    }
}
