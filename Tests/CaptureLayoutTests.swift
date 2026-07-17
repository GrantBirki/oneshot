import AppKit
@testable import OneShot
import XCTest

final class CaptureLayoutTests: XCTestCase {
    func testLayoutUsesHighestScaleAndPreservesHorizontalBoundary() throws {
        let layout = try XCTUnwrap(CaptureLayout.make(inputs: [
            CaptureLayoutInput(
                pointRect: CGRect(x: -100, y: 0, width: 100, height: 80),
                nativeScale: 1,
                pixelSize: CGSize(width: 100, height: 80),
            ),
            CaptureLayoutInput(
                pointRect: CGRect(x: 0, y: 0, width: 120, height: 80),
                nativeScale: 2,
                pixelSize: CGSize(width: 240, height: 160),
            ),
        ]))

        XCTAssertEqual(layout.pointBounds, CGRect(x: -100, y: 0, width: 220, height: 80))
        XCTAssertEqual(layout.outputScale, 2)
        XCTAssertEqual(layout.pixelSize, CGSize(width: 440, height: 160))
        XCTAssertEqual(layout.placements[0].pixelRect, CGRect(x: 0, y: 0, width: 200, height: 160))
        XCTAssertEqual(layout.placements[1].pixelRect, CGRect(x: 200, y: 0, width: 240, height: 160))
    }

    func testLayoutPreservesVerticalOrderAndNegativeOrigins() throws {
        let layout = try XCTUnwrap(CaptureLayout.make(inputs: [
            CaptureLayoutInput(
                pointRect: CGRect(x: -200, y: -100, width: 200, height: 100),
                nativeScale: 2,
                pixelSize: CGSize(width: 400, height: 200),
            ),
            CaptureLayoutInput(
                pointRect: CGRect(x: -200, y: 0, width: 200, height: 120),
                nativeScale: 2,
                pixelSize: CGSize(width: 400, height: 240),
            ),
        ]))

        XCTAssertEqual(layout.pixelSize, CGSize(width: 400, height: 440))
        XCTAssertEqual(layout.placements[0].pixelRect, CGRect(x: 0, y: 0, width: 400, height: 200))
        XCTAssertEqual(layout.placements[1].pixelRect, CGRect(x: 0, y: 200, width: 400, height: 240))
    }

    func testLayoutMapsSharedFractionalEdgeOnce() throws {
        let layout = try XCTUnwrap(CaptureLayout.make(inputs: [
            CaptureLayoutInput(
                pointRect: CGRect(x: 0, y: 0, width: 10.25, height: 10),
                nativeScale: 2,
                pixelSize: CGSize(width: 21, height: 20),
            ),
            CaptureLayoutInput(
                pointRect: CGRect(x: 10.25, y: 0, width: 9.75, height: 10),
                nativeScale: 2,
                pixelSize: CGSize(width: 20, height: 20),
            ),
        ]))

        let left = layout.placements[0].pixelRect
        let right = layout.placements[1].pixelRect
        XCTAssertEqual(left.maxX, right.minX)
        XCTAssertEqual(right.maxX, layout.pixelSize.width)
    }

    func testLayoutComposesThreeDisplaysWithoutChangingGlobalShape() throws {
        let layout = try XCTUnwrap(CaptureLayout.make(inputs: [
            CaptureLayoutInput(
                pointRect: CGRect(x: -80, y: 0, width: 80, height: 60),
                nativeScale: 1,
                pixelSize: CGSize(width: 80, height: 60),
            ),
            CaptureLayoutInput(
                pointRect: CGRect(x: 0, y: 0, width: 100, height: 60),
                nativeScale: 2,
                pixelSize: CGSize(width: 200, height: 120),
            ),
            CaptureLayoutInput(
                pointRect: CGRect(x: 0, y: -40, width: 100, height: 40),
                nativeScale: 2,
                pixelSize: CGSize(width: 200, height: 80),
            ),
        ]))

        XCTAssertEqual(layout.pointBounds, CGRect(x: -80, y: -40, width: 180, height: 100))
        XCTAssertEqual(layout.pixelSize, CGSize(width: 360, height: 200))
        XCTAssertEqual(layout.placements[0].pixelRect, CGRect(x: 0, y: 80, width: 160, height: 120))
        XCTAssertEqual(layout.placements[1].pixelRect, CGRect(x: 160, y: 80, width: 200, height: 120))
        XCTAssertEqual(layout.placements[2].pixelRect, CGRect(x: 160, y: 0, width: 200, height: 80))
    }

