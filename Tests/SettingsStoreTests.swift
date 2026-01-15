import XCTest
@testable import OneShot

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsStoreTests")
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
        defaults = nil
        super.tearDown()
    }

    func testDefaultsAreApplied() {
        let settings = SettingsStore(defaults: defaults)
        XCTAssertFalse(settings.autoLaunchEnabled)
        XCTAssertEqual(settings.saveDelaySeconds, 7)
        XCTAssertTrue(settings.previewTimeoutEnabled)
        XCTAssertEqual(settings.previewTimeout, 7)
        XCTAssertTrue(settings.previewEnabled)
        XCTAssertEqual(settings.saveLocationOption, .downloads)
        XCTAssertEqual(settings.filenamePrefix, "screenshot")
        XCTAssertEqual(settings.hotkeySelection, "ctrl+p")
        XCTAssertEqual(settings.hotkeyFullScreen, "ctrl+shift+p")
    }

    func testValuesPersistToDefaults() {
        var settings = SettingsStore(defaults: defaults)
        settings.autoLaunchEnabled = true
        settings.saveDelaySeconds = 3
        settings.previewTimeoutEnabled = false
        settings.previewEnabled = false
        settings.saveLocationOption = .desktop
        settings.customSavePath = "/tmp"
        settings.filenamePrefix = "grab"
        settings.hotkeySelection = "ctrl+z"
        settings.hotkeyFullScreen = "ctrl+shift+z"
        settings.hotkeyWindow = "ctrl+w"

        settings = SettingsStore(defaults: defaults)
        XCTAssertTrue(settings.autoLaunchEnabled)
        XCTAssertEqual(settings.saveDelaySeconds, 3)
        XCTAssertFalse(settings.previewTimeoutEnabled)
        XCTAssertNil(settings.previewTimeout)
        XCTAssertFalse(settings.previewEnabled)
        XCTAssertEqual(settings.saveLocationOption, .desktop)
        XCTAssertEqual(settings.customSavePath, "/tmp")
        XCTAssertEqual(settings.filenamePrefix, "grab")
        XCTAssertEqual(settings.hotkeySelection, "ctrl+z")
        XCTAssertEqual(settings.hotkeyFullScreen, "ctrl+shift+z")
        XCTAssertEqual(settings.hotkeyWindow, "ctrl+w")
    }

    func testPreviewTimeoutUsesSaveDelay() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveDelaySeconds = 5
        settings.previewTimeoutEnabled = true
        XCTAssertEqual(settings.previewTimeout, 5)
    }
}
