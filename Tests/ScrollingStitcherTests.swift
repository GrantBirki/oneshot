import AppKit
@testable import OneShot
import XCTest

final class ScrollingStitcherTests: XCTestCase {
    func testVisionRegistrationReportsKnownVerticalAndHorizontalShift() throws {
        let previous = makeTexturedImage(width: 320, height: 240)
        let current = translatedImage(previous, horizontal: 7, vertical: 18)
        var calculator = VisionScrollingOffsetCalculator(maxRegistrationDimension: 900)

        let offset = try XCTUnwrap(calculator.offset(from: current, to: previous))

        XCTAssertEqual(offset.horizontal, 7, accuracy: 1)
        XCTAssertEqual(offset.vertical, 18, accuracy: 1)
    }

    func testVisionRegistrationDownscalesAndReusesPreviousAcceptedImage() throws {
        let first = makeTexturedImage(width: 600, height: 480)
        let second = translatedImage(first, horizontal: 0, vertical: 24)
        let third = translatedImage(second, horizontal: 0, vertical: 24)
        var calculator = VisionScrollingOffsetCalculator(maxRegistrationDimension: 150)

        let firstOffset = try XCTUnwrap(calculator.offset(from: second, to: first))
        let retainedImages = calculator.retainedImagesDuringOffset(from: third, to: second)
        let projectedBytes = calculator.projectedAdditionalBytesForOffset(from: third, to: second)
        let secondOffset = try XCTUnwrap(calculator.offset(from: third, to: second))

        XCTAssertEqual(firstOffset.vertical, 24, accuracy: 3)
        XCTAssertEqual(secondOffset.vertical, 24, accuracy: 3)
        XCTAssertEqual(retainedImages.count, 2)
        XCTAssertEqual(projectedBytes, 72000)
        XCTAssertEqual(calculator.retainedImagesForMemoryAccounting.count, 2)
        calculator.reset()
        XCTAssertTrue(calculator.retainedImagesForMemoryAccounting.isEmpty)
    }

    func testVisionRegistrationProjectsOnlyDownscaledBitmapBytes() {
        let previous = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let current = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)
        let calculator = VisionScrollingOffsetCalculator(maxRegistrationDimension: 2)

        let projectedBytes = calculator.projectedAdditionalBytesForOffset(
            from: current,
            to: previous,
        )

