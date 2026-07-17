import CoreGraphics
import Vision

struct ScrollingOffset: Equatable, Sendable {
    let horizontal: CGFloat
    let vertical: CGFloat
}

protocol ScrollingOffsetCalculating: Sendable {
    var retainedImagesForMemoryAccounting: [CGImage] { get }

    func retainedImagesDuringOffset(from current: CGImage, to previous: CGImage) -> [CGImage]
    func projectedAdditionalBytesForOffset(from current: CGImage, to previous: CGImage) -> Int
    mutating func offset(from current: CGImage, to previous: CGImage) -> ScrollingOffset?
    mutating func reset()
}

extension ScrollingOffsetCalculating {
    var retainedImagesForMemoryAccounting: [CGImage] {
        []
    }

    func retainedImagesDuringOffset(from _: CGImage, to _: CGImage) -> [CGImage] {
        retainedImagesForMemoryAccounting
    }

    func projectedAdditionalBytesForOffset(from _: CGImage, to _: CGImage) -> Int {
        0
    }

    mutating func reset() {}
}

struct VisionScrollingOffsetCalculator: @unchecked Sendable, ScrollingOffsetCalculating {
    private struct RegistrationImage {
        let image: CGImage
        let scale: CGFloat
    }

    private let maxRegistrationDimension: Int
    private var cachedRegistrationImage: (source: CGImage, registration: RegistrationImage)?

    init(maxRegistrationDimension: Int = 900) {
        self.maxRegistrationDimension = maxRegistrationDimension
    }

    mutating func offset(from current: CGImage, to previous: CGImage) -> ScrollingOffset? {
        let previousRegistrationImage: RegistrationImage
        if let cachedRegistrationImage, cachedRegistrationImage.source === previous {
            previousRegistrationImage = cachedRegistrationImage.registration
        } else {
            cachedRegistrationImage = nil
            previousRegistrationImage = registrationImage(for: previous)
            cachedRegistrationImage = (source: previous, registration: previousRegistrationImage)
        }

        let currentRegistrationImage = current === previous
            ? previousRegistrationImage
            : registrationImage(for: current)

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

        cachedRegistrationImage = (source: current, registration: currentRegistrationImage)
        return ScrollingOffset(
            horizontal: observation.alignmentTransform.tx / currentRegistrationImage.scale,
            vertical: observation.alignmentTransform.ty / currentRegistrationImage.scale,
        )
    }

    mutating func reset() {
        cachedRegistrationImage = nil
    }

    var retainedImagesForMemoryAccounting: [CGImage] {
        guard let cachedRegistrationImage else { return [] }
        return [cachedRegistrationImage.source, cachedRegistrationImage.registration.image]
    }

    func retainedImagesDuringOffset(from _: CGImage, to previous: CGImage) -> [CGImage] {
        guard let cachedRegistrationImage, cachedRegistrationImage.source === previous else {
            return []
        }
        return [cachedRegistrationImage.source, cachedRegistrationImage.registration.image]
    }

    func projectedAdditionalBytesForOffset(from current: CGImage, to previous: CGImage) -> Int {
        var byteCount = 0
        if cachedRegistrationImage?.source !== previous {
            byteCount = registrationImageByteCount(for: previous)
        }
        if current !== previous {
            byteCount = saturatingSum(byteCount, registrationImageByteCount(for: current))
        }
        return byteCount
    }

    private func saturatingSum(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }

    private func registrationImageByteCount(for image: CGImage) -> Int {
        let longestSide = max(image.width, image.height)
        guard longestSide > maxRegistrationDimension else { return 0 }

        let scale = CGFloat(maxRegistrationDimension) / CGFloat(longestSide)
        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        guard let bytesPerRow = bitmapBytesPerRow(for: image, width: width) else {
            return .max
        }
        let result = bytesPerRow.multipliedReportingOverflow(by: height)
        return result.overflow ? .max : result.partialValue
    }

