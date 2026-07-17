import AppKit
import ScreenCaptureKit

struct ScrollingCaptureContext: @unchecked Sendable {
    let filter: SCContentFilter
    let configuration: SCStreamConfiguration
}

enum ScreenCaptureService {
    private struct ScreenCaptureTarget {
        let frame: CGRect
        let displayID: CGDirectDisplayID
        let captureRect: CGRect
    }

    static func captureFullScreen() async -> CGImage? {
        guard let frame = await MainActor.run(body: { ScreenFrameHelper.allScreensFrame() }) else { return nil }
        return await capture(rect: frame, excludingWindowIDs: [])
    }

    static func capture(rect: CGRect, excludingWindowID: CGWindowID? = nil) async -> CGImage? {
        await capture(rect: rect, excludingWindowIDs: excludingWindowID.map { [$0] } ?? [])
    }

    static func capture(rect: CGRect, excludingWindowIDs: Set<CGWindowID>) async -> CGImage? {
        guard !rect.isNull, !rect.isEmpty else { return nil }

        let targets = await screenTargets(intersecting: rect)
        guard !targets.isEmpty else { return nil }

        guard let content = await shareableContent() else { return nil }
        let displaysByID = scDisplaysByID(in: content)
        guard !displaysByID.isEmpty else { return nil }

        let excludedWindows = scWindows(for: excludingWindowIDs, in: content)

        var pieces: [CapturedPiece] = []

        for target in targets {
            guard let display = displaysByID[target.displayID] else { continue }
            if let piece = await captureDisplay(
                display: display,
                screenFrame: target.frame,
                captureRect: target.captureRect,
                excludedWindows: excludedWindows,
            ) {
                pieces.append(piece)
            }
        }

        guard pieces.count == targets.count else { return nil }
        if pieces.count == 1 {
            return pieces[0].image
        }

        return CaptureCompositor.composite(pieces)
    }

    static func capture(windowID: CGWindowID) async -> CGImage? {
        guard let content = await shareableContent(),
              let window = scWindow(for: windowID, in: content)
        else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = max(CGFloat(filter.pointPixelScale), 1)
        let size = filter.contentRect.size
        let width = max(1, Int((size.width * scale).rounded()))
        let height = max(1, Int((size.height * scale).rounded()))

        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            AppLog.capture.error(
                "ScreenCaptureKit window capture failed: \(String(describing: error), privacy: .public)",
            )
            return nil
        }
    }

    static func captureScrolling(rect: CGRect) async -> CGImage? {
        guard let context = await makeScrollingCaptureContext(rect: rect) else { return nil }
        return await captureScrolling(context: context)
    }

    static func preflightScrollingCapture(rect: CGRect) async -> ScrollingCapturePreflightResult {
        let screenFrames = await MainActor.run {
            NSScreen.screens.map(\.frame)
        }
        return ScrollingCapturePreflight.evaluate(rect: rect, screenFrames: screenFrames)
    }

    static func makeScrollingCaptureContext(rect: CGRect) async -> ScrollingCaptureContext? {
        guard await preflightScrollingCapture(rect: rect) == .ready else { return nil }
        guard let screenTarget = await screenTarget(containing: rect) else { return nil }
        guard let content = await shareableContent(),
              let display = scDisplay(for: screenTarget.displayID, in: content)
        else { return nil }
        let currentApp = currentApplication(in: content)

        let clampedRect = rect.intersection(screenTarget.frame)
        guard !clampedRect.isNull, !clampedRect.isEmpty else { return nil }
        let integralRect = clampedRect.integral
        let adjustedRect = ScreenCaptureCoordinateConverter.adjustedRect(
            for: integralRect,
            screenFrame: screenTarget.frame,
        )

        let excludedApps = currentApp.map { [$0] } ?? []
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        let scale = max(CGFloat(filter.pointPixelScale), 1)
        let width = max(1, Int((adjustedRect.width * scale).rounded(.up)))
        let height = max(1, Int((adjustedRect.height * scale).rounded(.up)))

        let config = SCStreamConfiguration()
        config.sourceRect = adjustedRect
        config.width = width
        config.height = height
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false

        return ScrollingCaptureContext(filter: filter, configuration: config)
    }

    static func captureScrolling(context: ScrollingCaptureContext) async -> CGImage? {
        let signpostID = AppSignpost.begin("ScreenCaptureKit frame capture")
        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: context.filter,
                configuration: context.configuration,
            )
            AppSignpost.end("ScreenCaptureKit frame capture", id: signpostID)
            return image
        } catch {
            AppSignpost.end("ScreenCaptureKit frame capture", id: signpostID)
            AppLog.capture.error(
                "ScreenCaptureKit scrolling capture failed: \(String(describing: error), privacy: .public)",
            )
            return nil
        }
    }
}

