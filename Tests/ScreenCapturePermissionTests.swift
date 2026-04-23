@testable import OneShot
import XCTest

@MainActor
final class ScreenCapturePermissionTests: XCTestCase {
    func testScreenRecordingSettingsURLTargetsPrivacyPane() {
        let url = ScreenCapturePermission.screenRecordingSettingsURL

        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
        XCTAssertEqual(
            url.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        )
    }
}
