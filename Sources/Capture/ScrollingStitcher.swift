import CoreGraphics
import Vision

protocol ScrollingOffsetCalculating {
    func verticalOffset(from current: CGImage, to previous: CGImage) -> CGFloat?
}

struct VisionScrollingOffsetCalculator: ScrollingOffsetCalculating {
    func verticalOffset(from current: CGImage, to previous: CGImage) -> CGFloat? {
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: previous)
        let handler = VNImageRequestHandler(cgImage: current, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            return nil
        }

        return observation.alignmentTransform.ty
    }
}

// Access is serialized by the capture session's stitch queue.
final class ScrollingStitcher: @unchecked Sendable {
    private var runningImage: CGImage?
    private var previousImage: CGImage?
    private let offsetCalculator: ScrollingOffsetCalculating
    private let minimumOffset: Int

    init(
        offsetCalculator: ScrollingOffsetCalculating = VisionScrollingOffsetCalculator(),
        minimumOffset: Int = 1,
    ) {
        self.offsetCalculator = offsetCalculator
        self.minimumOffset = minimumOffset
    }

    func reset() {
        runningImage = nil
        previousImage = nil
    }

    func start(with image: CGImage) {
        runningImage = image
        previousImage = image
    }

    func add(_ image: CGImage) {
        guard let base = runningImage, let previous = previousImage else {
            start(with: image)
            return
        }

        guard image.width == previous.width, image.height == previous.height else {
            runningImage = image
            previousImage = image
            return
        }

        guard let offset = offsetCalculator.verticalOffset(from: image, to: previous) else {
            previousImage = image
            return
        }

        let offsetPixels = Int(offset.rounded())
        if abs(offsetPixels) < minimumOffset {
            previousImage = image
            return
        }

        if abs(offsetPixels) >= image.height {
            previousImage = image
            return
        }

        if offsetPixels > 0 {
            if let stitched = composite(baseImage: base, newImage: image, offset: offsetPixels) {
                runningImage = stitched
            }
        } else {
            if let cropped = cropBottom(of: base, by: abs(offsetPixels)) {
                runningImage = cropped
            }
        }

        previousImage = image
    }

    func finish() -> CGImage? {
        runningImage
    }

    private func composite(baseImage: CGImage, newImage: CGImage, offset: Int) -> CGImage? {
        guard baseImage.width == newImage.width else { return nil }
        let totalHeight = baseImage.height + offset
        guard totalHeight > 0 else { return nil }

        guard let context = makeContext(reference: baseImage, height: totalHeight) else { return nil }

        let baseRect = CGRect(
            x: 0,
            y: CGFloat(offset),
            width: CGFloat(baseImage.width),
            height: CGFloat(baseImage.height),
        )
        let newRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(newImage.width),
            height: CGFloat(newImage.height),
        )

        context.draw(baseImage, in: baseRect)
        context.draw(newImage, in: newRect)

        return context.makeImage()
    }

    private func cropBottom(of image: CGImage, by amount: Int) -> CGImage? {
        let newHeight = image.height - amount
        guard newHeight > 0 else { return nil }
        guard let context = makeContext(reference: image, height: newHeight) else { return nil }

        let drawRect = CGRect(
            x: 0,
            y: -CGFloat(amount),
            width: CGFloat(image.width),
            height: CGFloat(image.height),
        )
        context.draw(image, in: drawRect)

        return context.makeImage()
    }

    private func makeContext(reference image: CGImage, height: Int) -> CGContext? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: image.width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue,
        )
    }
}
