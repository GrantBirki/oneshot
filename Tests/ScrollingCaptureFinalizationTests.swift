import CoreGraphics
import Dispatch
@testable import OneShot
import XCTest

@MainActor
final class ScrollingCaptureFinalizationTests: XCTestCase {
    func testCancellationOverridesSizeLimitDuringFinalization() async {
        await assertFinalizationResult(verticalOffset: 2, expectedReason: .cancelled) { $0.cancel() }
    }

    func testCancellationOverridesCaptureFailureDuringFinalization() async {
        await assertFinalizationResult(verticalOffset: nil, expectedReason: .cancelled) { $0.cancel() }
    }

    func testStopPreservesSizeLimitDuringFinalization() async {
        await assertFinalizationResult(verticalOffset: 2, expectedReason: .limitReached) { $0.stop() }
    }

    func testStopPreservesCaptureFailureDuringFinalization() async {
        await assertFinalizationResult(verticalOffset: nil, expectedReason: .captureFailed) { $0.stop() }
    }

    private func assertFinalizationResult(
        verticalOffset: CGFloat?,
        expectedReason: ScrollingCompletionReason,
        action: (ScrollingCaptureSession) -> Void,
    ) async {
        let finalizationStarted = expectation(description: "Final composition reached")
        let finished = expectation(description: "Late request resolved")
        let resumeFinalization = DispatchSemaphore(value: 0)
        defer { resumeFinalization.signal() }
        let calculator = FinalizationOffsetCalculator(
            vertical: verticalOffset,
            started: finalizationStarted,
            resume: resumeFinalization,
        )
        let stitcher = ScrollingStitcher(offsetCalculator: calculator, maxPixelCount: 20)
        let session = ScrollingCaptureSession(
            maximumConsecutiveFailures: 1,
            stitcher: stitcher,
            clock: ScrollingSessionClock(
                now: { ContinuousClock.now },
                sleep: { _ in await Task.yield() },
            ),
        ) { _ in makeFinalizationFrame() }

        session.start(rect: CGRect(x: 0, y: 0, width: 4, height: 4)) { result in
            XCTAssertEqual(result.reason, expectedReason)
            XCTAssertEqual(result.image?.height, 4)
            finished.fulfill()
        }

        await fulfillment(of: [finalizationStarted], timeout: 2)
        action(session)
        resumeFinalization.signal()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertFalse(session.isActive)
    }
}

/// Mutable calculator state stays on the stitcher actor; the expectation and semaphore are thread-safe.
private struct FinalizationOffsetCalculator: @unchecked Sendable, ScrollingOffsetCalculating {
    let vertical: CGFloat?
    let started: XCTestExpectation
    let resume: DispatchSemaphore
    private var didCalculateOffset = false

    init(vertical: CGFloat?, started: XCTestExpectation, resume: DispatchSemaphore) {
        self.vertical = vertical
        self.started = started
        self.resume = resume
    }

    mutating func offset(from _: CGImage, to _: CGImage) -> ScrollingOffset? {
        didCalculateOffset = true
        return vertical.map { ScrollingOffset(horizontal: 0, vertical: $0) }
    }

    mutating func reset() {
        // Only finish() resets after registration; initial session/frame resets stay unblocked.
        guard didCalculateOffset else { return }
        didCalculateOffset = false
        started.fulfill()
        XCTAssertEqual(resume.wait(timeout: .now() + 5), .success)
    }
}

private func makeFinalizationFrame() -> CGImage {
    CGContext(
        data: nil,
        width: 4,
        height: 4,
        bitsPerComponent: 8,
        bytesPerRow: 4 * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )!.makeImage()!
}
