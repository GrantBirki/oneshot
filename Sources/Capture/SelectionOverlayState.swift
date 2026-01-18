import CoreGraphics

final class SelectionOverlayState {
    var start: CGPoint?
    var current: CGPoint?
    let showSelectionCoordinates: Bool
    let dimmingMode: SelectionDimmingMode

    init(showSelectionCoordinates: Bool, dimmingMode: SelectionDimmingMode) {
        self.showSelectionCoordinates = showSelectionCoordinates
        self.dimmingMode = dimmingMode
    }

    var rect: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(start.x - current.x),
            height: abs(start.y - current.y),
        )
    }

    var selectionSizeText: String? {
        guard showSelectionCoordinates, let start, let current else { return nil }
        let width = Int(abs(current.x - start.x).rounded())
        let height = Int(abs(current.y - start.y).rounded())
        return "\(width) x \(height)"
    }
}
