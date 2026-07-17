import CoreGraphics

struct CaptureLayoutInput: Equatable {
    let pointRect: CGRect
    let nativeScale: CGFloat
    let pixelSize: CGSize
}

struct CapturedPiece {
    let image: CGImage
    let pointRect: CGRect
    let nativeScale: CGFloat
}

struct CaptureLayoutPlacement: Equatable {
    let pointRect: CGRect
    let pixelRect: CGRect
}

struct CaptureLayout: Equatable {
    let pointBounds: CGRect
    let outputScale: CGFloat
    let pixelSize: CGSize
    let placements: [CaptureLayoutPlacement]

    static func make(inputs: [CaptureLayoutInput]) -> CaptureLayout? {
        guard let first = inputs.first,
              inputs.allSatisfy({ input in
                  !input.pointRect.isNull
                      && !input.pointRect.isEmpty
                      && input.nativeScale.isFinite
                      && input.nativeScale > 0
                      && input.pixelSize.width > 0
                      && input.pixelSize.height > 0
              })
        else {
            return nil
        }

        let pointBounds = inputs.dropFirst().reduce(first.pointRect) { bounds, input in
            bounds.union(input.pointRect)
        }
        let outputScale = inputs.reduce(first.nativeScale) { scale, input in
            max(scale, input.nativeScale)
        }
        guard pointBounds.width.isFinite,
              pointBounds.height.isFinite,
              pointBounds.width > 0,
              pointBounds.height > 0
        else {
            return nil
        }

        let pixelWidth = outerPixelEdge(pointBounds.width, scale: outputScale)
        let pixelHeight = outerPixelEdge(pointBounds.height, scale: outputScale)
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let placements = inputs.map { input in
            let left = innerPixelEdge(input.pointRect.minX - pointBounds.minX, scale: outputScale)
            let right = input.pointRect.maxX == pointBounds.maxX
                ? pixelWidth
                : innerPixelEdge(input.pointRect.maxX - pointBounds.minX, scale: outputScale)

            // Screens use AppKit's bottom-left point coordinates, while captured images
            // are composed in top-to-bottom display order.
            let topDistance = pointBounds.maxY - input.pointRect.maxY
            let bottomDistance = pointBounds.maxY - input.pointRect.minY
            let top = innerPixelEdge(topDistance, scale: outputScale)
            let bottom = input.pointRect.minY == pointBounds.minY
                ? pixelHeight
                : innerPixelEdge(bottomDistance, scale: outputScale)

            return CaptureLayoutPlacement(
                pointRect: input.pointRect,
                pixelRect: CGRect(
                    x: left,
                    y: pixelHeight - bottom,
                    width: max(0, right - left),
                    height: max(0, bottom - top),
                ),
            )
        }

        return CaptureLayout(
            pointBounds: pointBounds,
            outputScale: outputScale,
            pixelSize: CGSize(width: pixelWidth, height: pixelHeight),
            placements: placements,
        )
    }

    private static func innerPixelEdge(_ pointDistance: CGFloat, scale: CGFloat) -> CGFloat {
        (pointDistance * scale).rounded(.down)
    }

    private static func outerPixelEdge(_ pointDistance: CGFloat, scale: CGFloat) -> CGFloat {
        (pointDistance * scale).rounded(.up)
    }
}

enum CaptureCompositor {
    static func composite(_ pieces: [CapturedPiece]) -> CGImage? {
        guard let first = pieces.first,
              let layout = CaptureLayout.make(inputs: pieces.map { piece in
                  CaptureLayoutInput(
                      pointRect: piece.pointRect,
                      nativeScale: piece.nativeScale,
                      pixelSize: CGSize(width: piece.image.width, height: piece.image.height),
                  )
              })
        else {
            return nil
        }

        let width = max(1, Int(layout.pixelSize.width))
        let height = max(1, Int(layout.pixelSize.height))
        let colorSpace = first.image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: first.image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: first.image.bitmapInfo.rawValue,
        ) else {
            return nil
        }
        context.interpolationQuality = .none

        for (piece, placement) in zip(pieces, layout.placements) where !placement.pixelRect.isEmpty {
            context.draw(piece.image, in: placement.pixelRect)
        }

        return context.makeImage()
    }
}

enum ScrollingCapturePreflightResult: Equatable, Sendable {
    case ready
    case invalidSelection
    case multipleDisplays
}

enum ScrollingCapturePreflight {
    static func evaluate(rect: CGRect, screenFrames: [CGRect]) -> ScrollingCapturePreflightResult {
        guard rect.width.isFinite,
              rect.height.isFinite,
              !rect.isNull,
              !rect.isEmpty
        else {
            return .invalidSelection
        }

        let intersectingDisplayCount = screenFrames.reduce(into: 0) { count, frame in
            let intersection = rect.intersection(frame)
            if !intersection.isNull, intersection.width > 0, intersection.height > 0 {
                count += 1
            }
        }

        switch intersectingDisplayCount {
        case 1:
            return .ready
        case 2...:
            return .multipleDisplays
        default:
            return .invalidSelection
        }
    }
}
