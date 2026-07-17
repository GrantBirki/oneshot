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
    func testFinalizeSavesAndFinishReleasesOutput() async throws {
        let settings = makeSettings()
        let coordinator = OutputCoordinator(
            settings: settings,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
        )
        let pngData = makeTestPNGData()

        let id = await coordinator.begin(pngData: pngData, scheduleSave: false)
        let result = try await coordinator.finalize(id: id)

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        XCTAssertEqual(try Data(contentsOf: result.url), pngData)
        let pendingBeforeFinish = await coordinator.pendingOutputCountForTesting()
        XCTAssertEqual(pendingBeforeFinish, 1)

        await coordinator.finish(id: id)
        let pendingAfterFinish = await coordinator.pendingOutputCountForTesting()
        XCTAssertEqual(pendingAfterFinish, 0)
    }

    @MainActor
    func testDiscardDeletesPreviouslySavedFileButDoesNotTouchClipboard() async throws {
        let settings = makeSettings()
        settings.autoCopyToClipboard = true
        var clipboardWrites = 0
        let coordinator = OutputCoordinator(
            settings: settings,
            clipboardCopy: { _ in clipboardWrites += 1 },
        )

        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)
        let result = try await coordinator.finalize(id: id)
        try await coordinator.discard(id: id)

        XCTAssertEqual(clipboardWrites, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))
        let pendingAfterDiscard = await coordinator.pendingOutputCountForTesting()
        XCTAssertEqual(pendingAfterDiscard, 0)
    }

    @MainActor
    func testDiscardTreatsCocoaMissingFileAsSuccess() async throws {
        let deleteCounter = LockedCounter()
        let coordinator = makeCoordinatorForDeleteTest { _ in
            deleteCounter.increment()
            throw CocoaError(.fileNoSuchFile)
        }
        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)
        _ = try await coordinator.finalize(id: id)

        try await coordinator.discard(id: id)
        let pendingCount = await coordinator.pendingOutputCountForTesting()

        XCTAssertEqual(deleteCounter.value, 1)
        XCTAssertEqual(pendingCount, 0)
    }

    @MainActor
    func testDiscardTreatsWrappedPOSIXMissingFileAsSuccess() async throws {
        let coordinator = makeCoordinatorForDeleteTest { _ in
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: CocoaError.fileReadUnknown.rawValue,
                userInfo: [NSUnderlyingErrorKey: POSIXError(.ENOENT)],
            )
        }
        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)
        _ = try await coordinator.finalize(id: id)

        try await coordinator.discard(id: id)
        let pendingCount = await coordinator.pendingOutputCountForTesting()

        XCTAssertEqual(pendingCount, 0)
    }

    @MainActor
    func testDiscardPreservesPendingOutputForRealDeleteFailure() async throws {
        let coordinator = makeCoordinatorForDeleteTest { _ in
            throw CocoaError(.fileWriteNoPermission)
        }
        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)
        _ = try await coordinator.finalize(id: id)

        do {
            try await coordinator.discard(id: id)
            XCTFail("Expected deletion to fail")
        } catch {
            guard case .deleteFailed = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }

        let pendingCount = await coordinator.pendingOutputCountForTesting()
        XCTAssertEqual(pendingCount, 1)
        await coordinator.finish(id: id)
    }

    @MainActor
    func testBeginSkipsClipboardWhenDisabled() async throws {
        let settings = makeSettings()
        settings.autoCopyToClipboard = false
        var clipboardWrites = 0
        let coordinator = OutputCoordinator(
            settings: settings,
            clipboardCopy: { _ in clipboardWrites += 1 },
        )

        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)
        XCTAssertEqual(clipboardWrites, 0)
        try await coordinator.discard(id: id)
    }

    @MainActor
    func testFailedSaveRemainsRecoverableThroughSaveAs() async throws {
        let settings = makeSettings()
        let invalidDirectory = tempDirectory.appendingPathComponent("not-a-directory")
        try Data("data".utf8).write(to: invalidDirectory)
        settings.customSavePath = invalidDirectory.path
        let coordinator = OutputCoordinator(
            settings: settings,
            clipboardCopy: { _ in },
        )
        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)

        do {
            _ = try await coordinator.finalize(id: id)
            XCTFail("Expected configured save to fail")
        } catch {
            guard case .saveFailed = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }

        let pendingAfterFailure = await coordinator.pendingOutputCountForTesting()
        XCTAssertEqual(pendingAfterFailure, 1)
        let recoveryURL = tempDirectory.appendingPathComponent("recovered.png")
        let recovered = try await coordinator.saveAndFinish(id: id, destination: .file(recoveryURL))
        XCTAssertEqual(recovered.url, recoveryURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recoveryURL.path))
        let pendingAfterRecovery = await coordinator.pendingOutputCountForTesting()
        XCTAssertEqual(pendingAfterRecovery, 0)
    }

    @MainActor
    func testMissingCustomDirectoryIsNotSilentlyRecreated() async throws {
        let settings = makeSettings()
        let coordinator = OutputCoordinator(settings: settings, clipboardCopy: { _ in })
        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)
        try FileManager.default.removeItem(at: tempDirectory)

        do {
            _ = try await coordinator.finalize(id: id)
            XCTFail("Expected the missing custom directory to fail")
        } catch {
            guard case .saveFailed = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.path))
        let pendingCount = await coordinator.pendingOutputCountForTesting()
        XCTAssertEqual(pendingCount, 1)
        try await coordinator.discard(id: id)
    }

    @MainActor
    func testInvalidCustomPathDoesNotFallBackToDownloads() async throws {
        let settings = makeSettings()
        settings.customSavePath = "relative/path"
        let saveCounter = LockedCounter()
        let store = OutputStore(saveFile: { _, _, _ in
            saveCounter.increment()
            return URL(fileURLWithPath: "/unused.png")
        })
        let coordinator = OutputCoordinator(settings: settings, clipboardCopy: { _ in }, store: store)
        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)

        do {
            _ = try await coordinator.finalize(id: id)
            XCTFail("Expected the invalid custom path to fail")
        } catch {
            guard case .saveFailed = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }

        XCTAssertEqual(saveCounter.value, 0)
        try await coordinator.discard(id: id)
    }

    @MainActor
    func testVanishedEarlySaveIsRecreatedFromPendingPNG() async throws {
        let settings = makeSettings()
        let coordinator = OutputCoordinator(
            settings: settings,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
        )
        let pngData = makeTestPNGData()
        let id = await coordinator.begin(pngData: pngData, scheduleSave: false)
        let first = try await coordinator.finalize(id: id)
        try FileManager.default.removeItem(at: first.url)

        let recovered = try await coordinator.finalize(id: id)

        XCTAssertTrue(FileManager.default.fileExists(atPath: recovered.url.path))
        XCTAssertEqual(try Data(contentsOf: recovered.url), pngData)
        await coordinator.finish(id: id)
    }

    @MainActor
    func testSaveAndFinishIsTerminalAndLaterDiscardCannotDeleteFile() async throws {
        let settings = makeSettings()
        let coordinator = OutputCoordinator(settings: settings, clipboardCopy: { _ in })
        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)

        let saved = try await coordinator.saveAndFinish(id: id)
        try await coordinator.discard(id: id)

        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.url.path))
    }

    @MainActor
    func testConcurrentFinalizeWritesExactlyOnce() async throws {
        let settings = makeSettings()
        let counter = LockedCounter()
        let store = OutputStore(
            saveFile: { data, directory, filename in
                counter.increment()
                return try FileSaveService.save(pngData: data, to: directory, filename: filename)
            },
        )
        let coordinator = OutputCoordinator(settings: settings, clipboardCopy: { _ in }, store: store)
        let id = await coordinator.begin(pngData: makeTestPNGData(), scheduleSave: false)

        async let first = coordinator.finalize(id: id)
        async let second = coordinator.finalize(id: id)
        let results = try await (first, second)

        XCTAssertEqual(results.0.url, results.1.url)
        XCTAssertEqual(counter.value, 1)
        await coordinator.finish(id: id)
    }

    @MainActor
    func testScheduledSaveUsesInjectedSleeperWithoutFixedDelay() async throws {
        let settings = makeSettings()
        settings.saveDelaySeconds = 60
        let sleepStarted = expectation(description: "Sleep requested")
        let saveFinished = expectation(description: "Save finished")
        let sleeper = ManualSleeper(onStart: { sleepStarted.fulfill() })
        let coordinator = OutputCoordinator(
            settings: settings,
            clipboardCopy: { _ in },
            sleeper: { duration in try await sleeper.sleep(duration) },
            onSave: { _, _ in saveFinished.fulfill() },
        )

        let id = await coordinator.begin(pngData: makeTestPNGData())
        await fulfillment(of: [sleepStarted], timeout: 1)
        let pendingWhileScheduled = await coordinator.pendingOutputCountForTesting()
        XCTAssertEqual(pendingWhileScheduled, 1)
        sleeper.resume()
        await fulfillment(of: [saveFinished], timeout: 1)
        try await coordinator.discard(id: id)
    }

    @MainActor
    private func makeSettings() -> SettingsStore {
        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.saveDelaySeconds = 60
        settings.autoCopyToClipboard = false
        return settings
    }

    @MainActor
    private func makeCoordinatorForDeleteTest(
        deleteFile: @escaping OutputStore.DeleteFile,
    ) -> OutputCoordinator {
        let savedURL = tempDirectory.appendingPathComponent("saved.png")
        let store = OutputStore(
            saveFile: { _, _, _ in savedURL },
            deleteFile: deleteFile,
        )
        return OutputCoordinator(
            settings: makeSettings(),
            clipboardCopy: { _ in },
            store: store,
        )
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.withLock { storage }
    }

    func increment() {
        lock.withLock { storage += 1 }
    }
}

private final class ManualSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private let onStart: @Sendable () -> Void
    private var continuation: CheckedContinuation<Void, Error>?

    init(onStart: @escaping @Sendable () -> Void) {
        self.onStart = onStart
    }

    func sleep(_: Duration) async throws {
        onStart()
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                self.continuation = continuation
            }
        }
    }

    func resume() {
        let continuation = lock.withLock {
            let value = self.continuation
            self.continuation = nil
            return value
        }
        continuation?.resume()
    }
}

private func makeTestPNGData() -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 2,
        pixelsHigh: 2,
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
