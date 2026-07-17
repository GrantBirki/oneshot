@testable import OneShot
import XCTest

final class PreviewAutoDismissGateTests: XCTestCase {
    func testDeadlineReachedDismissesWhenNotInteracting() {
        var gate = PreviewAutoDismissGate()

        XCTAssertTrue(gate.deadlineReached())
        XCTAssertFalse(gate.pending)
    }

    func testDeadlineReachedDefersWhileHoveredThenDismissesOnHoverExit() {
        var gate = PreviewAutoDismissGate(isHovered: true)

        XCTAssertFalse(gate.deadlineReached())
        XCTAssertTrue(gate.pending)
        XCTAssertTrue(gate.interactionChanged(isHovered: false))
        XCTAssertFalse(gate.pending)
    }

    func testDeadlineReachedDefersWhileDraggingThenDismissesOnDragEnd() {
        var gate = PreviewAutoDismissGate(isDragging: true)

        XCTAssertFalse(gate.deadlineReached())
        XCTAssertTrue(gate.pending)
        XCTAssertTrue(gate.interactionChanged(isDragging: false))
        XCTAssertFalse(gate.pending)
    }
}
