import AppKit

enum ScreenCaptureService {
    static func captureFullScreen() -> CGImage? {
        CGWindowListCreateImage(
            CGRect.infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
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
            [.bestResolution]
        )
    }

    static func capture(windowID: CGWindowID) -> CGImage? {
        CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.bestResolution]
        )
    }

    private static func cgRect(fromScreenRect rect: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else { return rect }
        let mainHeight = mainScreen.frame.height
        return CGRect(
            x: rect.origin.x,
            y: mainHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
