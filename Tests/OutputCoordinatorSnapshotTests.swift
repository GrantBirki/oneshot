import AppKit
@testable import OneShot
import XCTest

final class OutputCoordinatorSnapshotTests: XCTestCase {
    @MainActor
    func testFinalizeUsesSettingsSnapshotFromBegin() async throws {
        let suiteName = "OutputCoordinatorSnapshotTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let settings = SettingsStore(defaults: defaults)
        settings.saveLocationOption = .custom
        settings.customSavePath = tempDirectory.path
        settings.filenamePrefix = "initial"
        settings.autoCopyToClipboard = false
        let coordinator = OutputCoordinator(
            settings: settings,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            clipboardCopy: { _ in },
        )

        let id = await coordinator.begin(pngData: makeSnapshotTestPNGData(), scheduleSave: false)
        settings.customSavePath = tempDirectory.appendingPathComponent("changed").path
        settings.filenamePrefix = "changed"

        let output = try await coordinator.saveAndFinish(id: id)
        XCTAssertEqual(
            output.url.deletingLastPathComponent().standardizedFileURL.path,
            tempDirectory.standardizedFileURL.path,
        )
        XCTAssertTrue(output.url.lastPathComponent.hasPrefix("initial_"))
    }
}

private func makeSnapshotTestPNGData() -> Data {
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
