import Carbon.HIToolbox
@testable import OneShot
import XCTest

@MainActor
final class HotkeySettingsPaneTests: XCTestCase {
    func testConflictMessageDetectsDuplicateOneShotShortcut() {
        let pane = makePane()
        let hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_A), modifiers: [.control])

        let message = pane.conflictMessage(for: hotkey, against: [nil, hotkey])

        XCTAssertEqual(message, "This shortcut is already used by OneShot.")
    }

    func testConflictMessageDetectsReservedSystemShortcut() {
        let pane = makePane()
        let hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_4), modifiers: [.command, .shift])

        let message = pane.conflictMessage(for: hotkey, against: [])

        XCTAssertEqual(message, "This shortcut may conflict with system shortcuts.")
    }

    func testConflictMessageIgnoresNilAndInvalidShortcuts() {
        let pane = makePane()
        let invalid = Hotkey(keyCode: UInt16.max, modifiers: [.control])

        XCTAssertNil(pane.conflictMessage(for: nil, against: []))
        XCTAssertNil(pane.conflictMessage(for: invalid, against: [nil]))
    }

    func testConflictMessageAllowsUniqueShortcut() {
        let pane = makePane()
        let hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_A), modifiers: [.control])
        let other = Hotkey(keyCode: UInt16(kVK_ANSI_B), modifiers: [.control])

        XCTAssertNil(pane.conflictMessage(for: hotkey, against: [nil, other]))
    }

    private func makePane() -> HotkeySettingsPane {
        HotkeySettingsPane(settings: SettingsStore(defaults: .standard))
    }
}
