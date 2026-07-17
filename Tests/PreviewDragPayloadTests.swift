import AppKit
@testable import OneShot
import XCTest

final class PreviewDragPayloadTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "oneshot-preview-drag-tests-\(UUID().uuidString)",
            isDirectory: true,
        )
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        super.tearDown()
    }

    @MainActor
    func testFilePromiseUsesSafeFilenameAndWritesPNG() throws {
        let cgImage = try XCTUnwrap(makeBitmapRep(width: 1, height: 1).cgImage)
        let pngData = try PNGDataEncoder.encode(cgImage: cgImage)
        let payload = PreviewDragPayload(
            image: NSImage(cgImage: cgImage, size: NSSize(width: 1, height: 1)),
            pngData: pngData,
            filenamePrefix: "screenshot",
            dateProvider: { Date(timeIntervalSince1970: 0) },
        )
        let provider = NSFilePromiseProvider(fileType: "public.png", delegate: payload)
        let filename = payload.filePromiseProvider(provider, fileNameForType: "public.png")
        let completion = expectation(description: "Promise written")
        var writeError: Error?

        payload.filePromiseProvider(provider, writePromiseTo: tempDirectory) { error in
            writeError = error
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
        XCTAssertNil(writeError)
        XCTAssertEqual(try Data(contentsOf: tempDirectory.appendingPathComponent(filename)), pngData)
        XCTAssertLessThanOrEqual(filename.utf8.count, FilenameFormatter.maximumComponentBytes)
    }

    @MainActor
    func testDraggingItemAdvertisesFilePromiseWithoutCreatingTemporaryFile() throws {
        let cgImage = try XCTUnwrap(makeBitmapRep(width: 1, height: 1).cgImage)
        let payload = try PreviewDragPayload(
            image: NSImage(cgImage: cgImage, size: NSSize(width: 1, height: 1)),
            pngData: PNGDataEncoder.encode(cgImage: cgImage),
            filenamePrefix: "screenshot",
        )

        let item = payload.makeDraggingItem(dragFrame: NSRect(x: 0, y: 0, width: 10, height: 10))

        let provider = try XCTUnwrap(item.item as? NSFilePromiseProvider)
        XCTAssertEqual(payload.operationQueue(for: provider).maxConcurrentOperationCount, 1)
        XCTAssertTrue(try (FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)).isEmpty)
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
