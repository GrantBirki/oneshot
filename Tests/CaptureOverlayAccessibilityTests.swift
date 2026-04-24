import AppKit
@testable import OneShot
import XCTest

@MainActor
final class CaptureOverlayAccessibilityTests: XCTestCase {
    func testSelectionOverlayExposesAccessibleInstructionsAndSelectionSize() {
        let state = SelectionOverlayState(
            showSelectionCoordinates: true,
            dimmingMode: .fullScreen,
            selectionDimmingColor: .systemBlue,
        )
        let view = SelectionOverlayView(frame: NSRect(x: 0, y: 0, width: 320, height: 180), state: state)

        XCTAssertEqual(view.accessibilityRole(), .group)
        XCTAssertEqual(view.accessibilityLabel(), "Screenshot selection area")
        XCTAssertEqual(view.accessibilityHelp(), "Drag to select an area. Press Escape to cancel.")
        XCTAssertEqual(view.accessibilityValue() as? String, "No selection")

        state.start = CGPoint(x: 10, y: 10)
        state.current = CGPoint(x: 110, y: 60)
        view.updateOverlay()

        XCTAssertEqual(view.accessibilityValue() as? String, "100 x 50")
    }

    func testWindowCaptureOverlayExposesAccessibleInstructions() {
        let view = WindowCaptureOverlayView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))

        XCTAssertEqual(view.accessibilityRole(), .group)
        XCTAssertEqual(view.accessibilityLabel(), "Window capture overlay")
        XCTAssertEqual(
            view.accessibilityHelp(),
            "Move the pointer over a window and click to capture it. Press Escape to cancel.",
        )
        XCTAssertEqual(view.accessibilityValue() as? String, "No window selected")
    }

    func testScrollingOverlayExposesAccessibleRegionAndStopControl() throws {
        let region = ScrollingSelectionOverlayView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 180),
            selectionRect: CGRect(x: 10, y: 20, width: 123.4, height: 56.7),
        )

        XCTAssertEqual(region.accessibilityRole(), .group)
        XCTAssertEqual(region.accessibilityLabel(), "Scrolling capture region")
        XCTAssertEqual(
            region.accessibilityHelp(),
            "This region is being captured while you scroll. Use Stop Scrolling Capture to finish.",
        )
        XCTAssertEqual(region.accessibilityValue() as? String, "123 by 57")

        var didStop = false
        let stopView = StopCaptureButtonView {
            didStop = true
        }
        stopView.frame = NSRect(x: 0, y: 0, width: 112, height: 44)
        stopView.layout()

        let glassView = try XCTUnwrap(stopView.recursiveSubviews.compactMap { $0 as? NSGlassEffectView }.first)
        XCTAssertEqual(glassView.frame, stopView.bounds)
        XCTAssertEqual(glassView.cornerRadius, stopView.bounds.height / 2, accuracy: 0.5)
        XCTAssertNotNil(stopView.layer?.shadowPath)

        let button = try XCTUnwrap(stopView.recursiveSubviews.compactMap { $0 as? NSButton }.first)
        XCTAssertEqual(button.accessibilityLabel(), "Stop scrolling capture")
        XCTAssertEqual(button.accessibilityHelp(), "Finish scrolling capture and create the stitched screenshot.")

        button.performClick(nil)

        XCTAssertTrue(didStop)
    }
}

private extension NSView {
    var recursiveSubviews: [NSView] {
        subviews + subviews.flatMap(\.recursiveSubviews)
    }
}