        XCTAssertEqual(projectedBytes, 32)
        XCTAssertTrue(calculator.retainedImagesDuringOffset(from: current, to: previous).isEmpty)
    }

    func testStitcherAppendsOnlyNewBottomStripForDownwardOffset() async {
        let stitcher = ScrollingStitcher(offsetCalculator: StubOffsetCalculator(vertical: 2))
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)

        await stitcher.start(with: base)
        let status = await stitcher.add(next)

        guard let result = await stitcher.finish() else {
            XCTFail("Expected stitched image")
            return
        }

        XCTAssertEqual(status, .accepted)
        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 6)

        let rep = NSBitmapImageRep(cgImage: result)
        assertColor(rep.colorAt(x: 0, y: 0), equals: .red)
        assertColor(rep.colorAt(x: 0, y: 2), equals: .blue)
        assertColor(rep.colorAt(x: 0, y: result.height - 1), equals: .yellow)
    }

    func testStitcherIgnoresReverseMovementWithoutCroppingResult() async {
        let stitcher = ScrollingStitcher(offsetCalculator: StubOffsetCalculator(vertical: -2))
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)

        await stitcher.start(with: base)
        let status = await stitcher.add(next)

        guard let result = await stitcher.finish() else {
            XCTFail("Expected original image")
            return
        }

        XCTAssertEqual(status, .ignored(.reverseMovement))
        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 4)
        let rep = NSBitmapImageRep(cgImage: result)
        assertColor(rep.colorAt(x: 0, y: 0), equals: .red)
        assertColor(rep.colorAt(x: 0, y: result.height - 1), equals: .blue)
    }

    func testStitcherIgnoresOnePixelVerticalNoise() async {
        for offset in [-1, 0, 1] {
            let stitcher = ScrollingStitcher(offsetCalculator: StubOffsetCalculator(vertical: CGFloat(offset)))
            let image = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)

            await stitcher.start(with: image)

            let status = await stitcher.add(image)
            XCTAssertEqual(status, .ignored(.noMovement))
        }
    }

    func testStitcherRejectsExcessiveHorizontalDrift() async {
        let stitcher = ScrollingStitcher(
            offsetCalculator: StubOffsetCalculator(horizontal: 5, vertical: 2),
        )
        let image = makeSplitImage(width: 100, height: 10, topColor: .red, bottomColor: .blue)

        await stitcher.start(with: image)

        let status = await stitcher.add(image)
        XCTAssertEqual(status, .ignored(.horizontalDrift))
    }

    func testStitcherUsesOnePercentHorizontalToleranceForWideCapture() async {
        let stitcher = ScrollingStitcher(
            offsetCalculator: StubOffsetCalculator(horizontal: 5, vertical: 2),
        )
        let image = makeSplitImage(width: 1000, height: 10, topColor: .red, bottomColor: .blue)

        await stitcher.start(with: image)

        let status = await stitcher.add(image)
        XCTAssertEqual(status, .accepted)
    }

    func testStitcherStopsAtPixelLimitAndReturnsBestResult() async {
        let stitcher = ScrollingStitcher(
            offsetCalculator: StubOffsetCalculator(vertical: 2),
            maxPixelCount: 20,
        )
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)

        await stitcher.start(with: base)
        let status = await stitcher.add(next)

        guard let result = await stitcher.finish() else {
            XCTFail("Expected best current image")
            return
        }

        XCTAssertEqual(status, .limitReached)
        let reachedLimit = await stitcher.reachedPixelLimitForTesting()
        XCTAssertTrue(reachedLimit)
        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 4)
    }

    func testStitcherStopsAtWorkingSetLimit() async {
        let stitcher = ScrollingStitcher(
            offsetCalculator: StubOffsetCalculator(vertical: 2),
            maxPixelCount: 1000,
            maxWorkingSetBytes: 255,
        )
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)

        let startStatus = await stitcher.start(with: base)
        let addStatus = await stitcher.add(next)
        XCTAssertEqual(startStatus, .accepted)
        XCTAssertEqual(addStatus, .limitReached)

        let result = await stitcher.finish()
        XCTAssertEqual(result?.height, 4)
    }

    func testStitcherAcceptsExactWorkingSetLimit() async {
        let stitcher = ScrollingStitcher(
            offsetCalculator: StubOffsetCalculator(vertical: 2),
            maxPixelCount: 1000,
            maxWorkingSetBytes: 256,
        )
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)

        let startStatus = await stitcher.start(with: base)
        let addStatus = await stitcher.add(next)
        let retainedByteCount = await stitcher.retainedByteCountForTesting()
        let result = await stitcher.finish()

        XCTAssertEqual(startStatus, .accepted)
        XCTAssertEqual(addStatus, .accepted)
        XCTAssertEqual(retainedByteCount, 96)
        XCTAssertEqual(result?.height, 6)
        XCTAssertEqual(result?.bytesPerRow, 16)
    }

    func testStitcherCountsRegistrationCacheInWorkingSetLimit() async {
        let cachedImage = makeSplitImage(width: 4, height: 4, topColor: .purple, bottomColor: .orange)
        let stitcher = ScrollingStitcher(
            offsetCalculator: RetainingOffsetCalculator(vertical: 2, retainedImage: cachedImage),
            maxPixelCount: 1000,
            maxWorkingSetBytes: 319,
        )
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)

        let startStatus = await stitcher.start(with: base)
        let addStatus = await stitcher.add(next)
        let result = await stitcher.finish()

        XCTAssertEqual(startStatus, .accepted)
        XCTAssertEqual(addStatus, .limitReached)
        XCTAssertEqual(result?.height, 4)
    }

    func testStitcherRetainsOnlyUniqueStrips() async {
        let stitcher = ScrollingStitcher(offsetCalculator: StubOffsetCalculator(vertical: 2))
        let image = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)

        await stitcher.start(with: image)
        let initialByteCount = await stitcher.retainedByteCountForTesting()
        XCTAssertEqual(initialByteCount, 64)

        await stitcher.add(image)
        let stitchedByteCount = await stitcher.retainedByteCountForTesting()
        let retainedSegmentHeights = await stitcher.retainedSegmentHeightsForTesting()
        XCTAssertGreaterThan(stitchedByteCount, initialByteCount)
        XCTAssertEqual(retainedSegmentHeights, [4, 2])

        _ = await stitcher.finish()
        let finishedByteCount = await stitcher.retainedByteCountForTesting()
        XCTAssertEqual(finishedByteCount, 0)
    }

    func testStitcherPreservesBestResultOnSizeMismatch() async {
        let stitcher = ScrollingStitcher(offsetCalculator: StubOffsetCalculator(vertical: 2))
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 3, height: 4, topColor: .green, bottomColor: .yellow)

        await stitcher.start(with: base)
        let status = await stitcher.add(next)

        guard let result = await stitcher.finish() else {
            XCTFail("Expected original image")
            return
        }

        XCTAssertEqual(status, .ignored(.incompatibleFrame))
        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 4)
    }

    func testStitcherRejectsDiscontinuousMovement() async {
        let stitcher = ScrollingStitcher(offsetCalculator: StubOffsetCalculator(vertical: 4))
        let image = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)

        await stitcher.start(with: image)

        let status = await stitcher.add(image)
        XCTAssertEqual(status, .ignored(.discontinuousMovement))
    }
}

