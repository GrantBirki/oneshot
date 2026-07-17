import Carbon.HIToolbox
@testable import OneShot
import XCTest

final class HotkeyRegistrationTests: XCTestCase {
    func testConfigurationFindsDuplicateOutsideCurrentAction() throws {
        let duplicate = try XCTUnwrap(HotkeyParser.parse("control+g"))
        let configuration = HotkeyConfiguration(
            selection: duplicate,
            scrolling: nil,
            window: duplicate,
            fullScreen: nil,
        )

        XCTAssertEqual(
            configuration.duplicateAction(for: duplicate, excluding: .window),
            .selection,
        )
        XCTAssertNil(
            configuration.duplicateAction(
                for: Hotkey(keyCode: UInt16(kVK_ANSI_H), modifiers: [.control]),
                excluding: .window,
            ),
        )
    }

    func testRegistrationStatusMapsCarbonFailuresToUnavailable() {
        let alreadyExists = OSStatus(eventHotKeyExistsErr)
        XCTAssertEqual(
            HotkeyManager.status(forRegistrationResult: alreadyExists, hasReference: false),
            .unavailable(alreadyExists),
        )
        XCTAssertEqual(
            HotkeyManager.status(forRegistrationResult: noErr, hasReference: true),
            .registered,
        )
    }

    func testUnavailableStatusHasActionableMessage() {
        XCTAssertEqual(
            HotkeyRegistrationStatus.unavailable(OSStatus(eventHotKeyExistsErr)).message,
            "Couldn’t register; this shortcut is already in use.",
        )
    }
}
