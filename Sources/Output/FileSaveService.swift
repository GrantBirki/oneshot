import AppKit

enum FileSaveService {
    static func save(image: NSImage, to directory: URL, filename: String) throws -> URL {
        let pngData = try PNGDataEncoder.encode(image: image)
        return try save(pngData: pngData, to: directory, filename: filename)
    }

    static func save(pngData: Data, to directory: URL, filename: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try pngData.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
