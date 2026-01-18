import CoreGraphics
@testable import OneShot
import XCTest

final class OverlayPathBuilderTests: XCTestCase {
    func testInverseDimmingPathNilWithoutSelection() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertNil(OverlayPathBuilder.dimmingPath(for: nil, in: bounds, mode: .selectionOnly))
    }

    func testInverseDimmingPathCoversSelection() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect = CGRect(x: 25, y: 25, width: 50, height: 50)
        let path = OverlayPathBuilder.dimmingPath(for: rect, in: bounds, mode: .selectionOnly)

        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains(CGPoint(x: 30, y: 30), using: .winding, transform: .identity) ?? false)
        XCTAssertFalse(path?.contains(CGPoint(x: 10, y: 10), using: .winding, transform: .identity) ?? true)
    }

    func testMacOSLikeDimmingPathCoversBoundsWithoutSelection() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = OverlayPathBuilder.dimmingPath(for: nil, in: bounds, mode: .fullScreen)

        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains(CGPoint(x: 50, y: 50), using: .winding, transform: .identity) ?? false)
        XCTAssertFalse(path?.contains(CGPoint(x: 150, y: 150), using: .winding, transform: .identity) ?? true)
    }

    func testMacOSLikeDimmingPathCreatesHoleForSelection() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let selection = CGRect(x: 25, y: 25, width: 50, height: 50)
        let path = OverlayPathBuilder.dimmingPath(for: selection, in: bounds, mode: .fullScreen)

        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains(CGPoint(x: 10, y: 10), using: .evenOdd, transform: .identity) ?? false)
        XCTAssertFalse(path?.contains(CGPoint(x: 50, y: 50), using: .evenOdd, transform: .identity) ?? true)
    }
}
