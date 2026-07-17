import AppKit
@testable import OneShot
import XCTest

final class ClipboardServiceTests: XCTestCase {
    @MainActor
    func testCopyWritesPNGAndTIFF() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()

        let pngData = makePNGData(width: 1, height: 1)
        try await ClipboardService.copy(pngData: pngData, to: pasteboard)

        XCTAssertNotNil(pasteboard.data(forType: .png))
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
    }

    @MainActor
    func testCopyWritesPNGForInvalidData() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()

        let pngData = Data([0x00, 0x01, 0x02])
        try await ClipboardService.copy(pngData: pngData, to: pasteboard)

        XCTAssertEqual(pasteboard.data(forType: .png), pngData)
        XCTAssertTrue(pasteboard.types?.contains(.png) ?? false)
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
            bitsPerPixel: 0,
        )!
        return rep.representation(using: .png, properties: [:])!
    }
}
