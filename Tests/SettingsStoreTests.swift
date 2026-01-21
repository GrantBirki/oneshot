import AppKit
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
        XCTAssertEqual(settings.selectionDimmingMode, .fullScreen)
        XCTAssertEqual(
            settings.selectionDimmingColorHex,
            ColorHexCodec.defaultSelectionDimmingColorHex,
        )
        XCTAssertEqual(settings.selectionVisualCue, .none)
        XCTAssertTrue(settings.autoCopyToClipboard)
        XCTAssertEqual(settings.saveLocationOption, .downloads)
        XCTAssertEqual(settings.filenamePrefix, "screenshot")
        XCTAssertTrue(settings.shutterSoundEnabled)
        XCTAssertEqual(settings.shutterSound, .shutter)
        XCTAssertEqual(settings.shutterSoundVolume, 1.0)
        XCTAssertNil(settings.hotkeySelection)
        XCTAssertNil(settings.hotkeyFullScreen)
        XCTAssertNil(settings.hotkeyWindow)
        XCTAssertNil(settings.hotkeyScrolling)
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
        settings.selectionDimmingMode = .selectionOnly
        settings.selectionDimmingColorHex = "#336699CC"
        settings.selectionVisualCue = .none
        settings.autoCopyToClipboard = false
        settings.saveLocationOption = .desktop
        settings.customSavePath = "/tmp"
        settings.filenamePrefix = "grab"
        settings.shutterSoundEnabled = false
        settings.shutterSound = .sonyA7II
        settings.shutterSoundVolume = 0.35
        settings.hotkeySelection = HotkeyParser.parse("ctrl+z")
        settings.hotkeyFullScreen = HotkeyParser.parse("ctrl+shift+z")
        settings.hotkeyWindow = HotkeyParser.parse("ctrl+w")
        settings.hotkeyScrolling = HotkeyParser.parse("ctrl+shift+s")

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
        XCTAssertEqual(settings.selectionDimmingMode, .selectionOnly)
        XCTAssertEqual(settings.selectionDimmingColorHex, "#336699CC")
        XCTAssertEqual(settings.selectionVisualCue, .none)
        XCTAssertFalse(settings.autoCopyToClipboard)
        XCTAssertEqual(settings.saveLocationOption, .desktop)
        XCTAssertEqual(settings.customSavePath, "/tmp")
        XCTAssertEqual(settings.filenamePrefix, "grab")
        XCTAssertFalse(settings.shutterSoundEnabled)
        XCTAssertEqual(settings.shutterSound, .sonyA7II)
        XCTAssertEqual(settings.shutterSoundVolume, 0.35, accuracy: 0.0001)
        XCTAssertEqual(settings.hotkeySelection, HotkeyParser.parse("ctrl+z"))
        XCTAssertEqual(settings.hotkeyFullScreen, HotkeyParser.parse("ctrl+shift+z"))
        XCTAssertEqual(settings.hotkeyWindow, HotkeyParser.parse("ctrl+w"))
        XCTAssertEqual(settings.hotkeyScrolling, HotkeyParser.parse("ctrl+shift+s"))
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

    func testLegacyPreviewTimeoutMigratesToSaveDelay() {
        defaults.set(3.5, forKey: "settings.previewTimeoutSeconds")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.saveDelaySeconds, 3.5)
        XCTAssertNil(defaults.object(forKey: "settings.previewTimeoutSeconds"))
    }

    func testLegacyHotkeyMigratesToStoredKeys() {
        defaults.set("ctrl+z", forKey: "settings.hotkeySelection")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.hotkeySelection, HotkeyParser.parse("ctrl+z"))
        XCTAssertNil(defaults.object(forKey: "settings.hotkeySelection"))
        XCTAssertNotNil(defaults.object(forKey: "settings.hotkeySelection.keyCode"))
        XCTAssertNotNil(defaults.object(forKey: "settings.hotkeySelection.modifiers"))
    }

    func testStoredHotkeyRejectsSentinelKeyCode() {
        defaults.set(-1, forKey: "settings.hotkeySelection.keyCode")
        defaults.set(0, forKey: "settings.hotkeySelection.modifiers")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertNil(settings.hotkeySelection)
    }

    func testStoredHotkeyLoadsUIntValues() {
        defaults.set(UInt(6), forKey: "settings.hotkeySelection.keyCode")
        defaults.set(UInt(NSEvent.ModifierFlags.control.rawValue), forKey: "settings.hotkeySelection.modifiers")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.hotkeySelection?.keyCode, 6)
        XCTAssertTrue(settings.hotkeySelection?.modifiers.contains(.control) ?? false)
    }

    func testInvalidSelectionDimmingColorFallsBackToDefault() {
        defaults.set("invalid", forKey: "settings.selectionDimmingColorHex")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(
            settings.selectionDimmingColorHex,
            ColorHexCodec.defaultSelectionDimmingColorHex,
        )
    }

    func testShutterSoundVolumeClampsToRange() {
        let settings = SettingsStore(defaults: defaults)
        settings.shutterSoundVolume = 1.5
        XCTAssertEqual(settings.shutterSoundVolume, 1.0)
        settings.shutterSoundVolume = -0.2
        XCTAssertEqual(settings.shutterSoundVolume, 0.0)
    }
}
