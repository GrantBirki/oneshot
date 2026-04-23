import AppKit
import Carbon.HIToolbox
@testable import OneShot
import XCTest

@MainActor
final class HotkeyRecorderViewTests: XCTestCase {
    func testBecomeFirstResponderDoesNotStartRecording() {
        let view = HotkeyRecorderView()
        view.hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_D), modifiers: [.control])

        XCTAssertTrue(view.becomeFirstResponder())

        XCTAssertFalse(view.isRecordingForTesting)
        XCTAssertEqual(view.accessibilityValue() as? String, "⌃D")
    }

    func testSpaceStartsRecordingForKeyboardActivation() {
        let view = HotkeyRecorderView()

        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Space), characters: " "))

        XCTAssertTrue(view.isRecordingForTesting)
        XCTAssertEqual(view.accessibilityValue() as? String, "Type shortcut...")
    }

    func testEscapeCancelsRecordingAndRestoresInitialHotkey() {
        let view = HotkeyRecorderView()
        view.hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_D), modifiers: [.control])
        var changes: [Hotkey?] = []
        view.onChange = { changes.append($0) }

        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Space), characters: " "))
        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Escape), characters: ""))

        XCTAssertFalse(view.isRecordingForTesting)
        XCTAssertEqual(view.hotkey, Hotkey(keyCode: UInt16(kVK_ANSI_D), modifiers: [.control]))
        XCTAssertEqual(view.accessibilityValue() as? String, "⌃D")
        XCTAssertTrue(changes.isEmpty)
    }

    func testDeleteClearsHotkeyWhileRecording() {
        let view = HotkeyRecorderView()
        view.hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_D), modifiers: [.control])
        var changes: [Hotkey?] = []
        view.onChange = { changes.append($0) }

        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Space), characters: " "))
        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Delete), characters: ""))

        XCTAssertFalse(view.isRecordingForTesting)
        XCTAssertNil(view.hotkey)
        XCTAssertEqual(view.accessibilityValue() as? String, "None")
        XCTAssertEqual(changes.count, 1)
        XCTAssertNil(changes[0])
    }

    func testRecordingCommitsModifierShortcut() {
        let view = HotkeyRecorderView()
        var changes: [Hotkey?] = []
        view.onChange = { changes.append($0) }

        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Space), characters: " "))
        view.keyDown(
            with: makeKeyEvent(
                keyCode: UInt16(kVK_ANSI_G),
                characters: "g",
                modifierFlags: [.control],
            ),
        )

        let expected = Hotkey(keyCode: UInt16(kVK_ANSI_G), modifiers: [.control])
        XCTAssertFalse(view.isRecordingForTesting)
        XCTAssertEqual(view.hotkey, expected)
        XCTAssertEqual(view.accessibilityValue() as? String, "⌃G")
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0], expected)
    }

    func testPerformKeyEquivalentCommitsCommandShortcutWhileRecording() {
        let view = HotkeyRecorderView()
        var changes: [Hotkey?] = []
        view.onChange = { changes.append($0) }

        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Space), characters: " "))
        let handled = view.performKeyEquivalent(
            with: makeKeyEvent(
                keyCode: UInt16(kVK_ANSI_S),
                characters: "s",
                modifierFlags: [.command, .shift],
            ),
        )

        let expected = Hotkey(keyCode: UInt16(kVK_ANSI_S), modifiers: [.command, .shift])
        XCTAssertTrue(handled)
        XCTAssertFalse(view.isRecordingForTesting)
        XCTAssertEqual(view.hotkey, expected)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0], expected)
    }

    private func makeKeyEvent(
        keyCode: UInt16,
        characters: String,
        modifierFlags: NSEvent.ModifierFlags = [],
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode,
        )!
    }
}
