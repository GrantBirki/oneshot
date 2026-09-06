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
        let filename = FilenameFormatter.makeFilename(prefix: "../foo/bar:..\n\t", date: date)

        XCTAssertTrue(filename.hasPrefix("foobar_"))
        XCTAssertFalse(filename.contains(".."))
        XCTAssertFalse(filename.contains("/"))
        XCTAssertFalse(filename.contains(":"))
        XCTAssertFalse(filename.contains("\n"))
        XCTAssertFalse(filename.contains("\t"))
    }

    func testFilenameUsesDefaultPrefixWhenSanitizedEmpty() {
        let date = Date(timeIntervalSince1970: 0)
        let filename = FilenameFormatter.makeFilename(prefix: "..", date: date)

        XCTAssertTrue(filename.hasPrefix("screenshot_"))
    }

    func testFilenameNeverExceedsFilesystemComponentLimit() {
        let filename = FilenameFormatter.makeFilename(
            prefix: String(repeating: "very-long-prefix", count: 40),
            date: Date(timeIntervalSince1970: 0),
        )

        XCTAssertLessThanOrEqual(filename.utf8.count, FilenameFormatter.maximumComponentBytes)
        XCTAssertTrue(filename.hasSuffix(".png"))
    }

    func testFilenameTruncatesAtUnicodeCharacterBoundary() {
        let filename = FilenameFormatter.makeFilename(
            prefix: String(repeating: "📷", count: 100),
            date: Date(timeIntervalSince1970: 0),
        )

        XCTAssertLessThanOrEqual(filename.utf8.count, FilenameFormatter.maximumComponentBytes)
        XCTAssertNotNil(filename.data(using: .utf8))
        XCTAssertTrue(filename.hasSuffix(".png"))
    }

    func testTruncationPreservesWholeCharactersWithinByteBudget() {
        let family = "👩‍👩‍👧‍👦"
        let cases = [
            ("", 10, ""),
            ("abc", -1, ""),
            ("abc", 0, ""),
            ("abc", 2, "ab"),
            ("abc", 3, "abc"),
            ("abc", 4, "abc"),
            ("e\u{301}x", 2, ""),
            ("e\u{301}x", 3, "e\u{301}"),
            ("🇺🇸x", 7, ""),
            ("🇺🇸x", 8, "🇺🇸"),
            ("a\(family)b", 25, "a"),
            ("a\(family)b", 26, "a\(family)"),
        ]
        for (value, maximumBytes, expected) in cases {
            XCTAssertEqual(
                FilenameFormatter.truncateToUTF8Boundary(value, maximumBytes: maximumBytes),
                expected,
                "\(value) with a \(maximumBytes)-byte limit",
            )
        }
    }

    func testTruncationHandlesLongUnicodePrefix() {
        XCTAssertEqual(
            FilenameFormatter.truncateToUTF8Boundary(String(repeating: "📷", count: 100_000), maximumBytes: 210),
            String(repeating: "📷", count: 52),
        )
    }
}
