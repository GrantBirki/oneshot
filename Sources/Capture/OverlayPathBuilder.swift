import CoreGraphics

enum OverlayPathBuilder {
    static func innerDimmingPath(for rect: CGRect?) -> CGPath? {
        guard let rect else { return nil }
        return CGPath(rect: rect, transform: nil)
    }
}
