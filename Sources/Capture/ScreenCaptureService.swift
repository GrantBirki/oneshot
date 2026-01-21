import AppKit
import ScreenCaptureKit

enum ScreenCaptureService {
    private struct ScreenCaptureTarget: Sendable {
        let frame: CGRect
        let displayID: CGDirectDisplayID
    }

    static func captureFullScreen() -> CGImage? {
        CGWindowListCreateImage(
            CGRect.infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution],
        )
    }

    static func capture(rect: CGRect, excludingWindowID: CGWindowID? = nil) -> CGImage? {
        let captureRect = cgRect(fromScreenRect: rect)
        let options: CGWindowListOption = excludingWindowID == nil ? .optionOnScreenOnly : .optionOnScreenBelowWindow
        let windowID = excludingWindowID ?? kCGNullWindowID
        return CGWindowListCreateImage(
            captureRect,
            options,
            windowID,
            [.bestResolution],
        )
    }

    static func capture(windowID: CGWindowID) -> CGImage? {
        CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.bestResolution],
        )
    }

    static func captureScrolling(rect: CGRect) async -> CGImage? {
        guard let screenTarget = await screenTarget(containing: rect) else { return nil }
        guard let display = await scDisplay(for: screenTarget.displayID) else { return nil }
        let currentApp = await currentApplication()

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
        let width = max(1, Int(adjustedRect.width * scale))
        let height = max(1, Int(adjustedRect.height * scale))

        let config = SCStreamConfiguration()
        config.sourceRect = adjustedRect
        config.width = width
        config.height = height
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            NSLog("ScreenCaptureKit capture failed: \(error)")
            return nil
        }
    }

    private static func cgRect(fromScreenRect rect: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else { return rect }
        let mainHeight = mainScreen.frame.height
        return CGRect(
            x: rect.origin.x,
            y: mainHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height,
        )
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
            return ScreenCaptureTarget(frame: screen.frame, displayID: displayID)
        }
    }

    private static func intersectionArea(_ rect: CGRect, _ frame: CGRect) -> CGFloat {
        let intersection = rect.intersection(frame)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    private static func scDisplay(for displayID: CGDirectDisplayID) async -> SCDisplay? {
        do {
            let displays = try await SCShareableContent.current.displays
            return displays.first { $0.displayID == displayID }
        } catch {
            NSLog("Failed to fetch SCDisplay: \(error)")
            return nil
        }
    }

    private static func currentApplication() async -> SCRunningApplication? {
        do {
            let apps = try await SCShareableContent.current.applications
            let pid = NSRunningApplication.current.processIdentifier
            return apps.first { $0.processID == pid }
        } catch {
            NSLog("Failed to fetch current app for capture: \(error)")
            return nil
        }
    }
}
