import AppKit

final class EventMonitor {
    private var monitor: Any?
    private let remove: (Any) -> Void

    init(_ monitor: Any?, remove: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) }) {
        self.monitor = monitor
        self.remove = remove
    }

    var isActive: Bool {
        monitor != nil
    }

    func cancel() {
        guard let monitor else { return }
        remove(monitor)
        self.monitor = nil
    }

    deinit {
        cancel()
    }
}
