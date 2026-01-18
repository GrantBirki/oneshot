import CoreGraphics
@testable import OneShot
import XCTest

final class CursorVisibilityStackTests: XCTestCase {
    func testHideOnlyHappensOnce() {
        var hideCalls: [[CGDirectDisplayID]] = []
        let stack = CursorVisibilityStack(
            displayProvider: { [1, 2] },
            hideHandler: { hideCalls.append($0) },
            showHandler: { _ in },
        )

        stack.hide()
        stack.hide()

        XCTAssertEqual(hideCalls.count, 1)
        XCTAssertEqual(hideCalls.first ?? [], [1, 2])
    }

    func testShowOnlyAfterMatchingHide() {
        var showCalls: [[CGDirectDisplayID]] = []
        let stack = CursorVisibilityStack(
            displayProvider: { [7] },
            hideHandler: { _ in },
            showHandler: { showCalls.append($0) },
        )

        stack.hide()
        stack.hide()
        stack.show()

        XCTAssertTrue(showCalls.isEmpty)

        stack.show()

        XCTAssertEqual(showCalls, [[7]])
    }

    func testShowWithoutHideDoesNothing() {
        var showCalls: [[CGDirectDisplayID]] = []
        let stack = CursorVisibilityStack(
            displayProvider: { [3] },
            hideHandler: { _ in },
            showHandler: { showCalls.append($0) },
        )

        stack.show()

        XCTAssertTrue(showCalls.isEmpty)
    }
}
