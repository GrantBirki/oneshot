@testable import OneShot
import XCTest

final class PreviewSaveSchedulerTests: XCTestCase {
    func testSchedulesSaveWhenNoPreviewTimeout() {
        XCTAssertTrue(PreviewSaveScheduler.shouldScheduleSave(previewTimeout: nil))
    }

    func testSkipsScheduledSaveWhenPreviewTimeoutIsSet() {
        XCTAssertFalse(PreviewSaveScheduler.shouldScheduleSave(previewTimeout: 7))
    }
}
