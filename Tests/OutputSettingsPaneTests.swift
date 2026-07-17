@testable import OneShot
import XCTest

@MainActor
final class OutputSettingsPaneTests: XCTestCase {
    func testClipboardOnlyOutputForcesClipboardTogglePresentation() throws {
        try withSettings { settings in
            settings.previewEnabled = false
            settings.previewDisabledOutputBehavior = .clipboardOnly
            settings.autoCopyToClipboard = false
            let pane = OutputSettingsPane(settings: settings)

            XCTAssertTrue(settings.usesClipboardOnlyOutput)
            XCTAssertFalse(settings.usesDiskOutput)
            XCTAssertTrue(pane.autoCopyBinding.wrappedValue)
        }
    }

    func testLongFilenamePrefixIsShownAsShortened() throws {
        try withSettings { settings in
            settings.filenamePrefix = String(repeating: "📷", count: 200)
            let pane = OutputSettingsPane(settings: settings)

            XCTAssertTrue(pane.filenamePrefixWillBeShortened)
            XCTAssertLessThanOrEqual(
                pane.effectiveFilename.utf8.count,
                FilenameFormatter.maximumComponentBytes,
            )
        }
    }

    private func withSettings(_ body: (SettingsStore) throws -> Void) throws {
        let suiteName = "OutputSettingsPaneTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(SettingsStore(defaults: defaults))
    }
}
