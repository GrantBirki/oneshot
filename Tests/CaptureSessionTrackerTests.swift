@testable import OneShot
import XCTest

final class CaptureSessionTrackerTests: XCTestCase {
    func testBeginStartsFromIdle() {
        var tracker = CaptureSessionTracker()

        XCTAssertTrue(tracker.begin(.selecting))

        XCTAssertEqual(tracker.state, .selecting)
    }

    func testBeginBlocksConcurrentCapture() {
        var tracker = CaptureSessionTracker()

        XCTAssertTrue(tracker.begin(.selecting))
        XCTAssertFalse(tracker.begin(.windowSelecting))

        XCTAssertEqual(tracker.state, .selecting)
    }

    func testTransitionMovesActiveCaptureToProcessing() {
        var tracker = CaptureSessionTracker()

        XCTAssertTrue(tracker.begin(.selecting))
        tracker.transition(to: .processing)

        XCTAssertEqual(tracker.state, .processing)
    }

    func testFinishReturnsMatchingStateToIdle() {
        var tracker = CaptureSessionTracker()

        XCTAssertTrue(tracker.begin(.windowSelecting))
        tracker.finish(.windowSelecting)

        XCTAssertEqual(tracker.state, .idle)
    }

    func testFinishReturnsProcessingStateToIdle() {
        var tracker = CaptureSessionTracker()

        XCTAssertTrue(tracker.begin(.scrolling))
        tracker.transition(to: .processing)
        tracker.finish(.processing)

        XCTAssertEqual(tracker.state, .idle)
    }

    func testFinishIgnoresMismatchedActiveState() {
        var tracker = CaptureSessionTracker()

        XCTAssertTrue(tracker.begin(.selecting))
        tracker.finish(.windowSelecting)

        XCTAssertEqual(tracker.state, .selecting)
    }

    func testResetReturnsAnyStateToIdle() {
        var tracker = CaptureSessionTracker()

        XCTAssertTrue(tracker.begin(.scrolling))
        tracker.reset()

        XCTAssertEqual(tracker.state, .idle)
    }
}
