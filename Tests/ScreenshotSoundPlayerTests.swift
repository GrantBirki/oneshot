import Foundation
@testable import OneShot
import XCTest

final class ScreenshotSoundPlayerTests: XCTestCase {
    func testResolveSoundURLReturnsFirstMatch() {
        let expected = URL(fileURLWithPath: "/tmp/shutter.wav")
        let missing = StubBundle(result: nil)
        let hit = StubBundle(result: expected)
        let skipped = StubBundle(result: URL(fileURLWithPath: "/tmp/other.wav"))

        let url = ScreenshotSoundPlayer.resolveSoundURL(
            soundName: "shutter",
            soundExtension: "wav",
            bundles: [missing, hit, skipped],
        )

        XCTAssertEqual(url, expected)
        XCTAssertEqual(missing.requests.first, StubBundle.Request(name: "shutter", ext: "wav"))
        XCTAssertEqual(hit.requests.first, StubBundle.Request(name: "shutter", ext: "wav"))
        XCTAssertTrue(skipped.requests.isEmpty)
    }

    func testResolveSoundURLReturnsNilWhenMissing() {
        let first = StubBundle(result: nil)
        let second = StubBundle(result: nil)

        let url = ScreenshotSoundPlayer.resolveSoundURL(
            soundName: "shutter",
            soundExtension: "wav",
            bundles: [first, second],
        )

        XCTAssertNil(url)
        XCTAssertEqual(first.requests.first, StubBundle.Request(name: "shutter", ext: "wav"))
        XCTAssertEqual(second.requests.first, StubBundle.Request(name: "shutter", ext: "wav"))
    }
}

private final class StubBundle: SoundResourceBundle {
    struct Request: Equatable {
        let name: String?
        let ext: String?
    }

    private(set) var requests: [Request] = []
    private let result: URL?

    init(result: URL?) {
        self.result = result
    }

    func url(forResource name: String?, withExtension ext: String?) -> URL? {
        requests.append(Request(name: name, ext: ext))
        return result
    }
}
