import CoreGraphics

enum OverlayPathBuilder {
    static func dimmingPath(for selection: CGRect?, in bounds: CGRect, mode: SelectionDimmingMode) -> CGPath? {
        switch mode {
        case .selectionOnly:
            guard let selection else { return nil }
            return CGPath(rect: selection, transform: nil)
        case .fullScreen:
            let path = CGMutablePath()
            path.addRect(bounds)
            if let selection {
                path.addRect(selection)
            }
            return path
        }
    }
}
