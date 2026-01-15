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
            nil
        ) else {
            throw NSError(
                domain: "OneShot.PNGDataEncoder",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG destination."]
            )
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(
                domain: "OneShot.PNGDataEncoder",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG data."]
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
            userInfo: [NSLocalizedDescriptionKey: "Failed to extract CGImage from NSImage."]
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
}
