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
    func testReplacementBlocksPreviewActionsUntilItCompletes() async throws {
        let replacementStarted = expectation(description: "Replacement started")
        let replacementGate = PreviewActionGate(started: replacementStarted)
        let controller = PreviewController()
        defer {
            replacementGate.resume()
            controller.hide()
        }
        var saveCount = 0
        let request = try makeRequest(
            onSave: { saveCount += 1 },
            onReplace: { await replacementGate.wait() },
        )
        let content = try await showPreview(request, using: controller)
        let replacement = Task { await controller.resolveForReplacement() }
        await fulfillment(of: [replacementStarted], timeout: 1)

        content.performSave()
        let actionCompleted = await controller.waitForCurrentAction(timeout: .milliseconds(20))
        XCTAssertFalse(actionCompleted)
        XCTAssertEqual(saveCount, 0)

        replacementGate.resume()
        let didReplace = await replacement.value
        XCTAssertTrue(didReplace)
        controller.hide()
    }

    @MainActor
    func testAutoDismissFiresWhenTimeoutIsZero() async throws {
        let didDismiss = expectation(description: "Auto-dismiss fires")
        let controller = PreviewController()
        defer { controller.hide() }
        let request = try makeRequest(timeout: 0, onAutoDismiss: { didDismiss.fulfill() })

        _ = try await showPreview(request, using: controller)
        await fulfillment(of: [didDismiss], timeout: 1)
        XCTAssertFalse(controller.hasActivePreview)
    }

    @MainActor
    func testAutoDismissWaitsForCopyActionThenRunsOnce() async throws {
        let deadlineStarted = expectation(description: "Preview deadline started")
        let deadlineReturned = expectation(description: "Preview deadline returned")
        let deadlineGate = PreviewActionGate(started: deadlineStarted)
        let copyStarted = expectation(description: "Copy started")
        let copyGate = PreviewActionGate(started: copyStarted)
        let didDismiss = expectation(description: "Auto-dismiss follows copy")
        var dismissalCount = 0
        let controller = PreviewController(sleeper: { _ in
            await deadlineGate.wait()
            deadlineReturned.fulfill()
        })
        defer {
            deadlineGate.resume()
            copyGate.resume()
            controller.hide()
        }
        let request = try makeRequest(
            timeout: 60,
            onCopy: { await copyGate.wait() },
            onAutoDismiss: {
                dismissalCount += 1
                didDismiss.fulfill()
            },
        )
        let content = try await showPreview(request, using: controller)
        await fulfillment(of: [deadlineStarted], timeout: 1)
        content.showRecovery(message: "The screenshot could not be saved.", onRetry: {})
        let copyButton = try XCTUnwrap(content.recursiveSubviews.compactMap { $0 as? NSButton }
            .first { $0.title == "Copy" })
        copyButton.performClick(nil)
        await fulfillment(of: [copyStarted], timeout: 1)

        deadlineGate.resume()
        await fulfillment(of: [deadlineReturned], timeout: 1)
        XCTAssertEqual(dismissalCount, 0)
        XCTAssertTrue(controller.hasActivePreview)

        copyGate.resume()
        await fulfillment(of: [didDismiss], timeout: 1)
        XCTAssertEqual(dismissalCount, 1)
        XCTAssertFalse(controller.hasActivePreview)
        controller.hide()
    }

    @MainActor
    func testAutoDismissRestartsGraceAfterHoverReturns() async throws {
        let deadlineStarted = expectation(description: "Preview deadline started")
        let deadlineReturned = expectation(description: "Preview deadline returned")
        let firstGraceStarted = expectation(description: "First grace period started")
        let secondGraceStarted = expectation(description: "Second grace period started")
        let didDismiss = expectation(description: "Auto-dismiss after second hover exit")
        let deadlineGate = PreviewActionGate(started: deadlineStarted)
        let firstGraceGate = PreviewActionGate(started: firstGraceStarted)
        let secondGraceGate = PreviewActionGate(started: secondGraceStarted)
        let graceSleeper = PreviewSleepSequence(gates: [firstGraceGate, secondGraceGate])
        let controller = PreviewController(sleeper: { duration in
            if duration == .seconds(60) {
                await deadlineGate.wait()
                deadlineReturned.fulfill()
            } else {
                await graceSleeper.wait()
            }
        })
        defer {
            deadlineGate.resume()
            firstGraceGate.resume()
            secondGraceGate.resume()
            controller.hide()
        }
        let request = try makeRequest(timeout: 60, onAutoDismiss: { didDismiss.fulfill() })
        let content = try await showPreview(request, using: controller)
        content.setActionsVisibleForTesting(true)
        await fulfillment(of: [deadlineStarted], timeout: 1)
        deadlineGate.resume()
        await fulfillment(of: [deadlineReturned], timeout: 1)

        content.setActionsVisibleForTesting(false)
        await fulfillment(of: [firstGraceStarted], timeout: 1)
        content.setActionsVisibleForTesting(true)
        content.setActionsVisibleForTesting(false)
        await fulfillment(of: [secondGraceStarted], timeout: 1)

        firstGraceGate.resume()
        secondGraceGate.resume()
        await fulfillment(of: [didDismiss], timeout: 1)
        XCTAssertFalse(controller.hasActivePreview)
        controller.hide()
    }

    @MainActor
    func testCancelledTerminationResumesPendingAutoDismiss() async throws {
        let deadlineStarted = expectation(description: "Preview deadline started")
        let deadlineReturned = expectation(description: "Preview deadline returned")
        let graceStarted = expectation(description: "Dismissal resumes after cancelled quit")
        let didDismiss = expectation(description: "Pending auto-dismiss completes")
        let deadlineGate = PreviewActionGate(started: deadlineStarted)
        let graceGate = PreviewActionGate(started: graceStarted)
        let controller = PreviewController(sleeper: { duration in
            if duration == .seconds(60) {
                await deadlineGate.wait()
                deadlineReturned.fulfill()
            } else {
                await graceGate.wait()
            }
        })
        defer {
            deadlineGate.resume()
            graceGate.resume()
            controller.hide()
        }
        let request = try makeRequest(timeout: 60, onAutoDismiss: { didDismiss.fulfill() })
        _ = try await showPreview(request, using: controller)
        await fulfillment(of: [deadlineStarted], timeout: 1)
        controller.beginTermination()
        deadlineGate.resume()
        await fulfillment(of: [deadlineReturned], timeout: 1)
        XCTAssertTrue(controller.hasActivePreview)

        controller.cancelTermination()
        await fulfillment(of: [graceStarted], timeout: 1)
        graceGate.resume()
        await fulfillment(of: [didDismiss], timeout: 1)
        XCTAssertFalse(controller.hasActivePreview)
    }

    @MainActor
    func testFailedActionKeepsRecoveryOpenAfterDeadline() async throws {
        let deadlineStarted = expectation(description: "Preview deadline started")
        let deadlineReturned = expectation(description: "Preview deadline returned")
        let saveStarted = expectation(description: "Save started")
        let deadlineGate = PreviewActionGate(started: deadlineStarted)
        let saveGate = PreviewActionGate(started: saveStarted)
        var dismissalCount = 0
        let controller = PreviewController(sleeper: { _ in
            await deadlineGate.wait()
            deadlineReturned.fulfill()
        })
        defer {
            deadlineGate.resume()
            saveGate.resume()
            controller.hide()
        }
        let request = try makeRequest(
            timeout: 60,
            onSave: {
                await saveGate.wait()
                throw TestError.failed
            },
            onAutoDismiss: { dismissalCount += 1 },
        )
        let content = try await showPreview(request, using: controller)
        await fulfillment(of: [deadlineStarted], timeout: 1)
        content.performSave()
        await fulfillment(of: [saveStarted], timeout: 1)
        deadlineGate.resume()
        await fulfillment(of: [deadlineReturned], timeout: 1)

        saveGate.resume()
        let completed = await controller.waitForCurrentAction(timeout: .seconds(1))
        XCTAssertTrue(completed)
        XCTAssertTrue(controller.hasActivePreview)
        XCTAssertEqual(dismissalCount, 0)
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
}

