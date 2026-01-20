import CoreGraphics
@testable import OneShot
import XCTest

final class ScreenCaptureCoordinateConverterTests: XCTestCase {
    func testAdjustedRectUsesScreenOriginAndFlipsYAxis() {
        let screenFrame = CGRect(x: 100, y: 50, width: 800, height: 600)
        let rect = CGRect(x: 150, y: 100, width: 200, height: 300)

        let adjusted = ScreenCaptureCoordinateConverter.adjustedRect(for: rect, screenFrame: screenFrame)

        XCTAssertEqual(adjusted.origin.x, 50)
        XCTAssertEqual(adjusted.origin.y, 250)
        XCTAssertEqual(adjusted.size.width, 200)
        XCTAssertEqual(adjusted.size.height, 300)
    }
}
