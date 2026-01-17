import CoreGraphics
@testable import OneShot
import XCTest

final class OverlayPathBuilderTests: XCTestCase {
    func testInnerDimmingPathNilWithoutRect() {
        XCTAssertNil(OverlayPathBuilder.innerDimmingPath(for: nil))
    }

    func testInnerDimmingPathCoversRect() {
        let rect = CGRect(x: 25, y: 25, width: 50, height: 50)
        let path = OverlayPathBuilder.innerDimmingPath(for: rect)

        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains(CGPoint(x: 30, y: 30), using: .winding, transform: .identity) ?? false)
        XCTAssertFalse(path?.contains(CGPoint(x: 10, y: 10), using: .winding, transform: .identity) ?? true)
    }
}