private extension PreviewControllerTests {
    @MainActor
    func makeRequest(
        timeout: TimeInterval? = nil,
        onSave: @escaping PreviewRequest.Action = {},
        onCopy: @escaping PreviewRequest.Action = {},
        onReplace: @escaping PreviewRequest.Action = {},
        onAutoDismiss: PreviewRequest.Action? = nil,
    ) throws -> PreviewRequest {
        _ = NSApplication.shared
        let cgImage = makeBitmapRep(width: 1, height: 1).cgImage!
        return try PreviewRequest(
            image: NSImage(cgImage: cgImage, size: NSSize(width: 1, height: 1)),
            pngData: PNGDataEncoder.encode(cgImage: cgImage),
            filenamePrefix: "screenshot",
            timeout: timeout,
            onSave: onSave,
            onDiscard: {},
            onOpen: {},
            onSaveAs: {},
            onCopy: onCopy,
            onReveal: {},
            onDismissSaved: {},
            onReplace: onReplace,
            onAutoDismiss: onAutoDismiss,
            anchorRect: nil,
        )
    }

    @MainActor
    func showPreview(
        _ request: PreviewRequest,
        using controller: PreviewController,
    ) async throws -> PreviewContentView {
        let previousWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let didShow = await controller.show(request)
        XCTAssertTrue(didShow)
        let content = try XCTUnwrap(NSApp.windows.compactMap { window in
            previousWindows.contains(ObjectIdentifier(window)) ? nil : window.contentView as? PreviewContentView
        }.first)
        content.window?.makeFirstResponder(nil)
        content.setActionsVisibleForTesting(false)
        return content
    }

    func makeBitmapRep(width: Int, height: Int) -> NSBitmapImageRep {
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

private extension NSView {
    var recursiveSubviews: [NSView] {
        subviews + subviews.flatMap(\.recursiveSubviews)
    }
}

@MainActor
private final class PreviewActionGate {
    private let started: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?

    init(started: XCTestExpectation) {
        self.started = started
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class PreviewSleepSequence {
    private let gates: [PreviewActionGate]
    private var index = 0

    init(gates: [PreviewActionGate]) {
        self.gates = gates
    }

    func wait() async {
        guard index < gates.count else { return }
        let gate = gates[index]
        index += 1
        await gate.wait()
    }
}
