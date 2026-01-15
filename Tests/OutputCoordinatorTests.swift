import AppKit
import XCTest
@testable import OneShot

final class OutputCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        suiteName = "OutputCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        if let suiteName = suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        tempDirectory = nil
        super.tearDown()
    }

    func testFinalizeSavesImmediately() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 60

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let saveExpectation = expectation(description: "Saved")
        var savedURL: URL?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
            onSave: { _, url in
                savedURL = url
                saveExpectation.fulfill()
            }
        )

        let pngData = Self.makePNGData()
        let id = coordinator.begin(pngData: pngData)
        coordinator.finalize(id: id)

        wait(for: [saveExpectation], timeout: 2)
        guard let url = savedURL else {
            XCTFail("Missing saved URL")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let savedData = try? Data(contentsOf: url)
        XCTAssertEqual(savedData, pngData)
    }

    func testCancelDeletesSavedFileAfterSave() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 0

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let saveExpectation = expectation(description: "Saved")
        var savedURL: URL?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
            onSave: { _, url in
                savedURL = url
                saveExpectation.fulfill()
            }
        )

        let id = coordinator.begin(pngData: Self.makePNGData())
        wait(for: [saveExpectation], timeout: 2)

        coordinator.cancel(id: id)
        queue.sync {}

        guard let url = savedURL else {
            XCTFail("Missing saved URL")
            return
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testBeginCopiesPNGDataToClipboard() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 60

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let pngData = Self.makePNGData()
        var clipboardData: Data?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            clipboardCopy: { data in
                clipboardData = data
            }
        )

        let id = coordinator.begin(pngData: pngData)
        coordinator.cancel(id: id)
        queue.sync {}
        XCTAssertEqual(clipboardData, pngData)
    }

    private static func makePNGData() -> Data {
        let size = NSSize(width: 2, height: 2)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
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
