import AppKit
@testable import OneShot
import XCTest

final class OutputCoordinatorSnapshotTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        suiteName = "OutputCoordinatorSnapshotTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        tempDirectory = nil
        super.tearDown()
    }

    @MainActor
    func testFinalizeUsesSettingsSnapshotFromBegin() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.filenamePrefix = "initial"
        settings.saveDelaySeconds = 60

        let queue = DispatchQueue(label: "OutputCoordinatorSnapshotTests.queue")
        let saveExpectation = expectation(description: "Finalize completion")
        var savedURL: URL?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
        )

        let id = coordinator.begin(pngData: makeSnapshotTestPNGData(), scheduleSave: false)
        settings.customSavePath = tempDirectory.appendingPathComponent("changed").path
        settings.filenamePrefix = "changed"

        coordinator.finalize(id: id) { url in
            savedURL = url
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: 2)
        guard let url = savedURL else {
            XCTFail("Missing saved URL")
            return
        }
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL.path, tempDirectory.standardizedFileURL.path)
        XCTAssertTrue(url.lastPathComponent.hasPrefix("initial_"))
    }
}

private func makeSnapshotTestPNGData() -> Data {
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
        bitsPerPixel: 0,
    )!
    return rep.representation(using: .png, properties: [:])!
}
