import Foundation

enum SaveLocationResolver {
    static func resolve(option: SaveLocationOption, customPath: String) -> URL {
        let fileManager = FileManager.default

        switch option {
        case .downloads:
            return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        case .desktop:
            return fileManager.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        case .documents:
            return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .custom:
            let customURL = URL(fileURLWithPath: customPath)
            if customPath.isEmpty {
                return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            }
            return customURL
        }
    }
}
