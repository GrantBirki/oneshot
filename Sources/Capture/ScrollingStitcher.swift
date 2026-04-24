import CoreGraphics
import Vision

protocol ScrollingOffsetCalculating: Sendable {
    func verticalOffset(from current: CGImage, to previous: CGImage) -> CGFloat?
}

struct VisionScrollingOffsetCalculator: ScrollingOffsetCalculating {
    private let maxRegistrationDimension: Int

    init(maxRegistrationDimension: Int = 900) {
        self.maxRegistrationDimension = maxRegistrationDimension
    }

    func verticalOffset(from current: CGImage, to previous: CGImage) -> CGFloat? {
        let currentRegistrationImage = registrationImage(for: current)
        let previousRegistrationImage = registrationImage(for: previous)
        let signpostID = AppSignpost.begin("Vision scrolling offset")
        defer {
            AppSignpost.end("Vision scrolling offset", id: signpostID)
        }

        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: previousRegistrationImage.image)
        let handler = VNImageRequestHandler(cgImage: currentRegistrationImage.image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            return nil
        }

        return observation.alignmentTransform.ty / currentRegistrationImage.scale
    }

    private func registrationImage(for image: CGImage) -> (image: CGImage, scale: CGFloat) {
        let longestSide = max(image.width, image.height)
        guard longestSide > maxRegistrationDimension else {
            return (image, 1)
        }

        let scale = CGFloat(maxRegistrationDimension) / CGFloat(longestSide)
        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        guard let scaled = makeScaledImage(image, width: width, height: height) else {
            return (image, 1)
        }
        return (scaled, scale)
    }

    private func makeScaledImage(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue,
        ) else {
            return nil
        }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

enum ScrollingStitcherStatus: Equatable {
    case accepted
    case ignored
    case limitReached
}

actor ScrollingStitcher {
    private struct Segment {
        var image: CGImage
        var originY: Int
    }

    private var segments: [Segment] = []
    private var previousImage: CGImage?
    private var width: Int?
    private var height = 0
    private var didReachPixelLimit = false
    private let offsetCalculator: ScrollingOffsetCalculating
    private let minimumOffset: Int
    private let maxPixelCount: Int

    init(
        offsetCalculator: ScrollingOffsetCalculating = VisionScrollingOffsetCalculator(),
        minimumOffset: Int = 1,
        maxPixelCount: Int = 120_000_000,
    ) {
        self.offsetCalculator = offsetCalculator
        self.minimumOffset = minimumOffset
        self.maxPixelCount = maxPixelCount
    }

    func reset() {
        segments = []
        previousImage = nil
        width = nil
        height = 0
        didReachPixelLimit = false
    }

    func start(with image: CGImage) {
        segments = [Segment(image: image, originY: 0)]
        previousImage = image
        width = image.width
        height = image.height
        didReachPixelLimit = false
    }

    @discardableResult
    func add(_ image: CGImage) -> ScrollingStitcherStatus {
        guard !didReachPixelLimit else {
            return .limitReached
        }

        guard let previous = previousImage, let width else {
            start(with: image)
            return .accepted
        }

        guard image.width == width, image.height == previous.height else {
            start(with: image)
            return .accepted
        }

        guard let offset = offsetCalculator.verticalOffset(from: image, to: previous) else {
            previousImage = image
            return .ignored
        }

        let offsetPixels = Int(offset.rounded())
        if abs(offsetPixels) < minimumOffset {
            previousImage = image
            return .ignored
        }

        if abs(offsetPixels) >= image.height {
            previousImage = image
            return .ignored
        }

        if offsetPixels > 0 {
            let nextHeight = height + offsetPixels
            if nextHeight * width > maxPixelCount {
                didReachPixelLimit = true
                let dimensions = "\(width)x\(nextHeight)"
                AppLog.capture.warning(
                    "Scrolling capture pixel limit reached at \(dimensions, privacy: .public)",
                )
                return .limitReached
            }
            shiftSegments(upBy: offsetPixels)
            segments.append(Segment(image: image, originY: 0))
            height = nextHeight
        } else {
            cropBottom(by: abs(offsetPixels))
        }

        previousImage = image
        return .accepted
    }

    func finish() -> CGImage? {
        guard let width, height > 0, let reference = segments.first?.image else { return nil }
        guard let context = makeContext(reference: reference, width: width, height: height) else { return nil }
        context.interpolationQuality = .none

        for segment in segments {
            let drawRect = CGRect(
                x: 0,
                y: CGFloat(segment.originY),
                width: CGFloat(segment.image.width),
                height: CGFloat(segment.image.height),
            )
            context.draw(segment.image, in: drawRect)
        }

        return context.makeImage()
    }

    func reachedPixelLimitForTesting() -> Bool {
        didReachPixelLimit
    }

    private func shiftSegments(upBy amount: Int) {
        for index in segments.indices {
            segments[index].originY += amount
        }
    }

    private func cropBottom(by amount: Int) {
        height = max(0, height - amount)
        for index in segments.indices {
            segments[index].originY -= amount
        }
        segments.removeAll { segment in
            segment.originY + segment.image.height <= 0
        }
    }

    private func makeContext(reference image: CGImage, width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue,
        )
    }
}
