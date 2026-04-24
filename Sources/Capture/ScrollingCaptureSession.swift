import AppKit

typealias ScrollingFrameCapture = @Sendable () async -> CGImage?

@MainActor
final class ScrollingCaptureSession {
    private let targetFrameInterval: TimeInterval
    private let stitcher: ScrollingStitcher
    private let makeFrameCapture: @Sendable (CGRect) async -> ScrollingFrameCapture?
    private var captureTask: Task<Void, Never>?
    private var captureRect: CGRect = .zero
    private var onFinish: ((CGImage?) -> Void)?
    private var keyMonitor: EventMonitor?
    private var globalKeyMonitor: EventMonitor?

    init(
        captureInterval: TimeInterval = 0.1,
        stitcher: ScrollingStitcher = ScrollingStitcher(),
        makeFrameCapture: @escaping @Sendable (CGRect) async -> ScrollingFrameCapture? = { rect in
            guard let context = await ScreenCaptureService.makeScrollingCaptureContext(rect: rect) else {
                return nil
            }
            return {
                await ScreenCaptureService.captureScrolling(context: context)
            }
        },
    ) {
        targetFrameInterval = max(captureInterval, 0.1)
        self.stitcher = stitcher
        self.makeFrameCapture = makeFrameCapture
    }

    convenience init(
        captureInterval: TimeInterval = 0.1,
        stitcher: ScrollingStitcher = ScrollingStitcher(),
        captureImage: @escaping @Sendable (CGRect) async -> CGImage?,
    ) {
        self.init(captureInterval: captureInterval, stitcher: stitcher) { rect in
            {
                await captureImage(rect)
            }
        }
    }

    var isActive: Bool {
        captureTask != nil
    }

    func start(rect: CGRect, onFinish: @escaping (CGImage?) -> Void) {
        guard captureTask == nil else { return }
        startKeyMonitor()
        captureRect = rect
        self.onFinish = onFinish
        AccessibilityAnnouncer.announce("Scrolling capture started")
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
        guard let captureFrame = await makeFrameCapture(captureRect), !Task.isCancelled else {
            finish(with: nil)
            return
        }

        while !Task.isCancelled {
            let start = Date()
            if let image = await captureFrame(), !Task.isCancelled {
                let status = await stitcher.add(image)
                if status == .limitReached {
                    break
                }
            }
            await sleepAfterFrame(startedAt: start)
        }

        let signpostID = AppSignpost.begin("Scrolling final composition")
        let finalImage = await stitcher.finish()
        AppSignpost.end("Scrolling final composition", id: signpostID)
        finish(with: finalImage)
    }

    private func sleepAfterFrame(startedAt start: Date) async {
        let elapsed = Date().timeIntervalSince(start)
        let remaining = targetFrameInterval - elapsed
        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }

    private func finish(with image: CGImage?) {
        stopKeyMonitor()
        let callback = onFinish
        onFinish = nil
        captureTask = nil
        AccessibilityAnnouncer.announce("Scrolling capture stopped")
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
