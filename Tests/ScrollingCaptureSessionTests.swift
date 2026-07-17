import AppKit
@testable import OneShot
import XCTest

@MainActor
final class ScrollingCaptureSessionTests: XCTestCase {
    func testScrollingCaptureWaitsForFrameBeforeCapturingNextFrame() async {
        let probe = ScrollingCaptureProbe()
        let finished = expectation(description: "Scrolling capture finished")
        let session = ScrollingCaptureSession(clock: .immediateForTesting) { rect in
            await probe.capture(rect: rect)
        }

        session.start(rect: CGRect(x: 0, y: 0, width: 4, height: 4)) { result in
            XCTAssertEqual(result.reason, .userStopped)
            XCTAssertNotNil(result.image)
            finished.fulfill()
        }

        await probe.waitForCaptures(3)
        session.stop()

        await fulfillment(of: [finished], timeout: 2)
        let snapshot = await probe.snapshot()
        XCTAssertGreaterThanOrEqual(snapshot.captures, 3)
        XCTAssertEqual(snapshot.maxInFlight, 1)
    }

    func testScrollingCaptureBuildsReusableFrameCaptureOncePerSession() async {
        let factory = ScrollingFrameCaptureFactory()
        let finished = expectation(description: "Scrolling capture finished")
        let rect = CGRect(x: 10, y: 20, width: 40, height: 50)
        let stitcher = ScrollingStitcher(offsetCalculator: SessionOffsetCalculator(vertical: 0))
        let session = ScrollingCaptureSession(
            stitcher: stitcher,
            clock: .immediateForTesting,
        ) { rect in
            await factory.make(rect: rect)
        }

        session.start(rect: rect) { _ in
            finished.fulfill()
        }

        await factory.waitForFrames(3)
        session.stop()

        await fulfillment(of: [finished], timeout: 2)
        let snapshot = await factory.snapshot()
        XCTAssertEqual(snapshot.factoryCalls, 1)
        XCTAssertGreaterThanOrEqual(snapshot.frameCalls, 3)
        XCTAssertEqual(snapshot.lastRect, rect)
    }

    func testScrollingCaptureStopsAfterFiveFrameFailures() async {
        let finished = expectation(description: "Scrolling capture failed")
        let session = ScrollingCaptureSession(
            clock: .immediateForTesting,
            captureImage: { _ in nil },
        )

        session.start(rect: CGRect(x: 0, y: 0, width: 4, height: 4)) { result in
            XCTAssertEqual(result.reason, .captureFailed)
            XCTAssertNil(result.image)
            finished.fulfill()
        }

        await fulfillment(of: [finished], timeout: 2)
    }

    func testScrollingCaptureStopsAfterFiveRegistrationFailuresWithBestImage() async {
        let finished = expectation(description: "Scrolling registration failed")
        let stitcher = ScrollingStitcher(offsetCalculator: SessionOffsetCalculator(vertical: nil))
        let session = ScrollingCaptureSession(
            stitcher: stitcher,
            clock: .immediateForTesting,
        ) { _ in
            makeSolidProbeImage()
        }

        session.start(rect: CGRect(x: 0, y: 0, width: 4, height: 4)) { result in
            XCTAssertEqual(result.reason, .captureFailed)
            XCTAssertNotNil(result.image)
            finished.fulfill()
        }

        await fulfillment(of: [finished], timeout: 2)
    }

    func testScrollingCaptureReportsLimitAndReturnsBestImage() async {
        let finished = expectation(description: "Scrolling capture reached limit")
        let stitcher = ScrollingStitcher(
            offsetCalculator: SessionOffsetCalculator(vertical: 2),
            maxPixelCount: 20,
        )
        let session = ScrollingCaptureSession(
            stitcher: stitcher,
            clock: .immediateForTesting,
        ) { _ in
            makeSolidProbeImage()
        }

        session.start(rect: CGRect(x: 0, y: 0, width: 4, height: 4)) { result in
            XCTAssertEqual(result.reason, .limitReached)
            XCTAssertEqual(result.image?.height, 4)
            finished.fulfill()
        }

        await fulfillment(of: [finished], timeout: 2)
    }

    func testScrollingCaptureCancelUsesCancelledReason() async {
        let probe = ScrollingCaptureProbe()
        let finished = expectation(description: "Scrolling capture cancelled")
        let session = ScrollingCaptureSession(clock: .immediateForTesting) { rect in
            await probe.capture(rect: rect)
        }

        session.start(rect: CGRect(x: 0, y: 0, width: 4, height: 4)) { result in
            XCTAssertEqual(result.reason, .cancelled)
            finished.fulfill()
        }

        await probe.waitForCaptures(1)
        session.cancel()

        await fulfillment(of: [finished], timeout: 2)
    }
}

private extension ScrollingSessionClock {
    static let immediateForTesting = ScrollingSessionClock(
        now: { ContinuousClock().now },
        sleep: { _ in await Task.yield() },
    )
}

private struct SessionOffsetCalculator: ScrollingOffsetCalculating {
    let vertical: CGFloat?

    mutating func offset(from _: CGImage, to _: CGImage) -> ScrollingOffset? {
        vertical.map { ScrollingOffset(horizontal: 0, vertical: $0) }
    }
}

private actor ScrollingCaptureProbe {
    private var captures = 0
    private var inFlight = 0
    private var maxInFlight = 0
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func capture(rect _: CGRect) async -> CGImage? {
        captures += 1
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        resumeSatisfiedWaiters()
        await Task.yield()
        inFlight -= 1
        return makeSolidProbeImage()
    }

    func waitForCaptures(_ count: Int) async {
        guard captures < count else { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    func snapshot() -> (captures: Int, maxInFlight: Int) {
        (captures, maxInFlight)
    }

    private func resumeSatisfiedWaiters() {
        let satisfied = waiters.filter { captures >= $0.count }
        waiters.removeAll { captures >= $0.count }
        satisfied.forEach { $0.continuation.resume() }
    }
}

private actor ScrollingFrameCaptureFactory {
    struct Snapshot {
        let factoryCalls: Int
        let frameCalls: Int
        let lastRect: CGRect?
    }

    private var factoryCalls = 0
    private var frameCalls = 0
    private var lastRect: CGRect?
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func make(rect: CGRect) -> ScrollingFrameCapture? {
        factoryCalls += 1
        lastRect = rect
        return {
            await self.capture()
        }
    }

    func waitForFrames(_ count: Int) async {
        guard frameCalls < count else { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    func snapshot() -> Snapshot {
        Snapshot(factoryCalls: factoryCalls, frameCalls: frameCalls, lastRect: lastRect)
    }

    private func capture() -> CGImage {
        frameCalls += 1
        let satisfied = waiters.filter { frameCalls >= $0.count }
        waiters.removeAll { frameCalls >= $0.count }
        satisfied.forEach { $0.continuation.resume() }
        return makeSolidProbeImage()
    }
}

private func makeSolidProbeImage() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: 4,
        height: 4,
        bitsPerComponent: 8,
        bytesPerRow: 4 * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )!
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    return context.makeImage()!
}
