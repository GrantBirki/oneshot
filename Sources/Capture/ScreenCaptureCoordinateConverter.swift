import CoreGraphics

enum ScreenCaptureCoordinateConverter {
    static func adjustedRect(for rect: CGRect, screenFrame: CGRect) -> CGRect {
        let screenHeight = screenFrame.height + screenFrame.minY
        return CGRect(
            x: rect.origin.x - screenFrame.minX,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height,
        )
    }
}
