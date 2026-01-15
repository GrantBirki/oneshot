@testable import OneShot
import XCTest

final class FilenameFormatterTests: XCTestCase {
    func testFilenameIncludesTimezoneMarker() {
        let date = Date(timeIntervalSince1970: 0)
        let filename = FilenameFormatter.makeFilename(prefix: "screenshot", date: date)
        let sign = TimeZone.current.secondsFromGMT(for: date) >= 0 ? "tz_plus" : "tz_minus"

        XCTAssertTrue(filename.hasPrefix("screenshot_"))
        XCTAssertTrue(filename.hasSuffix(".png"))
        XCTAssertTrue(filename.contains(sign))
        XCTAssertTrue(filename.contains("T"))
    }

    func testFilenameSanitizesPrefix() {
        let date = Date(timeIntervalSince1970: 0)
        let filename = FilenameFormatter.makeFilename(prefix: "../foo/bar:..", date: date)

        XCTAssertTrue(filename.hasPrefix("foobar_"))
        XCTAssertFalse(filename.contains(".."))
        XCTAssertFalse(filename.contains("/"))
        XCTAssertFalse(filename.contains(":"))
    }

    func testFilenameUsesDefaultPrefixWhenSanitizedEmpty() {
        let date = Date(timeIntervalSince1970: 0)
        let filename = FilenameFormatter.makeFilename(prefix: "..", date: date)

        XCTAssertTrue(filename.hasPrefix("screenshot_"))
    }
}
