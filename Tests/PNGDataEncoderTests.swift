import AppKit
@testable import OneShot
import XCTest

final class PNGDataEncoderTests: XCTestCase {
    func testEncodeCGImageProducesPNGData() throws {
        let cgImage = makeCGImage(width: 1, height: 1)
        let data = try PNGDataEncoder.encode(cgImage: cgImage)

        XCTAssertTrue(data.count > 8)
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }

    func testEncodeNSImageUsesLargestRepresentation() throws {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        let smallRep = makeBitmapRep(width: 1, height: 1)
        let largeRep = makeBitmapRep(width: 3, height: 3)
        image.addRepresentation(smallRep)
        image.addRepresentation(largeRep)

        let data = try PNGDataEncoder.encode(image: image)
        let decoded = NSBitmapImageRep(data: data)

        XCTAssertEqual(decoded?.pixelsWide, 3)
        XCTAssertEqual(decoded?.pixelsHigh, 3)
    }

    private func makeCGImage(width: Int, height: Int) -> CGImage {
        makeBitmapRep(width: width, height: height).cgImage!
    }

    private func makeBitmapRep(width: Int, height: Int) -> NSBitmapImageRep {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
    }
}
