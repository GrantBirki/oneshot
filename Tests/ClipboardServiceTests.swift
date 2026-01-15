import AppKit
import XCTest
@testable import OneShot

final class ClipboardServiceTests: XCTestCase {
    func testCopyWritesPNGAndTIFF() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()

        let pngData = makePNGData(width: 1, height: 1)
        ClipboardService.copy(pngData: pngData, to: pasteboard)

        XCTAssertNotNil(pasteboard.data(forType: .png))
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
    }

    private func makePNGData(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
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
        return rep.representation(using: .png, properties: [:])!
    }
}
