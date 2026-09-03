import AppKit
@testable import OneShot
import XCTest

final class ClipboardServiceTests: XCTestCase {
    @MainActor
    func testCopyWritesPNGAndTIFF() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()

        let pngData = try makePNGData(width: 1, height: 1)
        try await ClipboardService.copy(pngData: pngData, to: pasteboard)

        XCTAssertNotNil(pasteboard.data(forType: .png))
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
    }

    @MainActor
    func testCopyPreservesPixelDimensionsAndDisplaySize() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        for scale: CGFloat in [2, 1] {
            let pngData = try makePNGData(width: 12, height: 8, scale: scale)
            try await ClipboardService.copy(pngData: pngData, to: pasteboard)

            XCTAssertEqual(pasteboard.data(forType: .png), pngData)
            for type: NSPasteboard.PasteboardType in [.png, .tiff] {
                let data = try XCTUnwrap(pasteboard.data(forType: type))
                let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
                let image = try XCTUnwrap(NSImage(data: data))
                let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
                let properties = try XCTUnwrap(
                    CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                )

                XCTAssertEqual(bitmap.pixelsWide, 12)
                XCTAssertEqual(bitmap.pixelsHigh, 8)
                XCTAssertEqual(image.size.width, 12 / scale, accuracy: 0.01)
                XCTAssertEqual(image.size.height, 8 / scale, accuracy: 0.01)
                XCTAssertEqual(
                    try XCTUnwrap(properties[kCGImagePropertyDPIWidth] as? Double), 72 * scale, accuracy: 0.1,
                )
                XCTAssertEqual(
                    try XCTUnwrap(properties[kCGImagePropertyDPIHeight] as? Double), 72 * scale, accuracy: 0.1,
                )
            }
        }
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

    private func makePNGData(width: Int, height: Int, scale: CGFloat = 1) throws -> Data {
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
        return try PNGDataEncoder.encode(cgImage: XCTUnwrap(rep.cgImage), scale: scale)
    }
}
