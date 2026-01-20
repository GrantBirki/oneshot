import AppKit
@testable import OneShot
import XCTest

final class ScrollingStitcherTests: XCTestCase {
    func testStitcherAddsDownwardOffset() {
        let stitcher = ScrollingStitcher(offsetCalculator: StubOffsetCalculator(offset: 2))
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)

        stitcher.start(with: base)
        stitcher.add(next)

        guard let result = stitcher.finish() else {
            XCTFail("Expected stitched image")
            return
        }

        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 6)

        let rep = NSBitmapImageRep(cgImage: result)
        assertColor(rep.colorAt(x: 0, y: 0), equals: .red)
        assertColor(rep.colorAt(x: 0, y: 2), equals: .green)
        assertColor(rep.colorAt(x: 0, y: result.height - 1), equals: .yellow)
    }

    func testStitcherCropsOnUpwardOffset() {
        let stitcher = ScrollingStitcher(offsetCalculator: StubOffsetCalculator(offset: -2))
        let base = makeSplitImage(width: 4, height: 4, topColor: .red, bottomColor: .blue)
        let next = makeSplitImage(width: 4, height: 4, topColor: .green, bottomColor: .yellow)

        stitcher.start(with: base)
        stitcher.add(next)

        guard let result = stitcher.finish() else {
            XCTFail("Expected cropped image")
            return
        }

        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 2)

        let rep = NSBitmapImageRep(cgImage: result)
        assertColor(rep.colorAt(x: 0, y: 0), equals: .red)
        assertColor(rep.colorAt(x: 0, y: result.height - 1), equals: .red)
    }
}

private struct StubOffsetCalculator: ScrollingOffsetCalculating {
    let offset: CGFloat?

    func verticalOffset(from _: CGImage, to _: CGImage) -> CGFloat? {
        offset
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

private func assertColor(_ color: NSColor?, equals expected: NSColor, file: StaticString = #file, line: UInt = #line) {
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
