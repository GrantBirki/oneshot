import Foundation

enum SaveLocationResolver {
    static func resolve(option: SaveLocationOption, customPath: String) -> URL {
        let fileManager = FileManager.default
        let defaultURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

        switch option {
        case .downloads:
            return defaultURL
        case .desktop:
            return fileManager.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        case .documents:
            return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .custom:
            return customDirectory(path: customPath) ?? defaultURL
        }
    }

    static func customDirectory(path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let expanded = (trimmed as NSString).expandingTildeInPath
        guard (expanded as NSString).isAbsolutePath else { return nil }

        return URL(fileURLWithPath: expanded, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }
}
