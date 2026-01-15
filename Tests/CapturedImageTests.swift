import AppKit
@testable import OneShot
import XCTest

final class CapturedImageTests: XCTestCase {
    func testCapturedImageKeepsFullResolutionPNG() throws {
        let cgImage = makeCGImage(width: 4, height: 4)
        let captured = try CapturedImage(
            cgImage: cgImage,
            displaySize: NSSize(width: 2, height: 2)
        )

        let decoded = NSBitmapImageRep(data: captured.pngData)

        XCTAssertEqual(decoded?.pixelsWide, 4)
        XCTAssertEqual(decoded?.pixelsHigh, 4)
        XCTAssertEqual(captured.previewImage.size.width, 2)
        XCTAssertEqual(captured.previewImage.size.height, 2)
    }

    private func makeCGImage(width: Int, height: Int) -> CGImage {
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
        )!.cgImage!
    }
}
