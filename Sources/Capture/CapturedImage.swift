import AppKit

struct CapturedImage {
    let previewImage: NSImage
    let pngData: Data

    init(
        cgImage: CGImage,
        displaySize: NSSize,
        encoder: (CGImage) throws -> Data = PNGDataEncoder.encode
    ) throws {
        previewImage = NSImage(cgImage: cgImage, size: displaySize)
        pngData = try encoder(cgImage)
    }
}
