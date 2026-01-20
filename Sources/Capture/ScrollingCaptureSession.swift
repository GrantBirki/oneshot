import AppKit

final class ScrollingCaptureSession {
    private let captureInterval: TimeInterval
    private let stateQueue: DispatchQueue
    private let stitchQueue: DispatchQueue
    private let stitcher: ScrollingStitcher
    private let captureImage: (CGRect) async -> CGImage?
    private var captureTask: Task<Void, Never>?
    private var captureRect: CGRect = .zero
    private var onFinish: ((CGImage?) -> Void)?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?

    private enum KeyCodes {
        static let escape: UInt16 = 53
    }

    init(
        captureInterval: TimeInterval = 0.15,
        stateQueue: DispatchQueue = DispatchQueue(label: "oneshot.scrolling.capture", qos: .userInitiated),
        stitchQueue: DispatchQueue = DispatchQueue(label: "oneshot.scrolling.stitch", qos: .userInitiated),
        stitcher: ScrollingStitcher = ScrollingStitcher(),
        captureImage: @escaping (CGRect) async -> CGImage? = { await ScreenCaptureService.captureScrolling(rect: $0) },
    ) {
        self.captureInterval = captureInterval
        self.stateQueue = stateQueue
        self.stitchQueue = stitchQueue
        self.stitcher = stitcher
        self.captureImage = captureImage
    }

    var isActive: Bool {
        stateQueue.sync { captureTask != nil }
    }

    func start(rect: CGRect, onFinish: @escaping (CGImage?) -> Void) {
        startKeyMonitor()
        stateQueue.sync {
            guard captureTask == nil else { return }
            captureRect = rect
            self.onFinish = onFinish
            stitchQueue.sync {
                stitcher.reset()
            }
            captureTask = Task.detached(priority: .userInitiated) { [weak self] in
                await self?.captureLoop()
            }
        }
    }

    func stop() {
        stopKeyMonitor()
        stateQueue.sync {
            captureTask?.cancel()
        }
    }

    private func captureLoop() async {
        defer { finish() }
        let interval = max(captureInterval, 0.05)
        while !Task.isCancelled {
            if let image = await captureImage(captureRect) {
                stitchQueue.async { [stitcher] in
                    stitcher.add(image)
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func finish() {
        let finalImage = stitchQueue.sync {
            stitcher.finish()
        }
        let finish = stateQueue.sync {
            let callback = onFinish
            onFinish = nil
            captureTask = nil
            return callback
        }
        DispatchQueue.main.async {
            finish?(finalImage)
        }
    }

    private func startKeyMonitor() {
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                if event.keyCode == KeyCodes.escape {
                    self?.stop()
                    return nil
                }
                return event
            }
        }

        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                if event.keyCode == KeyCodes.escape {
                    DispatchQueue.main.async {
                        self?.stop()
                    }
                }
            }
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil

        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalKeyMonitor = nil
    }
}
