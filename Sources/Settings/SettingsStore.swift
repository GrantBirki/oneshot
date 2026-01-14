import Foundation

enum SaveLocationOption: String, CaseIterable, Identifiable {
    case downloads
    case desktop
    case documents
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloads: return "Downloads"
        case .desktop: return "Desktop"
        case .documents: return "Documents"
        case .custom: return "Custom"
        }
    }
}

final class SettingsStore: ObservableObject {
    @Published var autoLaunchEnabled: Bool {
        didSet { defaults.set(autoLaunchEnabled, forKey: Keys.autoLaunchEnabled) }
    }

    @Published var saveDelaySeconds: Double {
        didSet { defaults.set(saveDelaySeconds, forKey: Keys.saveDelaySeconds) }
    }

    @Published var previewTimeoutEnabled: Bool {
        didSet { defaults.set(previewTimeoutEnabled, forKey: Keys.previewTimeoutEnabled) }
    }

    @Published var previewEnabled: Bool {
        didSet { defaults.set(previewEnabled, forKey: Keys.previewEnabled) }
    }

    @Published var saveLocationOption: SaveLocationOption {
        didSet { defaults.set(saveLocationOption.rawValue, forKey: Keys.saveLocationOption) }
    }

    @Published var customSavePath: String {
        didSet { defaults.set(customSavePath, forKey: Keys.customSavePath) }
    }

    @Published var filenamePrefix: String {
        didSet { defaults.set(filenamePrefix, forKey: Keys.filenamePrefix) }
    }

    @Published var hotkeySelection: String {
        didSet { defaults.set(hotkeySelection, forKey: Keys.hotkeySelection) }
    }

    @Published var hotkeyFullScreen: String {
        didSet { defaults.set(hotkeyFullScreen, forKey: Keys.hotkeyFullScreen) }
    }

    @Published var hotkeyWindow: String {
        didSet { defaults.set(hotkeyWindow, forKey: Keys.hotkeyWindow) }
    }

    var previewTimeout: TimeInterval? {
        previewTimeoutEnabled ? saveDelaySeconds : nil
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        autoLaunchEnabled = defaults.object(forKey: Keys.autoLaunchEnabled) as? Bool ?? false
        if let saveDelay = defaults.object(forKey: Keys.saveDelaySeconds) as? Double {
            saveDelaySeconds = saveDelay
        } else if let legacyDelay = defaults.object(forKey: LegacyKeys.previewTimeoutSeconds) as? Double {
            saveDelaySeconds = legacyDelay
            defaults.removeObject(forKey: LegacyKeys.previewTimeoutSeconds)
        } else {
            saveDelaySeconds = 7
        }
        previewTimeoutEnabled = defaults.object(forKey: Keys.previewTimeoutEnabled) as? Bool ?? true
        previewEnabled = defaults.object(forKey: Keys.previewEnabled) as? Bool ?? true

        let locationRaw = defaults.string(forKey: Keys.saveLocationOption) ?? SaveLocationOption.downloads.rawValue
        saveLocationOption = SaveLocationOption(rawValue: locationRaw) ?? .downloads

        customSavePath = defaults.string(forKey: Keys.customSavePath) ?? ""
        filenamePrefix = defaults.string(forKey: Keys.filenamePrefix) ?? "screenshot"

        hotkeySelection = defaults.string(forKey: Keys.hotkeySelection) ?? "ctrl+p"
        hotkeyFullScreen = defaults.string(forKey: Keys.hotkeyFullScreen) ?? "ctrl+shift+p"
        hotkeyWindow = defaults.string(forKey: Keys.hotkeyWindow) ?? ""
    }
}

private enum Keys {
    static let autoLaunchEnabled = "settings.autoLaunchEnabled"
    static let saveDelaySeconds = "settings.saveDelaySeconds"
    static let previewTimeoutEnabled = "settings.previewTimeoutEnabled"
    static let previewEnabled = "settings.previewEnabled"
    static let saveLocationOption = "settings.saveLocationOption"
    static let customSavePath = "settings.customSavePath"
    static let filenamePrefix = "settings.filenamePrefix"
    static let hotkeySelection = "settings.hotkeySelection"
    static let hotkeyFullScreen = "settings.hotkeyFullScreen"
    static let hotkeyWindow = "settings.hotkeyWindow"
}

private enum LegacyKeys {
    static let previewTimeoutSeconds = "settings.previewTimeoutSeconds"
}