    private func registrationImage(for image: CGImage) -> RegistrationImage {
        let longestSide = max(image.width, image.height)
        guard longestSide > maxRegistrationDimension else {
            return RegistrationImage(image: image, scale: 1)
        }

        let scale = CGFloat(maxRegistrationDimension) / CGFloat(longestSide)
        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        guard let scaled = makeScaledImage(image, width: width, height: height) else {
            return RegistrationImage(image: image, scale: 1)
        }
        return RegistrationImage(image: scaled, scale: scale)
    }

    private func makeScaledImage(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let bytesPerRow = bitmapBytesPerRow(for: image, width: width) else {
            return nil
        }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: bytesPerRow,
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

enum ScrollingFrameIgnoreReason: Equatable, Sendable {
    case noMovement
    case reverseMovement
    case horizontalDrift
    case registrationFailed
    case incompatibleFrame
    case discontinuousMovement
}

enum ScrollingStitcherStatus: Equatable, Sendable {
    case accepted
    case ignored(ScrollingFrameIgnoreReason)
    case limitReached
}

actor ScrollingStitcher {
    private struct Segment {
        let image: CGImage
    }

    private var segments: [Segment] = []
    private var previousAcceptedImage: CGImage?
    private var width: Int?
    private var height = 0
    private var retainedByteCount = 0
    private var retainedSegmentImageIDs: Set<ObjectIdentifier> = []
    private var destinationBytesPerRow: Int?
    private var didReachLimit = false
    private var offsetCalculator: any ScrollingOffsetCalculating
    private let verticalNoiseTolerance: Int
    private let maximumHorizontalDrift: Int
    private let maximumHorizontalDriftRatio: CGFloat
    private let maxPixelCount: Int
    private let maxWorkingSetBytes: Int

    init(
        offsetCalculator: any ScrollingOffsetCalculating = VisionScrollingOffsetCalculator(),
        verticalNoiseTolerance: Int = 1,
        maximumHorizontalDrift: Int = 4,
        maximumHorizontalDriftRatio: CGFloat = 0.01,
        maxPixelCount: Int = 120_000_000,
        maxWorkingSetBytes: Int = 480_000_000,
    ) {
        self.offsetCalculator = offsetCalculator
        self.verticalNoiseTolerance = max(0, verticalNoiseTolerance)
        self.maximumHorizontalDrift = max(0, maximumHorizontalDrift)
        self.maximumHorizontalDriftRatio = max(0, maximumHorizontalDriftRatio)
        self.maxPixelCount = max(1, maxPixelCount)
        self.maxWorkingSetBytes = max(1, maxWorkingSetBytes)
    }

    func reset() {
        releaseCapturedFrames()
        didReachLimit = false
        offsetCalculator.reset()
    }

    @discardableResult
    func start(with image: CGImage) -> ScrollingStitcherStatus {
        releaseCapturedFrames()
        offsetCalculator.reset()

        let outputPixelCount = safeProduct(image.width, image.height)
        let imageBytes = estimatedByteCount(for: image)
        guard let destinationBytesPerRow = bitmapBytesPerRow(for: image, width: image.width) else {
            didReachLimit = true
            return .limitReached
        }
        let outputByteCount = safeProduct(destinationBytesPerRow, image.height)
        let projectedWorkingSet = safeSum(imageBytes, outputByteCount)
        guard outputPixelCount <= maxPixelCount, projectedWorkingSet <= maxWorkingSetBytes else {
            didReachLimit = true
            return .limitReached
        }

        segments = [Segment(image: image)]
        previousAcceptedImage = image
        width = image.width
        height = image.height
        retainedByteCount = imageBytes
        retainedSegmentImageIDs = [ObjectIdentifier(image)]
        self.destinationBytesPerRow = destinationBytesPerRow
        didReachLimit = false
        return .accepted
    }

    @discardableResult
    func add(_ image: CGImage) -> ScrollingStitcherStatus {
        guard !didReachLimit else {
            return .limitReached
        }

        guard let previousAcceptedImage, let width, let destinationBytesPerRow else {
            return start(with: image)
        }

        guard image.width == width, image.height == previousAcceptedImage.height else {
            return .ignored(.incompatibleFrame)
        }

        let currentOutputByteCount = safeProduct(destinationBytesPerRow, height)
        let frameImages = [previousAcceptedImage, image]
        let currentWorkingSet = projectedWorkingSet(
            outputByteCount: currentOutputByteCount,
            additionalRetainedByteCount: 0,
            frameImages: frameImages + offsetCalculator.retainedImagesForMemoryAccounting,
        )
        guard currentWorkingSet <= maxWorkingSetBytes else {
            return reachLimit(width: width, height: height)
        }

        let preRegistrationWorkingSet = projectedWorkingSet(
            outputByteCount: currentOutputByteCount,
            additionalRetainedByteCount: offsetCalculator.projectedAdditionalBytesForOffset(
                from: image,
                to: previousAcceptedImage,
            ),
            frameImages: frameImages + offsetCalculator.retainedImagesDuringOffset(
                from: image,
                to: previousAcceptedImage,
            ),
        )
        guard preRegistrationWorkingSet <= maxWorkingSetBytes else {
            return reachLimit(width: width, height: height)
        }

        let offset = offsetCalculator.offset(from: image, to: previousAcceptedImage)
        let postRegistrationWorkingSet = projectedWorkingSet(
            outputByteCount: currentOutputByteCount,
            additionalRetainedByteCount: 0,
            frameImages: frameImages + offsetCalculator.retainedImagesForMemoryAccounting,
        )
        guard postRegistrationWorkingSet <= maxWorkingSetBytes else {
            return reachLimit(width: width, height: height)
        }

        guard let offset,
              offset.horizontal.isFinite,
              offset.vertical.isFinite
        else {
            return .ignored(.registrationFailed)
        }

        let horizontalLimit = max(
            CGFloat(maximumHorizontalDrift),
            CGFloat(width) * maximumHorizontalDriftRatio,
        )
        guard abs(offset.horizontal) <= horizontalLimit else {
            return .ignored(.horizontalDrift)
        }

        let offsetPixels = Int(offset.vertical.rounded())
        if abs(offsetPixels) <= verticalNoiseTolerance {
            return .ignored(.noMovement)
        }
        guard offsetPixels > 0 else {
            return .ignored(.reverseMovement)
        }
        guard offsetPixels < image.height else {
            return .ignored(.discontinuousMovement)
        }

        return acceptDownwardFrame(
            image,
            offsetPixels: offsetPixels,
            width: width,
            destinationBytesPerRow: destinationBytesPerRow,
        )
    }

    private func acceptDownwardFrame(
        _ image: CGImage,
        offsetPixels: Int,
        width: Int,
        destinationBytesPerRow: Int,
    ) -> ScrollingStitcherStatus {
        let nextHeight = safeSum(height, offsetPixels)
        let nextPixelCount = safeProduct(nextHeight, width)
        let outputByteCount = safeProduct(destinationBytesPerRow, nextHeight)
        let stripBytesPerRow = bitmapBytesPerRow(for: image, width: image.width) ?? .max
        let stripByteCount = safeProduct(stripBytesPerRow, offsetPixels)
        var frameImages = [image]
        if let previousAcceptedImage {
            frameImages.append(previousAcceptedImage)
        }
        frameImages.append(contentsOf: offsetCalculator.retainedImagesForMemoryAccounting)
        let nextWorkingSet = projectedWorkingSet(
            outputByteCount: outputByteCount,
            additionalRetainedByteCount: stripByteCount,
            frameImages: frameImages,
        )

        guard nextPixelCount <= maxPixelCount, nextWorkingSet <= maxWorkingSetBytes else {
            return reachLimit(width: width, height: nextHeight)
        }

        guard let strip = copyBottomStrip(from: image, height: offsetPixels) else {
            return .ignored(.registrationFailed)
        }

        segments.append(Segment(image: strip))
        retainedSegmentImageIDs.insert(ObjectIdentifier(strip))
        previousAcceptedImage = image
        retainedByteCount = safeSum(retainedByteCount, estimatedByteCount(for: strip))
        height = nextHeight
        return .accepted
    }

    func finish() -> CGImage? {
        defer {
            releaseCapturedFrames()
            offsetCalculator.reset()
        }

        guard let width, height > 0, let reference = segments.first?.image else { return nil }
        guard let context = makeContext(reference: reference, width: width, height: height) else { return nil }
        context.interpolationQuality = .none

        var destinationY = height
        for segment in segments {
            destinationY -= segment.image.height
            let drawRect = CGRect(
                x: 0,
                y: destinationY,
                width: segment.image.width,
                height: segment.image.height,
            )
            context.draw(segment.image, in: drawRect)
        }

        return context.makeImage()
    }

    func reachedPixelLimitForTesting() -> Bool {
        didReachLimit
    }

    func retainedByteCountForTesting() -> Int {
        retainedByteCount
    }

    func retainedSegmentHeightsForTesting() -> [Int] {
        segments.map(\.image.height)
    }

    private func releaseCapturedFrames() {
        segments.removeAll(keepingCapacity: false)
        previousAcceptedImage = nil
        width = nil
        height = 0
        retainedByteCount = 0
        retainedSegmentImageIDs.removeAll(keepingCapacity: false)
        destinationBytesPerRow = nil
    }

    private func copyBottomStrip(from image: CGImage, height: Int) -> CGImage? {
        let cropRect = CGRect(x: 0, y: image.height - height, width: image.width, height: height)
        guard let croppedImage = image.cropping(to: cropRect),
              let context = makeContext(reference: image, width: image.width, height: height)
        else {
            return nil
        }
        context.interpolationQuality = .none
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: image.width, height: height))
        return context.makeImage()
    }