private extension ScreenCaptureService {
    private static func screenTargets(intersecting rect: CGRect) async -> [ScreenCaptureTarget] {
        await MainActor.run {
            let screens = NSScreen.screens
            guard !screens.isEmpty else { return [] }
            let displayKey = NSDeviceDescriptionKey("NSScreenNumber")
            return screens.compactMap { screen in
                guard let displayID = screen.deviceDescription[displayKey] as? CGDirectDisplayID else {
                    return nil
                }
                let intersection = rect.intersection(screen.frame)
                guard !intersection.isNull, !intersection.isEmpty else { return nil }
                return ScreenCaptureTarget(
                    frame: screen.frame,
                    displayID: displayID,
                    captureRect: intersection,
                )
            }
        }
    }

    private static func captureDisplay(
        display: SCDisplay,
        screenFrame: CGRect,
        captureRect: CGRect,
        excludedWindows: [SCWindow],
    ) async -> CapturedPiece? {
        let adjustedRect = ScreenCaptureCoordinateConverter.adjustedRect(for: captureRect, screenFrame: screenFrame)
        guard adjustedRect.width > 0, adjustedRect.height > 0 else { return nil }

        let filter = if excludedWindows.isEmpty {
            SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        } else {
            SCContentFilter(display: display, excludingWindows: excludedWindows)
        }

        let scale = max(CGFloat(filter.pointPixelScale), 1)
        let width = max(1, Int((adjustedRect.width * scale).rounded(.up)))
        let height = max(1, Int((adjustedRect.height * scale).rounded(.up)))

        let config = SCStreamConfiguration()
        config.sourceRect = adjustedRect
        config.width = width
        config.height = height
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false

        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config,
            )
            return CapturedPiece(image: image, pointRect: captureRect, nativeScale: scale)
        } catch {
            AppLog.capture.error(
                "ScreenCaptureKit display capture failed: \(String(describing: error), privacy: .public)",
            )
            return nil
        }
    }

    private static func screenTarget(containing rect: CGRect) async -> ScreenCaptureTarget? {
        await MainActor.run {
            let screens = NSScreen.screens
            guard !screens.isEmpty else { return nil }
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let candidate = screens.first(where: { $0.frame.contains(center) })
                ?? screens.max(by: { intersectionArea(rect, $0.frame) < intersectionArea(rect, $1.frame) })
            let displayKey = NSDeviceDescriptionKey("NSScreenNumber")
            guard let screen = candidate,
                  let displayID = screen.deviceDescription[displayKey] as? CGDirectDisplayID
            else {
                return nil
            }
            return ScreenCaptureTarget(frame: screen.frame, displayID: displayID, captureRect: rect)
        }
    }

    private static func intersectionArea(_ rect: CGRect, _ frame: CGRect) -> CGFloat {
        let intersection = rect.intersection(frame)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    private static func shareableContent() async -> SCShareableContent? {
        do {
            return try await SCShareableContent.current
        } catch {
            AppLog.capture.error(
                "Failed to fetch ScreenCaptureKit shareable content: \(String(describing: error), privacy: .public)",
            )
            return nil
        }
    }

    private static func scDisplaysByID(in content: SCShareableContent) -> [CGDirectDisplayID: SCDisplay] {
        Dictionary(uniqueKeysWithValues: content.displays.map { ($0.displayID, $0) })
    }

    private static func scDisplay(for displayID: CGDirectDisplayID, in content: SCShareableContent) -> SCDisplay? {
        content.displays.first { $0.displayID == displayID }
    }

    private static func scWindow(for windowID: CGWindowID?, in content: SCShareableContent) -> SCWindow? {
        guard let windowID else { return nil }
        return content.windows.first { $0.windowID == windowID }
    }

    private static func scWindows(for windowIDs: Set<CGWindowID>, in content: SCShareableContent) -> [SCWindow] {
        guard !windowIDs.isEmpty else { return [] }
        return content.windows.filter { windowIDs.contains($0.windowID) }
    }

    private static func currentApplication(in content: SCShareableContent) -> SCRunningApplication? {
        let pid = NSRunningApplication.current.processIdentifier
        return content.applications.first { $0.processID == pid }
    }
}
