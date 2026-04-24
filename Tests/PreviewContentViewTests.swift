import AppKit
@testable import OneShot
import XCTest

@MainActor
final class PreviewContentViewTests: XCTestCase {
    func testLayoutUsesFullSizeImageWithOverlayButtons() throws {
        let sut = try makeSUT()

        XCTAssertEqual(sut.imageView.frame, sut.backgroundView.bounds)
        XCTAssertEqual(sut.containerView.frame, sut.view.bounds)
        XCTAssertEqual(sut.overlayView.frame, sut.containerView.bounds)
        XCTAssertTrue(sut.overlayView.isHidden)
        XCTAssertTrue(sut.backgroundView.frame.minX > sut.view.bounds.minX)
        XCTAssertTrue(sut.backgroundView.frame.minY > sut.view.bounds.minY)
        XCTAssertTrue(sut.backgroundView.frame.maxX < sut.view.bounds.maxX)
        XCTAssertTrue(sut.backgroundView.frame.maxY < sut.view.bounds.maxY)

        XCTAssertFalse(sut.closeButton.isHidden)
        XCTAssertFalse(sut.trashButton.isHidden)
        XCTAssertEqual(sut.closeButton.frame.width, sut.closeButton.frame.height, accuracy: 0.5)
        XCTAssertEqual(sut.closeButton.frame.width, sut.trashButton.frame.width, accuracy: 0.5)
        XCTAssertEqual(sut.closeGlassView.frame.minY, sut.trashGlassView.frame.minY, accuracy: 0.5)
        XCTAssertEqual(sut.closeGlassView.frame.minX, sut.view.bounds.minX, accuracy: 0.5)
        XCTAssertEqual(sut.trashGlassView.frame.maxX, sut.view.bounds.maxX, accuracy: 0.5)
        XCTAssertEqual(sut.closeGlassView.frame.maxY, sut.view.bounds.maxY, accuracy: 0.5)
        XCTAssertTrue(sut.closeGlassView.frame.minX < sut.backgroundView.frame.minX)
        XCTAssertTrue(sut.trashGlassView.frame.maxX > sut.backgroundView.frame.maxX)
        XCTAssertTrue(sut.closeGlassView.frame.maxY > sut.backgroundView.frame.maxY)
    }

    func testHitTestPrefersButtonsOverImage() throws {
        let sut = try makeSUT()
        sut.view.setActionsVisibleForTesting(true)
        sut.view.layout()

        let closeFrame = sut.closeButton.convert(sut.closeButton.bounds, to: sut.view)
        let closePoint = NSPoint(x: closeFrame.midX, y: closeFrame.midY)
        let hitClose = sut.view.hitTest(closePoint)
        XCTAssertEqual(hitClose?.identifier?.rawValue, "preview-close")

        let trashFrame = sut.trashButton.convert(sut.trashButton.bounds, to: sut.view)
        let trashPoint = NSPoint(x: trashFrame.midX, y: trashFrame.midY)
        let hitTrash = sut.view.hitTest(trashPoint)
        XCTAssertEqual(hitTrash?.identifier?.rawValue, "preview-trash")

        let imageFrame = sut.imageView.convert(sut.imageView.bounds, to: sut.view)
        let imagePoint = NSPoint(x: imageFrame.midX, y: imageFrame.midY)
        let hitImage = sut.view.hitTest(imagePoint)
        XCTAssertTrue(hitImage is PreviewImageView)
    }

    func testActionButtonsKeepStableScaleWhenPreviewActionsHide() throws {
        let sut = try makeSUT()

        sut.view.setActionsVisibleForTesting(true)
        sut.view.setActionsVisibleForTesting(false)

        XCTAssertEqual(sut.closeButton.layer?.transform.m11 ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(sut.trashButton.layer?.transform.m11 ?? 0, 1, accuracy: 0.001)
    }

    func testTrashActionUsesRedSymbolTint() throws {
        let sut = try makeSUT()

        XCTAssertEqual(sut.trashButton.contentTintColor, .systemRed)
    }

    func testPreviewSurfaceUsesClearGlassWithRegularActionGlass() throws {
        let sut = try makeSUT()

        XCTAssertEqual(sut.backgroundView.style, .clear)
        XCTAssertEqual(sut.closeGlassView.style, .regular)
        XCTAssertEqual(sut.trashGlassView.style, .regular)
    }

    func testPreviewImageIsAccessibleAndPerformPressOpensScreenshot() throws {
        let sut = try makeSUT()
        var didOpen = false
        sut.imageView.onOpen = {
            didOpen = true
        }

        XCTAssertEqual(sut.imageView.accessibilityRole(), .button)
        XCTAssertEqual(sut.imageView.accessibilityLabel(), "Screenshot preview")
        XCTAssertEqual(sut.imageView.accessibilityHelp(), "Open the screenshot, or drag it to another app.")

        XCTAssertTrue(sut.imageView.accessibilityPerformPress())
        XCTAssertTrue(didOpen)
    }

    private func makeSUT() throws -> PreviewContentSUT {
        let view = PreviewContentView(frame: NSRect(x: 0, y: 0, width: 200, height: 120))
        view.layout()

        let backgroundView = try XCTUnwrap(
            view.subviews.first { $0 is NSGlassEffectView } as? NSGlassEffectView,
        )
        let imageView = try XCTUnwrap(backgroundView.contentView as? PreviewImageView)
        let containerView = try XCTUnwrap(
            view.subviews.first { $0 is NSGlassEffectContainerView } as? NSGlassEffectContainerView,
        )
        let overlayView = try XCTUnwrap(containerView.contentView as? PreviewActionOverlayView)
        let buttons = overlayView.recursiveSubviews.compactMap { $0 as? NSButton }
        let closeButton = try XCTUnwrap(buttons.first { $0.identifier?.rawValue == "preview-close" })
        let trashButton = try XCTUnwrap(buttons.first { $0.identifier?.rawValue == "preview-trash" })
        let actionGlassViews = overlayView.subviews.compactMap { $0 as? NSGlassEffectView }
        let closeGlassView = try XCTUnwrap(actionGlassViews.min { $0.frame.minX < $1.frame.minX })
        let trashGlassView = try XCTUnwrap(actionGlassViews.max { $0.frame.maxX < $1.frame.maxX })

        XCTAssertEqual(actionGlassViews.count, 2)
        return PreviewContentSUT(
            view: view,
            backgroundView: backgroundView,
            imageView: imageView,
            containerView: containerView,
            overlayView: overlayView,
            closeButton: closeButton,
            trashButton: trashButton,
            closeGlassView: closeGlassView,
            trashGlassView: trashGlassView,
        )
    }
}

private struct PreviewContentSUT {
    let view: PreviewContentView
    let backgroundView: NSGlassEffectView
    let imageView: PreviewImageView
    let containerView: NSGlassEffectContainerView
    let overlayView: PreviewActionOverlayView
    let closeButton: NSButton
    let trashButton: NSButton
    let closeGlassView: NSGlassEffectView
    let trashGlassView: NSGlassEffectView
}

private extension NSView {
    var recursiveSubviews: [NSView] {
        subviews + subviews.flatMap(\.recursiveSubviews)
    }
}