    private func estimatedByteCount(for image: CGImage) -> Int {
        safeProduct(image.bytesPerRow, image.height)
    }

    private func projectedWorkingSet(
        outputByteCount: Int,
        additionalRetainedByteCount: Int,
        frameImages: [CGImage],
    ) -> Int {
        var additionalImageIDs: Set<ObjectIdentifier> = []
        var frameByteCount = 0
        for image in frameImages {
            let imageID = ObjectIdentifier(image)
            guard !retainedSegmentImageIDs.contains(imageID),
                  additionalImageIDs.insert(imageID).inserted
            else {
                continue
            }
            frameByteCount = safeSum(frameByteCount, estimatedByteCount(for: image))
        }

        let segmentByteCount = safeSum(retainedByteCount, additionalRetainedByteCount)
        let retainedImageByteCount = safeSum(segmentByteCount, frameByteCount)
        return safeSum(retainedImageByteCount, outputByteCount)
    }

    private func reachLimit(width: Int, height: Int) -> ScrollingStitcherStatus {
        didReachLimit = true
        let dimensions = "\(width)x\(height)"
        AppLog.capture.warning(
            "Scrolling capture size limit reached at \(dimensions, privacy: .public)",
        )
        return .limitReached
    }

    private func safeProduct(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? .max : result.partialValue
    }

    private func safeSum(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }

    private func makeContext(reference image: CGImage, width: Int, height: Int) -> CGContext? {
        guard let bytesPerRow = bitmapBytesPerRow(for: image, width: width) else {
            return nil
        }
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue,
        )
    }
}

private func bitmapBytesPerRow(for image: CGImage, width: Int) -> Int? {
    guard width > 0, image.bitsPerPixel > 0 else { return nil }
    let bitCount = width.multipliedReportingOverflow(by: image.bitsPerPixel)
    guard !bitCount.overflow else { return nil }

    let wholeBytes = bitCount.partialValue / 8
    let partialByte = bitCount.partialValue % 8 == 0 ? 0 : 1
    let byteCount = wholeBytes.addingReportingOverflow(partialByte)
    return byteCount.overflow ? nil : byteCount.partialValue
}
