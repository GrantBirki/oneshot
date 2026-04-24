import AppKit
@testable import OneShot
import XCTest

@MainActor
final class ScrollingCaptureSessionTests: XCTestCase {
    func testScrollingCaptureWaitsForStitchingBeforeCapturingNextFrame() async {
        let probe = ScrollingCaptureProbe()
        let finished = expectation(description: "Scrolling capture finished")
        var finalImage: CGImage?
        let session = ScrollingCaptureSession(captureInterval: 0.001) { rect in
            await probe.capture(rect: rect)
        }

        session.start(rect: CGRect(x: 0, y: 0, width: 4, height: 4)) { image in
            finalImage = image
            finished.fulfill()
        }

        try? await Task.sleep(nanoseconds: 160_000_000)
        session.stop()

        await fulfillment(of: [finished], timeout: 2)
        let snapshot = await probe.snapshot()
        XCTAssertNotNil(finalImage)
        XCTAssertGreaterThanOrEqual(snapshot.captures, 1)
        XCTAssertEqual(snapshot.maxInFlight, 1)
    }

    func testScrollingCaptureBuildsReusableFrameCaptureOncePerSession() async {
        let factory = ScrollingFrameCaptureFactory()
        let finished = expectation(description: "Scrolling capture finished")
        let rect = CGRect(x: 10, y: 20, width: 40, height: 50)
        let stitcher = ScrollingStitcher(offsetCalculator: SessionOffsetCalculator(offset: 0))
        let session = ScrollingCaptureSession(captureInterval: 0.001, stitcher: stitcher) { rect in
            await factory.make(rect: rect)
        }

        session.start(rect: rect) { _ in
            finished.fulfill()
        }

        try? await Task.sleep(nanoseconds: 260_000_000)
        session.stop()

        await fulfillment(of: [finished], timeout: 2)
        let snapshot = await factory.snapshot()
        XCTAssertEqual(snapshot.factoryCalls, 1)
        XCTAssertGreaterThanOrEqual(snapshot.frameCalls, 2)
        XCTAssertEqual(snapshot.lastRect, rect)
    }
}

private struct SessionOffsetCalculator: ScrollingOffsetCalculating {
    let offset: CGFloat?

    func verticalOffset(from _: CGImage, to _: CGImage) -> CGFloat? {
        offset
    }
}

private actor ScrollingCaptureProbe {
    private var captures = 0
    private var inFlight = 0
    private var maxInFlight = 0

    func capture(rect _: CGRect) async -> CGImage? {
        captures += 1
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        try? await Task.sleep(nanoseconds: 40_000_000)
        inFlight -= 1
        return makeProbeImage()
    }

    func snapshot() -> (captures: Int, maxInFlight: Int) {
        (captures, maxInFlight)
    }

    private func makeProbeImage() -> CGImage {
        makeSolidProbeImage()
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

    func make(rect: CGRect) -> ScrollingFrameCapture? {
        factoryCalls += 1
        lastRect = rect
        return {
            await self.capture()
        }
    }

    func snapshot() -> Snapshot {
        Snapshot(factoryCalls: factoryCalls, frameCalls: frameCalls, lastRect: lastRect)
    }

    private func capture() -> CGImage {
        frameCalls += 1
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
