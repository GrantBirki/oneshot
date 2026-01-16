import CoreGraphics
@testable import OneShot
import XCTest

final class SelectionOverlayStateTests: XCTestCase {
    func testSelectionSizeTextRoundsAndFormats() {
        let state = SelectionOverlayState()
        state.start = CGPoint(x: 10.2, y: 20.6)
        state.current = CGPoint(x: 30.6, y: 50.2)

        XCTAssertEqual(state.selectionSizeText, "20 x 30")
    }

    func testSelectionSizeTextHandlesReverseDrag() {
        let state = SelectionOverlayState()
        state.start = CGPoint(x: 80, y: 120)
        state.current = CGPoint(x: 30, y: 50)

        XCTAssertEqual(state.selectionSizeText, "50 x 70")
    }

    func testSelectionSizeTextNilWithoutPoints() {
        let state = SelectionOverlayState()

        XCTAssertNil(state.selectionSizeText)
        state.start = CGPoint(x: 10, y: 10)
        XCTAssertNil(state.selectionSizeText)
        state.start = nil
        state.current = CGPoint(x: 10, y: 10)
        XCTAssertNil(state.selectionSizeText)
    }
}
