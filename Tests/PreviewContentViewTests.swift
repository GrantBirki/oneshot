import AppKit
@testable import OneShot
import XCTest

final class PreviewContentViewTests: XCTestCase {
    func testLayoutUsesFullWidthImageAndHalfWidthButtons() {
        let view = PreviewContentView(frame: NSRect(x: 0, y: 0, width: 200, height: 120))
        view.layout()

        guard let backgroundView = view.subviews.first(where: { $0 is NSVisualEffectView }) as? NSVisualEffectView else {
            XCTFail("Missing background view")
            return
        }

        guard let imageView = backgroundView.subviews.compactMap({ $0 as? PreviewImageView }).first else {
            XCTFail("Missing preview image view")
            return
        }

        let buttons = backgroundView.subviews.compactMap { $0 as? NSButton }
        guard let closeButton = buttons.first(where: { $0.identifier?.rawValue == "preview-close" }) else {
            XCTFail("Missing close button")
            return
        }
        guard let trashButton = buttons.first(where: { $0.identifier?.rawValue == "preview-trash" }) else {
            XCTFail("Missing trash button")
            return
        }

        XCTAssertEqual(imageView.frame.origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(imageView.frame.origin.y, 0, accuracy: 0.5)
        XCTAssertEqual(imageView.frame.width, view.bounds.width, accuracy: 0.5)
        XCTAssertEqual(imageView.frame.maxY, closeButton.frame.minY, accuracy: 0.5)

        XCTAssertEqual(closeButton.frame.minX, 0, accuracy: 0.5)
        XCTAssertEqual(closeButton.frame.maxX, trashButton.frame.minX, accuracy: 0.5)
        XCTAssertEqual(trashButton.frame.maxX, view.bounds.width, accuracy: 0.5)
        XCTAssertEqual(closeButton.frame.width, trashButton.frame.width, accuracy: 0.5)
        XCTAssertEqual(closeButton.frame.maxY, view.bounds.height, accuracy: 0.5)
        XCTAssertEqual(trashButton.frame.maxY, view.bounds.height, accuracy: 0.5)
    }
}
