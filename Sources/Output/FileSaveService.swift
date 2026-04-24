import AppKit

enum FileSaveService {
    static func save(image: NSImage, to directory: URL, filename: String) throws -> URL {
        let pngData = try PNGDataEncoder.encode(image: image)
        return try save(pngData: pngData, to: directory, filename: filename)
    }

    static func save(pngData: Data, to directory: URL, filename: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = uniqueURL(for: filename, in: directory)
        try pngData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    static func uniqueURL(
        for filename: String,
        in directory: URL,
        fileManager: FileManager = .default,
    ) -> URL {
        let originalURL = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: originalURL.path) else {
            return originalURL
        }

        let nsFilename = filename as NSString
        let basename = nsFilename.deletingPathExtension
        let pathExtension = nsFilename.pathExtension

        for index in 2 ... 99 {
            let candidateName = filenameWithSuffix(
                basename: basename,
                pathExtension: pathExtension,
                suffix: "-\(index)",
            )
            let candidateURL = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        let fallbackName = filenameWithSuffix(
            basename: basename,
            pathExtension: pathExtension,
            suffix: "-\(UUID().uuidString.prefix(8))",
        )
        return directory.appendingPathComponent(fallbackName)
    }

    private static func filenameWithSuffix(
        basename: String,
        pathExtension: String,
        suffix: String,
    ) -> String {
        guard !pathExtension.isEmpty else {
            return "\(basename)\(suffix)"
        }
        return "\(basename)\(suffix).\(pathExtension)"
    }
}
