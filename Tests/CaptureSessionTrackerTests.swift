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

    @MainActor
    func testTaskCompletionRaceReturnsAtTimeoutWithoutWaitingForObservedTask() async {
        let blocker = AsyncBlocker()
        let task = Task { @MainActor in
            await blocker.wait()
        }

        let completed = await TaskCompletionRace.wait(
            for: task,
            timeout: .seconds(5),
            sleeper: { _ in },
        )

        XCTAssertFalse(completed)
        blocker.resume()
        await task.value
    }
}

@MainActor
private final class AsyncBlocker {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isResolved = false

    func wait() async {
        if isResolved {
            return
        }
        await withCheckedContinuation { continuation in
            if isResolved {
                continuation.resume()
            } else {
                self.continuation = continuation
            }
        }
    }

    func resume() {
        isResolved = true
        continuation?.resume()
        continuation = nil
    }
}
