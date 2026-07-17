import AppKit
import Carbon.HIToolbox
@testable import OneShot
import XCTest

@MainActor
final class HotkeyRecorderViewTests: XCTestCase {
    func testBecomeFirstResponderDoesNotStartRecording() {
        let view = HotkeyRecorderView()
        let hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_D), modifiers: [.control])
        view.hotkey = hotkey

        XCTAssertTrue(view.becomeFirstResponder())

        XCTAssertFalse(view.isRecordingForTesting)
        XCTAssertEqual(view.accessibilityValue() as? String, hotkey.displayString)
    }

    func testSpaceStartsRecordingForKeyboardActivation() {
        let view = HotkeyRecorderView()

        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Space), characters: " "))

        XCTAssertTrue(view.isRecordingForTesting)
        XCTAssertEqual(view.accessibilityValue() as? String, "Type shortcut...")
    }

    func testAccessibilityPressStartsRecording() {
        let view = HotkeyRecorderView()

        XCTAssertEqual(view.accessibilityRole(), .button)
        XCTAssertTrue(view.accessibilityPerformPress())
        XCTAssertTrue(view.isRecordingForTesting)
        XCTAssertEqual(view.accessibilityValue() as? String, "Type shortcut...")
    }

    func testClearButtonHasSpecificAccessibilityCopy() throws {
        let view = HotkeyRecorderView(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        view.hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_D), modifiers: [.control])
        view.layout()

        let clearButton = try XCTUnwrap(view.recursiveSubviews.compactMap { $0 as? NSButton }.first)

        XCTAssertFalse(clearButton.isHidden)
        XCTAssertEqual(clearButton.accessibilityLabel(), "Clear hotkey")
        XCTAssertEqual(clearButton.accessibilityHelp(), "Remove this hotkey.")
    }

    func testEscapeCancelsRecordingAndRestoresInitialHotkey() {
        let view = HotkeyRecorderView()
        let hotkey = Hotkey(keyCode: UInt16(kVK_ANSI_D), modifiers: [.control])
        view.hotkey = hotkey
        var changes: [Hotkey?] = []
        view.onChange = { changes.append($0) }

        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Space), characters: " "))
        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Escape), characters: ""))

        XCTAssertFalse(view.isRecordingForTesting)
        XCTAssertEqual(view.hotkey, hotkey)
        XCTAssertEqual(view.accessibilityValue() as? String, hotkey.displayString)
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
        XCTAssertEqual(view.accessibilityValue() as? String, expected.displayString)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0], expected)
    }

    func testRecordingRejectsUnmodifiedShortcut() {
        let view = HotkeyRecorderView()
        var changes: [Hotkey?] = []
        view.onChange = { changes.append($0) }

        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_Space), characters: " "))
        view.keyDown(with: makeKeyEvent(keyCode: UInt16(kVK_ANSI_G), characters: "g"))

        XCTAssertTrue(view.isRecordingForTesting)
        XCTAssertNil(view.hotkey)
        XCTAssertTrue(changes.isEmpty)
        XCTAssertEqual(view.accessibilityValue() as? String, "Type shortcut...")
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

private extension NSView {
    var recursiveSubviews: [NSView] {
        subviews + subviews.flatMap(\.recursiveSubviews)
    }
}
