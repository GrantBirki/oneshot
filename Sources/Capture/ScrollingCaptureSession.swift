import AppKit

@MainActor
final class ScrollingCaptureSession {
    private let captureInterval: TimeInterval
    private let stitcher: ScrollingStitcher
    private let captureImage: @Sendable (CGRect) async -> CGImage?
    private var captureTask: Task<Void, Never>?
    private var captureRect: CGRect = .zero
    private var onFinish: ((CGImage?) -> Void)?
    private var keyMonitor: EventMonitor?
    private var globalKeyMonitor: EventMonitor?

    init(
        captureInterval: TimeInterval = 0.025,
        stitcher: ScrollingStitcher = ScrollingStitcher(),
        captureImage: @escaping @Sendable (CGRect) async -> CGImage? = {
            await ScreenCaptureService.captureScrolling(rect: $0)
        },
    ) {
        self.captureInterval = captureInterval
        self.stitcher = stitcher
        self.captureImage = captureImage
    }

    var isActive: Bool {
        captureTask != nil
    }

    func start(rect: CGRect, onFinish: @escaping (CGImage?) -> Void) {
        guard captureTask == nil else { return }
        startKeyMonitor()
        captureRect = rect
        self.onFinish = onFinish
        captureTask = Task(priority: .userInitiated) { [weak self] in
            await self?.captureLoop()
        }
    }

    func stop() {
        stopKeyMonitor()
        captureTask?.cancel()
    }

    private func captureLoop() async {
        await stitcher.reset()
        let interval = max(captureInterval, 0.025)
        while !Task.isCancelled {
            if let image = await captureImage(captureRect), !Task.isCancelled {
                await stitcher.add(image)
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        let finalImage = await stitcher.finish()
        finish(with: finalImage)
    }

    private func finish(with image: CGImage?) {
        stopKeyMonitor()
        let callback = onFinish
        onFinish = nil
        captureTask = nil
        callback?(image)
    }

    private func startKeyMonitor() {
        if keyMonitor == nil {
            keyMonitor = EventMonitor(NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                let shouldCancel = event.keyCode == KeyboardKeyCode.escape
                let handled = MainActor.assumeIsolated {
                    if shouldCancel {
                        self?.stop()
                        return true
                    }
                    return false
                }
                return handled ? nil : event
            })
        }

        if globalKeyMonitor == nil {
            let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                let keyCode = event.keyCode
                if keyCode == KeyboardKeyCode.escape {
                    DispatchQueue.main.async {
                        self?.stop()
                    }
                }
            }
            globalKeyMonitor = EventMonitor(monitor)
        }
    }

    private func stopKeyMonitor() {
        keyMonitor?.cancel()
        keyMonitor = nil

        globalKeyMonitor?.cancel()
        globalKeyMonitor = nil
    }
}
