@testable import OneShot
import XCTest

@MainActor
final class CaptureSettingsPaneTests: XCTestCase {
    private struct PreviewRequest {
        let sound: ShutterSoundOption
        let volume: Double
        let isEnabled: Bool
    }

    func testPreviewShutterSoundUsesCurrentSettings() throws {
        try withSettings { settings in
            settings.shutterSound = .sonyA7II
            settings.shutterSoundVolume = 0.42
            settings.shutterSoundEnabled = true

            let request = try previewRequest(for: settings)

            XCTAssertEqual(request.sound, .sonyA7II)
            XCTAssertEqual(request.volume, 0.42, accuracy: 0.0001)
            XCTAssertEqual(request.isEnabled, true)
        }
    }

    func testPreviewShutterSoundPassesDisabledState() throws {
        try withSettings { settings in
            settings.shutterSound = .popPopCanonAE1
            settings.shutterSoundVolume = 0.18
            settings.shutterSoundEnabled = false

            let request = try previewRequest(for: settings)

            XCTAssertEqual(request.sound, .popPopCanonAE1)
            XCTAssertEqual(request.volume, 0.18, accuracy: 0.0001)
            XCTAssertEqual(request.isEnabled, false)
        }
    }

    func testRoundedVolumeClampsAndRoundsToPercentSteps() throws {
        try withSettings { settings in
            let pane = CaptureSettingsPane(settings: settings)

            XCTAssertEqual(pane.roundedVolume(-0.2), 0)
            XCTAssertEqual(pane.roundedVolume(1.4), 1)
            XCTAssertEqual(pane.roundedVolume(0.554), 0.55)
            XCTAssertEqual(pane.roundedVolume(0.556), 0.56)
        }
    }

    func testSanitizeHexInputKeepsOnlyEightUppercaseHexDigits() throws {
        try withSettings { settings in
            let pane = CaptureSettingsPane(settings: settings)

            XCTAssertEqual(pane.sanitizeHexInput("  #a1-b2 c3 d4 e5"), "#A1B2C3D4")
            XCTAssertEqual(pane.sanitizeHexInput("not-hex"), "#E")
            XCTAssertEqual(pane.sanitizeHexInput(""), "")
        }
    }

    private func previewRequest(for settings: SettingsStore) throws -> PreviewRequest {
        var preview: PreviewRequest?
        let pane = CaptureSettingsPane(settings: settings) { sound, volume, isEnabled in
            preview = PreviewRequest(sound: sound, volume: volume, isEnabled: isEnabled)
        }

        pane.previewShutterSound()

        return try XCTUnwrap(preview)
    }

    private func withSettings(_ body: (SettingsStore) throws -> Void) throws {
        let suiteName = "CaptureSettingsPaneTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try body(SettingsStore(defaults: defaults))
    }
}
