import AppKit
import ImageIO
@testable import OneShot
import XCTest

final class PNGDataEncoderTests: XCTestCase {
    func testEncodeCGImageProducesPNGData() throws {
        let cgImage = makeCGImage(width: 1, height: 1)
        let data = try PNGDataEncoder.encode(cgImage: cgImage)

        XCTAssertTrue(data.count > 8)
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }

    func testEncodeAsyncProducesPNGData() async throws {
        let cgImage = makeCGImage(width: 2, height: 2)

        let data = try await PNGDataEncoder.encodeAsync(cgImage: cgImage)

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

    func testEncodeWritesDPIForRetinaScale() throws {
        let data = try PNGDataEncoder.encode(cgImage: makeCGImage(width: 2, height: 2), scale: 2)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])

        XCTAssertEqual(try XCTUnwrap(properties[kCGImagePropertyDPIWidth] as? Double), 144, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(properties[kCGImagePropertyDPIHeight] as? Double), 144, accuracy: 0.1)
    }

    func testEncodePreservesPixelsColorProfileAndScale() throws {
        for colorSpaceName in [CGColorSpace.sRGB, CGColorSpace.displayP3] {
            let colorSpace = try XCTUnwrap(CGColorSpace(name: colorSpaceName))
            let original = try makePixelFixture(colorSpace: colorSpace)
            let originalPixels = try pixels(of: original, colorSpace: colorSpace)

            for scale: CGFloat in [1, 2] {
                let expectedDPI = 72 * Double(scale)
                let data = try PNGDataEncoder.encode(cgImage: original, scale: scale)
                let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
                let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
                let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])

                XCTAssertEqual(decoded.width, original.width)
                XCTAssertEqual(decoded.height, original.height)
                XCTAssertEqual(decoded.colorSpace?.name as String?, colorSpaceName as String)
                XCTAssertEqual(try pixels(of: decoded, colorSpace: colorSpace), originalPixels)
                XCTAssertEqual(properties[kCGImagePropertyHasAlpha] as? Bool, true)
                XCTAssertEqual(
                    try XCTUnwrap(properties[kCGImagePropertyDPIWidth] as? Double),
                    expectedDPI,
                    accuracy: 0.1,
                )
                XCTAssertEqual(
                    try XCTUnwrap(properties[kCGImagePropertyDPIHeight] as? Double),
                    expectedDPI,
                    accuracy: 0.1,
                )
            }
        }
    }

    private func makePixelFixture(colorSpace: CGColorSpace) throws -> CGImage {
        let context = try makePixelContext(width: 8, height: 4, colorSpace: colorSpace)
        let colors: [[CGFloat]] = [
            [1, 0, 0], [0, 1, 0], [0, 0, 1], [0.25, 0.5, 0.75],
            [1, 0, 1], [1, 1, 0], [0, 0, 0], [1, 1, 1],
        ]
        context.setBlendMode(.copy)
        for (column, color) in colors.enumerated() {
            let stripe: CGFloat = column.isMultiple(of: 2) ? 0 : 1
            let rows = [[stripe, stripe, stripe, 1], color + [1], color + [0.5], color + [column == 0 ? 0 : 0.25]]
            for (row, components) in rows.enumerated() {
                context.setFillColor(components)
                context.fill(CGRect(x: column, y: row, width: 1, height: 1))
            }
        }
        return try XCTUnwrap(context.makeImage())
    }

    private func pixels(of image: CGImage, colorSpace: CGColorSpace) throws -> [UInt8] {
        let context = try makePixelContext(width: image.width, height: image.height, colorSpace: colorSpace)
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try XCTUnwrap(context.data)
        return Array(UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: image.width * image.height * 4,
        ))
    }

    private func makePixelContext(width: Int, height: Int, colorSpace: CGColorSpace) throws -> CGContext {
        try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue,
        ))
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
            bitsPerPixel: 0,
        )!
    }
}
