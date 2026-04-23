import AppKit
@testable import OneShot
import XCTest

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
            },
        )

        let pngData = makeTestPNGData()
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

    @MainActor
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
            },
        )

        let id = coordinator.begin(pngData: makeTestPNGData())
        wait(for: [saveExpectation], timeout: 2)

        coordinator.cancel(id: id)
        queue.sync {}

        guard let url = savedURL else {
            XCTFail("Missing saved URL")
            return
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testBeginCopiesPNGDataToClipboard() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 60

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let pngData = makeTestPNGData()
        var clipboardData: Data?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            clipboardCopy: { data in
                clipboardData = data
            },
        )

        let id = coordinator.begin(pngData: pngData)
        coordinator.cancel(id: id)
        queue.sync {}
        XCTAssertEqual(clipboardData, pngData)
    }

    @MainActor
    func testBeginSkipsClipboardWhenDisabled() {
        let settings = SettingsStore(defaults: defaults)
        settings.autoCopyToClipboard = false
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 60

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let pngData = makeTestPNGData()
        var clipboardData: Data?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            clipboardCopy: { data in
                clipboardData = data
            },
        )

        let id = coordinator.begin(pngData: pngData)
        coordinator.cancel(id: id)
        queue.sync {}
        XCTAssertNil(clipboardData)
    }

    @MainActor
    func testBeginWithoutSchedulingDefersSaveUntilFinalize() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 0

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let noSaveExpectation = expectation(description: "No save before finalize")
        noSaveExpectation.isInverted = true
        let saveExpectation = expectation(description: "Saved after finalize")
        var didFinalize = false

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            clipboardCopy: { _ in },
            onSave: { _, _ in
                if !didFinalize {
                    noSaveExpectation.fulfill()
                }
                saveExpectation.fulfill()
            },
        )

        let id = coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)
        wait(for: [noSaveExpectation], timeout: 0.2)
        didFinalize = true
        coordinator.finalize(id: id)
        wait(for: [saveExpectation], timeout: 2)
    }

    @MainActor
    func testFinalizeReturnsSavedURL() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 60

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let saveExpectation = expectation(description: "Finalize completion")
        var savedURL: URL?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
        )

        let pngData = makeTestPNGData()
        let id = coordinator.begin(pngData: pngData, scheduleSave: false)
        coordinator.finalize(id: id) { url in
            savedURL = url
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: 2)
        guard let url = savedURL else {
            XCTFail("Missing saved URL")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let savedData = try? Data(contentsOf: url)
        XCTAssertEqual(savedData, pngData)
    }

    @MainActor
    func testFinalizeReturnsSavedURLAfterScheduledSave() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 0

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let saveExpectation = expectation(description: "Saved")
        let finalizeExpectation = expectation(description: "Finalize completion")
        var savedURL: URL?
        var finalizedURL: URL?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
            onSave: { _, url in
                savedURL = url
                saveExpectation.fulfill()
            },
        )

        let id = coordinator.begin(pngData: makeTestPNGData())
        wait(for: [saveExpectation], timeout: 2)

        coordinator.finalize(id: id) { url in
            finalizedURL = url
            finalizeExpectation.fulfill()
        }

        wait(for: [finalizeExpectation], timeout: 2)
        guard let savedURL else {
            XCTFail("Missing saved URL")
            return
        }
        XCTAssertEqual(finalizedURL, savedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
    }

    @MainActor
    func testFinalizeReturnsNilWhenSaveFails() throws {
        let settings = SettingsStore(defaults: defaults)
        let invalidDirectory = tempDirectory.appendingPathComponent("not-a-directory")
        try Data("data".utf8).write(to: invalidDirectory)
        settings.saveLocationOption = .custom
        settings.customSavePath = invalidDirectory.path
        settings.saveDelaySeconds = 0

        let queue = DispatchQueue(label: "OutputCoordinatorTests.queue")
        let finalizeExpectation = expectation(description: "Finalize completion")
        var finalizedURL: URL?

        let coordinator = OutputCoordinator(
            settings: settings,
            queue: queue,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
        )

        let id = coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)
        coordinator.finalize(id: id) { url in
            finalizedURL = url
            finalizeExpectation.fulfill()
        }

        wait(for: [finalizeExpectation], timeout: 2)
        XCTAssertNil(finalizedURL)
        XCTAssertEqual(coordinator.pendingSaveCountForTesting(), 0)
    }
}

private func makeTestPNGData() -> Data {
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
