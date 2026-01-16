import AppKit
import ImageIO
import UniformTypeIdentifiers

enum PNGDataEncoder {
    static func encode(cgImage: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil,
        ) else {
            throw NSError(
                domain: "OneShot.PNGDataEncoder",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG destination."],
            )
        }

        let options = pngOptions(for: cgImage)
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(
                domain: "OneShot.PNGDataEncoder",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG data."],
            )
        }

        return data as Data
    }

    static func encode(image: NSImage) throws -> Data {
        if let cgImage = bestCGImage(from: image) {
            return try encode(cgImage: cgImage)
        }

        throw NSError(
            domain: "OneShot.PNGDataEncoder",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Failed to extract CGImage from NSImage."],
        )
    }

    private static func bestCGImage(from image: NSImage) -> CGImage? {
        let bitmapReps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        if let bestRep = bitmapReps.max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }),
           let cgImage = bestRep.cgImage
        {
            return cgImage
        }

        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private static func pngOptions(for cgImage: CGImage) -> [CFString: Any] {
        var properties: [CFString: Any] = [
            kCGImagePropertyPixelWidth: cgImage.width,
            kCGImagePropertyPixelHeight: cgImage.height,
            kCGImagePropertyDepth: cgImage.bitsPerComponent,
            kCGImagePropertyOrientation: 1,
            kCGImagePropertyHasAlpha: hasAlpha(for: cgImage),
            kCGImagePropertyIsFloat: cgImage.bitmapInfo.contains(.floatComponents),
            kCGImagePropertyIsIndexed: isIndexedColorSpace(for: cgImage),
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGInterlaceType: 0,
                kCGImagePropertyPNGCompressionFilter: IMAGEIO_PNG_NO_FILTERS,
            ],
        ]

        if let colorModel = colorModelProperty(for: cgImage) {
            properties[kCGImagePropertyColorModel] = colorModel
        }

        return properties
    }

    private static func colorModelProperty(for cgImage: CGImage) -> CFString? {
        guard let colorSpace = cgImage.colorSpace else { return nil }
        switch colorSpace.model {
        case .rgb:
            return kCGImagePropertyColorModelRGB
        case .monochrome:
            return kCGImagePropertyColorModelGray
        case .cmyk:
            return kCGImagePropertyColorModelCMYK
        case .lab:
            return kCGImagePropertyColorModelLab
        default:
            return nil
        }
    }

    private static func hasAlpha(for cgImage: CGImage) -> Bool {
        switch cgImage.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            return true
        }
    }

    private static func isIndexedColorSpace(for cgImage: CGImage) -> Bool {
        guard let colorSpace = cgImage.colorSpace else { return false }
        return colorSpace.model == .indexed
    }
}
