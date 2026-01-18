import AppKit
@testable import OneShot
import XCTest

final class OverlayWindowTests: XCTestCase {
    func testOverlayWindowUsesNonActivatingPanelConfig() {
        let window = OverlayWindow(contentRect: CGRect(x: 0, y: 0, width: 10, height: 10))

        XCTAssertTrue(window.styleMask.contains(.borderless))
        XCTAssertTrue(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(window.isFloatingPanel)
        XCTAssertEqual(window.level, .screenSaver)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
        XCTAssertFalse(window.hasShadow)
        XCTAssertFalse(window.ignoresMouseEvents)
        XCTAssertTrue(window.acceptsMouseMovedEvents)
        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
        XCTAssertTrue(window.becomesKeyOnlyIfNeeded)
    }
}
