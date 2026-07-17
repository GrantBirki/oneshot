import AppKit
@testable import OneShot
import XCTest

final class PreviewControllerTests: XCTestCase {
    @MainActor
    func testShowResolvesExistingPreviewBeforeReplacingIt() async throws {
        let controller = PreviewController()
        var replaceCount = 0
        let first = try makeRequest(onReplace: { replaceCount += 1 })
        let second = try makeRequest()

        let didShowFirst = await controller.show(first)
        let didShowSecond = await controller.show(second)
        XCTAssertTrue(didShowFirst)
        XCTAssertTrue(didShowSecond)

        XCTAssertEqual(replaceCount, 1)
        controller.hide()
    }

    @MainActor
    func testFailedReplacementKeepsCurrentPreview() async throws {
        let controller = PreviewController()
        let first = try makeRequest(onReplace: { throw TestError.failed })
        let second = try makeRequest()

        let didShowFirst = await controller.show(first)
        let didShowSecond = await controller.show(second)
        XCTAssertTrue(didShowFirst)
        XCTAssertFalse(didShowSecond)
        XCTAssertTrue(controller.hasActivePreview)
        controller.hide()
    }

    @MainActor
    func testAutoDismissFiresWhenTimeoutIsZero() async throws {
        let didDismiss = expectation(description: "Auto-dismiss fires")
        let controller = PreviewController()
        let request = try makeRequest(timeout: 0, onAutoDismiss: { didDismiss.fulfill() })

        let didShow = await controller.show(request)
        XCTAssertTrue(didShow)
        await fulfillment(of: [didDismiss], timeout: 1)
        XCTAssertFalse(controller.hasActivePreview)
    }

    @MainActor
    func testPointBasedSizingPreservesAspectWithinEnvelope() {
        let wide = PreviewPanel.preferredSize(
            imageSize: NSSize(width: 2000, height: 500),
            minimumSize: NSSize(width: 160, height: 120),
            maximumSize: NSSize(width: 300, height: 250),
        )
        let portrait = PreviewPanel.preferredSize(
            imageSize: NSSize(width: 500, height: 2000),
            minimumSize: NSSize(width: 160, height: 120),
            maximumSize: NSSize(width: 300, height: 250),
        )

        XCTAssertEqual(wide.width, 300)
        XCTAssertEqual(wide.height, 120)
        XCTAssertEqual(portrait.width, 160)
        XCTAssertEqual(portrait.height, 250)
    }

    @MainActor
    private func makeRequest(
        timeout: TimeInterval? = nil,
        onReplace: @escaping PreviewRequest.Action = {},
        onAutoDismiss: PreviewRequest.Action? = nil,
    ) throws -> PreviewRequest {
        let cgImage = makeBitmapRep(width: 1, height: 1).cgImage!
        return try PreviewRequest(
            image: NSImage(cgImage: cgImage, size: NSSize(width: 1, height: 1)),
            pngData: PNGDataEncoder.encode(cgImage: cgImage),
            filenamePrefix: "screenshot",
            timeout: timeout,
            onSave: {},
            onDiscard: {},
            onOpen: {},
            onSaveAs: {},
            onCopy: {},
            onReveal: {},
            onDismissSaved: {},
            onReplace: onReplace,
            onAutoDismiss: onAutoDismiss,
            anchorRect: nil,
        )
    }

    private func makeBitmapRep(width: Int, height: Int) -> NSBitmapImageRep {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0,
        )!
    }
}

private enum TestError: Error {
    case failed
}
