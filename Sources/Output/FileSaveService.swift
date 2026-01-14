import AppKit

enum FileSaveService {
    static func save(image: NSImage, to directory: URL, filename: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "OpenShot.FileSaveService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG data."])
        }

        try pngData.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
