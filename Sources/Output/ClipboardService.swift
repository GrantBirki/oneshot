import AppKit
import ImageIO
import UniformTypeIdentifiers

enum ClipboardError: LocalizedError, Sendable {
    case writeFailed

    var errorDescription: String? {
        "The screenshot could not be copied to the clipboard."
    }
}

enum ClipboardService {
    @MainActor
    static func copy(pngData: Data, to pasteboard: NSPasteboard = .general) async throws {
        let tiffData = await makeTIFFData(from: pngData)
        pasteboard.clearContents()
        var types: [NSPasteboard.PasteboardType] = [.png]
        if tiffData != nil {
            types.append(.tiff)
        }
        pasteboard.declareTypes(types, owner: nil)
        guard pasteboard.setData(pngData, forType: .png) else {
            throw ClipboardError.writeFailed
        }
        if let tiffData, !pasteboard.setData(tiffData, forType: .tiff) {
            throw ClipboardError.writeFailed
        }
    }

    private static func makeTIFFData(from pngData: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard
                let source = CGImageSourceCreateWithData(pngData as CFData, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                return nil
            }

            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                data,
                UTType.tiff.identifier as CFString,
                1,
                nil,
            ) else {
                return nil
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return data as Data
        }.value
    }
}