    func testCompositorRendersHorizontalMixedScalePiecesWithoutASeam() throws {
        let image = try XCTUnwrap(CaptureCompositor.composite([
            CapturedPiece(
                image: solidImage(width: 2, height: 2, color: .systemRed),
                pointRect: CGRect(x: -2, y: 0, width: 2, height: 2),
                nativeScale: 1,
            ),
            CapturedPiece(
                image: solidImage(width: 4, height: 4, color: .systemBlue),
                pointRect: CGRect(x: 0, y: 0, width: 2, height: 2),
                nativeScale: 2,
            ),
        ]))
        let rep = NSBitmapImageRep(cgImage: image)

        XCTAssertEqual(image.width, 8)
        XCTAssertEqual(image.height, 4)
        assertColor(rep.colorAt(x: 3, y: 1), equals: .systemRed)
        assertColor(rep.colorAt(x: 4, y: 1), equals: .systemBlue)
    }

    func testCompositorRendersVerticalPiecesInGlobalPointOrder() throws {
        let image = try XCTUnwrap(CaptureCompositor.composite([
            CapturedPiece(
                image: solidImage(width: 2, height: 2, color: .systemBlue),
                pointRect: CGRect(x: -2, y: -2, width: 2, height: 2),
                nativeScale: 1,
            ),
            CapturedPiece(
                image: solidImage(width: 2, height: 2, color: .systemRed),
                pointRect: CGRect(x: -2, y: 0, width: 2, height: 2),
                nativeScale: 1,
            ),
        ]))
        let rep = NSBitmapImageRep(cgImage: image)

        XCTAssertEqual(image.width, 2)
        XCTAssertEqual(image.height, 4)
        assertColor(rep.colorAt(x: 0, y: 0), equals: .systemRed)
        assertColor(rep.colorAt(x: 0, y: 3), equals: .systemBlue)
    }

    func testScrollingPreflightAllowsOnePositiveAreaIntersection() {
        let screens = [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 100, y: 0, width: 100, height: 100),
        ]

        XCTAssertEqual(
            ScrollingCapturePreflight.evaluate(
                rect: CGRect(x: 10, y: 10, width: 90, height: 80),
                screenFrames: screens,
            ),
            .ready,
        )
    }

    func testScrollingPreflightRejectsMultiplePositiveAreaIntersections() {
        let screens = [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 100, y: 0, width: 100, height: 100),
        ]

        XCTAssertEqual(
            ScrollingCapturePreflight.evaluate(
                rect: CGRect(x: 90, y: 10, width: 20, height: 80),
                screenFrames: screens,
            ),
            .multipleDisplays,
        )
    }

    func testScrollingPreflightTreatsBoundaryTouchAsSingleDisplay() {
        let screens = [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 100, y: 0, width: 100, height: 100),
        ]

        XCTAssertEqual(
            ScrollingCapturePreflight.evaluate(
                rect: CGRect(x: 10, y: 10, width: 90, height: 80),
                screenFrames: screens,
            ),
            .ready,
        )
    }

    func testScrollingPreflightRejectsInvalidAndOffscreenSelections() {
        let screen = CGRect(x: 0, y: 0, width: 100, height: 100)

        XCTAssertEqual(
            ScrollingCapturePreflight.evaluate(rect: .zero, screenFrames: [screen]),
            .invalidSelection,
        )
        XCTAssertEqual(
            ScrollingCapturePreflight.evaluate(
                rect: CGRect(x: 200, y: 200, width: 10, height: 10),
                screenFrames: [screen],
            ),
            .invalidSelection,
        )
    }
}

private func solidImage(width: Int, height: Int, color: NSColor) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )!
    context.setFillColor(color.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

private func assertColor(
    _ color: NSColor?,
    equals expected: NSColor,
    file: StaticString = #filePath,
    line: UInt = #line,
) {
    guard let color = color?.usingColorSpace(.deviceRGB),
          let expected = expected.usingColorSpace(.deviceRGB)
    else {
        XCTFail("Unable to read color", file: file, line: line)
        return
    }
    XCTAssertEqual(color.redComponent, expected.redComponent, accuracy: 0.01, file: file, line: line)
    XCTAssertEqual(color.greenComponent, expected.greenComponent, accuracy: 0.01, file: file, line: line)
    XCTAssertEqual(color.blueComponent, expected.blueComponent, accuracy: 0.01, file: file, line: line)
}
