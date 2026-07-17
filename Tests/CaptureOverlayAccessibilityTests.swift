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
            "Move the pointer over a window and click or press Return to capture it. Press Escape to cancel.",
        )
        XCTAssertEqual(view.accessibilityValue() as? String, "No window selected")
    }

    func testWindowInfoUsesOwnerAndTitleForAccessibility() {
        let info = WindowInfo(
            id: 42,
            bounds: CGRect(x: 10, y: 20, width: 100, height: 80),
            ownerName: "Example App",
            title: "Example Document",
        )

        XCTAssertEqual(info.accessibilityName, "Example App: Example Document")
    }

    func testWindowHitTestingPreservesFrontToBackOrder() {
        let front = WindowInfo(id: 1, bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        let back = WindowInfo(id: 2, bounds: CGRect(x: 0, y: 0, width: 200, height: 200))

        XCTAssertEqual(
            WindowInfoProvider.window(at: CGPoint(x: 50, y: 50), in: [front, back]),
            front,
        )
    }

    func testWindowOverlayUsesSnapshotUntilExplicitRefresh() {
        let initial = WindowInfo(
            id: 1,
            bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            ownerName: "Initial App",
        )
        let refreshed = WindowInfo(
            id: 2,
            bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            ownerName: "Refreshed App",
        )
        var refreshCount = 0
        let view = WindowCaptureOverlayView(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            windowInfos: [initial],
            refreshWindowInfos: {
                refreshCount += 1
                return [refreshed]
            },
        )

        view.updateHighlight(at: CGPoint(x: 50, y: 50))
        view.updateHighlight(at: CGPoint(x: 60, y: 60))
        XCTAssertEqual(refreshCount, 0)
        XCTAssertEqual(view.accessibilityValue() as? String, "Initial App")

        view.updateHighlight(at: CGPoint(x: 50, y: 50), refreshing: true)
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(view.accessibilityValue() as? String, "Refreshed App")
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

        let button = try XCTUnwrap(stopView.recursiveSubviews.compactMap { $0 as? NSButton }.first)
        XCTAssertEqual(button.frame, stopView.bounds)
        XCTAssertTrue(button.isBordered)
        XCTAssertEqual(button.bezelStyle, .glass)
        XCTAssertNotNil(stopView.layer?.shadowPath)
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
