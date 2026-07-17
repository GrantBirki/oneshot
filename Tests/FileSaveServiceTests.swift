import AppKit
@testable import OneShot
import XCTest

final class FileSaveServiceTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "oneshot-filesave-\(UUID().uuidString)",
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

    func testSavePNGDataCreatesDirectoryAndWritesFile() throws {
        let directory = tempDirectory.appendingPathComponent("nested/dir", isDirectory: true)
        let pngData = makePNGData(width: 2, height: 2)

        let url = try FileSaveService.save(pngData: pngData, to: directory, filename: "screenshot.png")

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), pngData)
    }

    func testSavePNGDataDoesNotOverwriteExistingFile() throws {
        let existingURL = tempDirectory.appendingPathComponent("screenshot.png")
        let existingData = Data("existing".utf8)
        try existingData.write(to: existingURL)
        let pngData = makePNGData(width: 2, height: 2)

        let url = try FileSaveService.save(pngData: pngData, to: tempDirectory, filename: "screenshot.png")

        XCTAssertEqual(url.lastPathComponent, "screenshot-2.png")
        XCTAssertEqual(try Data(contentsOf: existingURL), existingData)
        XCTAssertEqual(try Data(contentsOf: url), pngData)
    }

    func testUniqueURLSkipsExistingNumberedSuffixes() throws {
        try Data().write(to: tempDirectory.appendingPathComponent("screenshot.png"))
        try Data().write(to: tempDirectory.appendingPathComponent("screenshot-2.png"))

        let url = FileSaveService.uniqueURL(for: "screenshot.png", in: tempDirectory)

        XCTAssertEqual(url.lastPathComponent, "screenshot-3.png")
    }

    func testUniqueURLHandlesFilenamesWithoutExtension() throws {
        try Data().write(to: tempDirectory.appendingPathComponent("screenshot"))

        let url = FileSaveService.uniqueURL(for: "screenshot", in: tempDirectory)

        XCTAssertEqual(url.lastPathComponent, "screenshot-2")
    }

    func testCollisionSuffixKeepsMultibyteFilenameWithinComponentLimit() throws {
        let filename = "\(String(repeating: "😀", count: 62)).png"
        try Data().write(to: tempDirectory.appendingPathComponent(filename))

        let url = FileSaveService.uniqueURL(for: filename, in: tempDirectory)

        XCTAssertLessThanOrEqual(url.lastPathComponent.utf8.count, FilenameFormatter.maximumComponentBytes)
        XCTAssertTrue(url.lastPathComponent.hasSuffix("-2.png"))
        XCTAssertNotNil(url.lastPathComponent.data(using: .utf8))
    }

    func testSaveImageWritesPNGFile() throws {
        let directory = tempDirectory.appendingPathComponent("images", isDirectory: true)
        let image = makeImage(width: 3, height: 3)

        let url = try FileSaveService.save(image: image, to: directory, filename: "image.png")

        let saved = try Data(contentsOf: url)
        XCTAssertEqual(Array(saved.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }

    func testSaveThrowsWhenDirectoryIsFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("not-a-directory")
        try Data("data".utf8).write(to: fileURL)
        let pngData = makePNGData(width: 1, height: 1)

        XCTAssertThrowsError(try FileSaveService.save(pngData: pngData, to: fileURL, filename: "test.png"))
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

    private func makeImage(width: Int, height: Int) -> NSImage {
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
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
    }
}