private func makeTexturedImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )!
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for index in 0 ..< 80 {
        let red = CGFloat((index * 37) % 255) / 255
        let green = CGFloat((index * 71) % 255) / 255
        let blue = CGFloat((index * 113) % 255) / 255
        context.setFillColor(NSColor(red: red, green: green, blue: blue, alpha: 1).cgColor)
        context.fill(
            CGRect(
                x: (index * 53) % max(width - 23, 1),
                y: (index * 97) % max(height - 19, 1),
                width: 23,
                height: 19,
            ),
        )
    }
    return context.makeImage()!
}

private func translatedImage(_ image: CGImage, horizontal: CGFloat, vertical: CGFloat) -> CGImage {
    let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: image.bitsPerComponent,
        bytesPerRow: 0,
        space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: image.bitmapInfo.rawValue,
    )!
    context.draw(
        image,
        in: CGRect(
            x: horizontal,
            y: vertical,
            width: CGFloat(image.width),
            height: CGFloat(image.height),
        ),
    )
    return context.makeImage()!
}

private struct StubOffsetCalculator: ScrollingOffsetCalculating {
    let horizontal: CGFloat
    let vertical: CGFloat?

    init(horizontal: CGFloat = 0, vertical: CGFloat?) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    mutating func offset(from _: CGImage, to _: CGImage) -> ScrollingOffset? {
        vertical.map { ScrollingOffset(horizontal: horizontal, vertical: $0) }
    }
}

private struct RetainingOffsetCalculator: ScrollingOffsetCalculating {
    let vertical: CGFloat
    let retainedImage: CGImage

    var retainedImagesForMemoryAccounting: [CGImage] {
        [retainedImage]
    }

    mutating func offset(from _: CGImage, to _: CGImage) -> ScrollingOffset? {
        ScrollingOffset(horizontal: 0, vertical: vertical)
    }
}

private func makeSplitImage(width: Int, height: Int, topColor: NSColor, bottomColor: NSColor) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )!
    let split = max(height / 2, 1)
    context.setFillColor(bottomColor.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: split))
    context.setFillColor(topColor.cgColor)
    context.fill(CGRect(x: 0, y: split, width: width, height: height - split))
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
    XCTAssertEqual(color.alphaComponent, expected.alphaComponent, accuracy: 0.01, file: file, line: line)
}
