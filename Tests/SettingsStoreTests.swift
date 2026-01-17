@testable import OneShot
import XCTest

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
        XCTAssertFalse(settings.menuBarIconHidden)
        XCTAssertTrue(settings.showSelectionCoordinates)
        XCTAssertEqual(settings.saveDelaySeconds, 7)
        XCTAssertTrue(settings.previewTimeoutEnabled)
        XCTAssertEqual(settings.previewTimeout, 7)
        XCTAssertTrue(settings.previewEnabled)
        XCTAssertEqual(settings.previewAutoDismissBehavior, .saveToDisk)
        XCTAssertEqual(settings.previewReplacementBehavior, .saveImmediately)
        XCTAssertEqual(settings.previewDisabledOutputBehavior, .saveToDisk)
        XCTAssertTrue(settings.autoCopyToClipboard)
        XCTAssertEqual(settings.saveLocationOption, .downloads)
        XCTAssertEqual(settings.filenamePrefix, "screenshot")
        XCTAssertNil(settings.hotkeySelection)
        XCTAssertNil(settings.hotkeyFullScreen)
        XCTAssertNil(settings.hotkeyWindow)
    }

    func testValuesPersistToDefaults() {
        var settings = SettingsStore(defaults: defaults)
        settings.autoLaunchEnabled = true
        settings.menuBarIconHidden = true
        settings.showSelectionCoordinates = false
        settings.saveDelaySeconds = 3
        settings.previewTimeoutEnabled = false
        settings.previewEnabled = false
        settings.previewAutoDismissBehavior = .discard
        settings.previewReplacementBehavior = .discard
        settings.previewDisabledOutputBehavior = .clipboardOnly
        settings.autoCopyToClipboard = false
        settings.saveLocationOption = .desktop
        settings.customSavePath = "/tmp"
        settings.filenamePrefix = "grab"
        settings.hotkeySelection = HotkeyParser.parse("ctrl+z")
        settings.hotkeyFullScreen = HotkeyParser.parse("ctrl+shift+z")
        settings.hotkeyWindow = HotkeyParser.parse("ctrl+w")

        settings = SettingsStore(defaults: defaults)
        XCTAssertTrue(settings.autoLaunchEnabled)
        XCTAssertTrue(settings.menuBarIconHidden)
        XCTAssertFalse(settings.showSelectionCoordinates)
        XCTAssertEqual(settings.saveDelaySeconds, 3)
        XCTAssertFalse(settings.previewTimeoutEnabled)
        XCTAssertNil(settings.previewTimeout)
        XCTAssertFalse(settings.previewEnabled)
        XCTAssertEqual(settings.previewAutoDismissBehavior, .discard)
        XCTAssertEqual(settings.previewReplacementBehavior, .discard)
        XCTAssertEqual(settings.previewDisabledOutputBehavior, .clipboardOnly)
        XCTAssertFalse(settings.autoCopyToClipboard)
        XCTAssertEqual(settings.saveLocationOption, .desktop)
        XCTAssertEqual(settings.customSavePath, "/tmp")
        XCTAssertEqual(settings.filenamePrefix, "grab")
        XCTAssertEqual(settings.hotkeySelection, HotkeyParser.parse("ctrl+z"))
        XCTAssertEqual(settings.hotkeyFullScreen, HotkeyParser.parse("ctrl+shift+z"))
        XCTAssertEqual(settings.hotkeyWindow, HotkeyParser.parse("ctrl+w"))
    }

    func testPreviewTimeoutUsesSaveDelay() {
        let settings = SettingsStore(defaults: defaults)
        settings.saveDelaySeconds = 5
        settings.previewTimeoutEnabled = true
        XCTAssertEqual(settings.previewTimeout, 5)
    }

    func testClearingHotkeyPersists() {
        var settings = SettingsStore(defaults: defaults)
        settings.hotkeySelection = nil

        settings = SettingsStore(defaults: defaults)
        XCTAssertNil(settings.hotkeySelection)
    }
}
