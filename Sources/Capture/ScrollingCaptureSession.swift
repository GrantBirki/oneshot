import AppKit

typealias ScrollingFrameCapture = @Sendable () async -> CGImage?

enum ScrollingCompletionReason: Equatable, Sendable {
    case userStopped
    case limitReached
    case captureFailed
    case cancelled
}

struct ScrollingCaptureResult: @unchecked Sendable {
    let image: CGImage?
    let reason: ScrollingCompletionReason
}

struct ScrollingSessionClock: Sendable {
    let now: @Sendable () -> ContinuousClock.Instant
    let sleep: @Sendable (Duration) async -> Void

    static let continuous = ScrollingSessionClock(
        now: { ContinuousClock.now },
        sleep: { duration in
            try? await Task.sleep(for: duration)
        },
    )
}

@MainActor
final class ScrollingCaptureSession {
    private let targetFrameInterval: Duration
    private let maximumConsecutiveFailures: Int
    private let stitcher: ScrollingStitcher
    private let makeFrameCapture: @Sendable (CGRect) async -> ScrollingFrameCapture?
    private let clock: ScrollingSessionClock
    private var captureTask: Task<Void, Never>?
    private var captureRect: CGRect = .zero
    private var onFinish: ((ScrollingCaptureResult) -> Void)?
    private var requestedCompletionReason: ScrollingCompletionReason?

    init(
        captureInterval: TimeInterval = 0.1,
        maximumConsecutiveFailures: Int = 5,
        stitcher: ScrollingStitcher = ScrollingStitcher(),
        clock: ScrollingSessionClock = .continuous,
        makeFrameCapture: @escaping @Sendable (CGRect) async -> ScrollingFrameCapture? = { rect in
            guard let context = await ScreenCaptureService.makeScrollingCaptureContext(rect: rect) else {
                return nil
            }
            return {
                await ScreenCaptureService.captureScrolling(context: context)
            }
        },
    ) {
        let sanitizedInterval = captureInterval.isFinite
            ? min(max(captureInterval, 0.1), 3600)
            : 0.1
        targetFrameInterval = .nanoseconds(Int64((sanitizedInterval * 1_000_000_000).rounded()))
        self.maximumConsecutiveFailures = max(1, maximumConsecutiveFailures)
        self.stitcher = stitcher
        self.clock = clock
        self.makeFrameCapture = makeFrameCapture
    }

    convenience init(
        captureInterval: TimeInterval = 0.1,
        maximumConsecutiveFailures: Int = 5,
        stitcher: ScrollingStitcher = ScrollingStitcher(),
        clock: ScrollingSessionClock = .continuous,
        captureImage: @escaping @Sendable (CGRect) async -> CGImage?,
    ) {
        self.init(
            captureInterval: captureInterval,
            maximumConsecutiveFailures: maximumConsecutiveFailures,
            stitcher: stitcher,
            clock: clock,
        ) { rect in
            {
                await captureImage(rect)
            }
        }
    }

    var isActive: Bool {
        captureTask != nil
    }

    @discardableResult
    func start(rect: CGRect, onFinish: @escaping (ScrollingCaptureResult) -> Void) -> Bool {
        guard captureTask == nil else { return false }
        captureRect = rect
        self.onFinish = onFinish
        requestedCompletionReason = nil
        AccessibilityAnnouncer.announce("Scrolling capture started")
        captureTask = Task(priority: .userInitiated) { [weak self] in
            await self?.captureLoop()
        }
        return true
    }

    @discardableResult
    func start(rect: CGRect, onFinish: @escaping (CGImage?) -> Void) -> Bool {
        start(rect: rect) { result in
            onFinish(result.reason == .cancelled ? nil : result.image)
        }
    }

    func stop() {
        requestStop(reason: .userStopped)
    }

    func cancel() {
        requestStop(reason: .cancelled)
    }

    private func requestStop(reason: ScrollingCompletionReason) {
        guard captureTask != nil else { return }
        requestedCompletionReason = reason
        captureTask?.cancel()
    }

    private func captureLoop() async {
        await stitcher.reset()
        guard let captureFrame = await makeFrameCapture(captureRect), !Task.isCancelled else {
            finish(with: nil, reason: requestedCompletionReason ?? .captureFailed)
            return
        }

        var consecutiveFailures = 0
        var completionReason: ScrollingCompletionReason?

        while !Task.isCancelled {
            let startedAt = clock.now()
            if let image = await captureFrame(), !Task.isCancelled {
                let status = await stitcher.add(image)
                switch status {
                case .accepted,
                     .ignored(.noMovement),
                     .ignored(.reverseMovement),
                     .ignored(.horizontalDrift),
                     .ignored(.discontinuousMovement):
                    consecutiveFailures = 0
                case .ignored(.registrationFailed), .ignored(.incompatibleFrame):
                    consecutiveFailures += 1
                case .limitReached:
                    completionReason = .limitReached
                }
            } else if !Task.isCancelled {
                consecutiveFailures += 1
            }

            if completionReason != nil {
                break
            }
            if consecutiveFailures >= maximumConsecutiveFailures {
                AppLog.capture.warning("Scrolling capture stopped after repeated frame failures")
                completionReason = .captureFailed
                break
            }
            await sleepAfterFrame(startedAt: startedAt)
        }

        let signpostID = AppSignpost.begin("Scrolling final composition")
        let finalImage = await stitcher.finish()
        AppSignpost.end("Scrolling final composition", id: signpostID)
        let reason = completionReason ?? requestedCompletionReason ?? .cancelled
        finish(with: finalImage, reason: reason)
    }

    private func sleepAfterFrame(startedAt: ContinuousClock.Instant) async {
        let elapsed = startedAt.duration(to: clock.now())
        let remaining = targetFrameInterval - elapsed
        guard remaining > .zero else { return }
        await clock.sleep(remaining)
    }

    private func finish(with image: CGImage?, reason: ScrollingCompletionReason) {
        let callback = onFinish
        onFinish = nil
        captureTask = nil
        requestedCompletionReason = nil

        switch reason {
        case .limitReached:
            AccessibilityAnnouncer.announce("Scrolling capture stopped at the size limit")
        case .captureFailed:
            AccessibilityAnnouncer.announce("Scrolling capture stopped after repeated capture failures")
        case .userStopped:
            AccessibilityAnnouncer.announce("Scrolling capture stopped")
        case .cancelled:
            break
        }
        callback?(ScrollingCaptureResult(image: image, reason: reason))
    }
}
