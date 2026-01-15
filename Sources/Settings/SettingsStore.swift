import AppKit
import Carbon.HIToolbox
import Foundation

enum SaveLocationOption: String, CaseIterable, Identifiable {
    case downloads
    case desktop
    case documents
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloads: "Downloads"
        case .desktop: "Desktop"
        case .documents: "Documents"
        case .custom: "Custom"
        }
    }
}

enum PreviewReplacementBehavior: String, CaseIterable, Identifiable {
    case saveImmediately
    case discard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveImmediately:
            "Save previous capture"
        case .discard:
            "Discard previous capture"
        }
    }

    var helpText: String {
        switch self {
        case .saveImmediately:
            "Save the previous capture to disk immediately, then replace the preview."
        case .discard:
            "Cancel the previous capture without saving, then replace the preview."
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

    @Published var previewReplacementBehavior: PreviewReplacementBehavior {
        didSet { defaults.set(previewReplacementBehavior.rawValue, forKey: Keys.previewReplacementBehavior) }
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

    @Published var hotkeySelection: Hotkey? {
        didSet {
            persistHotkey(
                hotkeySelection,
                keyCodeKey: Keys.hotkeySelectionKeyCode,
                modifiersKey: Keys.hotkeySelectionModifiers,
            )
        }
    }

    @Published var hotkeyFullScreen: Hotkey? {
        didSet {
            persistHotkey(
                hotkeyFullScreen,
                keyCodeKey: Keys.hotkeyFullScreenKeyCode,
                modifiersKey: Keys.hotkeyFullScreenModifiers,
            )
        }
    }

    @Published var hotkeyWindow: Hotkey? {
        didSet {
            persistHotkey(
                hotkeyWindow,
                keyCodeKey: Keys.hotkeyWindowKeyCode,
                modifiersKey: Keys.hotkeyWindowModifiers,
            )
        }
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
        let replacementRaw = defaults.string(forKey: Keys.previewReplacementBehavior)
            ?? PreviewReplacementBehavior.saveImmediately.rawValue
        previewReplacementBehavior = PreviewReplacementBehavior(rawValue: replacementRaw) ?? .saveImmediately

        let locationRaw = defaults.string(forKey: Keys.saveLocationOption) ?? SaveLocationOption.downloads.rawValue
        saveLocationOption = SaveLocationOption(rawValue: locationRaw) ?? .downloads

        customSavePath = defaults.string(forKey: Keys.customSavePath) ?? ""
        filenamePrefix = defaults.string(forKey: Keys.filenamePrefix) ?? "screenshot"

        hotkeySelection = loadHotkey(
            keyCodeKey: Keys.hotkeySelectionKeyCode,
            modifiersKey: Keys.hotkeySelectionModifiers,
            legacyKey: LegacyKeys.hotkeySelection,
            defaultValue: SettingsStore.defaultHotkeySelection,
        )
        hotkeyFullScreen = loadHotkey(
            keyCodeKey: Keys.hotkeyFullScreenKeyCode,
            modifiersKey: Keys.hotkeyFullScreenModifiers,
            legacyKey: LegacyKeys.hotkeyFullScreen,
            defaultValue: SettingsStore.defaultHotkeyFullScreen,
        )
        hotkeyWindow = loadHotkey(
            keyCodeKey: Keys.hotkeyWindowKeyCode,
            modifiersKey: Keys.hotkeyWindowModifiers,
            legacyKey: LegacyKeys.hotkeyWindow,
            defaultValue: nil,
        )
    }

    private func loadHotkey(
        keyCodeKey: String,
        modifiersKey: String,
        legacyKey: String?,
        defaultValue: Hotkey?,
    ) -> Hotkey? {
        if defaults.object(forKey: keyCodeKey) != nil {
            return storedHotkey(keyCodeKey: keyCodeKey, modifiersKey: modifiersKey)
        }

        if let legacyKey, let legacyValue = defaults.string(forKey: legacyKey) {
            let parsed = HotkeyParser.parse(legacyValue)
            defaults.removeObject(forKey: legacyKey)
            if let parsed {
                persistHotkey(parsed, keyCodeKey: keyCodeKey, modifiersKey: modifiersKey)
                return parsed
            }
        }

        return defaultValue
    }

    private func storedHotkey(keyCodeKey: String, modifiersKey: String) -> Hotkey? {
        guard let keyCodeValue = defaults.object(forKey: keyCodeKey) else {
            return nil
        }

        let keyCodeInt = if let intValue = keyCodeValue as? Int {
            intValue
        } else if let uintValue = keyCodeValue as? UInt {
            Int(uintValue)
        } else {
            defaults.integer(forKey: keyCodeKey)
        }

        if keyCodeInt < 0 || keyCodeInt > Int(UInt16.max) {
            return nil
        }

        let keyCode = UInt16(keyCodeInt)
        let rawValue = modifierRawValue(forKey: modifiersKey)
        return Hotkey(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: rawValue))
    }

    private func modifierRawValue(forKey key: String) -> UInt {
        if let value = defaults.object(forKey: key) as? UInt {
            return value
        }
        if let value = defaults.object(forKey: key) as? Int {
            return UInt(value)
        }
        return UInt(defaults.integer(forKey: key))
    }

    private func persistHotkey(_ hotkey: Hotkey?, keyCodeKey: String, modifiersKey: String) {
        if let hotkey {
            defaults.set(Int(hotkey.keyCode), forKey: keyCodeKey)
            defaults.set(Int(hotkey.modifiers.rawValue), forKey: modifiersKey)
        } else {
            defaults.set(SettingsStore.unsetKeyCodeSentinel, forKey: keyCodeKey)
            defaults.set(0, forKey: modifiersKey)
        }
    }

    private static let unsetKeyCodeSentinel = -1
    private static let defaultHotkeySelection = Hotkey(
        keyCode: UInt16(kVK_ANSI_P),
        modifiers: [.control],
    )
    private static let defaultHotkeyFullScreen = Hotkey(
        keyCode: UInt16(kVK_ANSI_P),
        modifiers: [.control, .shift],
    )
}

private enum Keys {
    static let autoLaunchEnabled = "settings.autoLaunchEnabled"
    static let saveDelaySeconds = "settings.saveDelaySeconds"
    static let previewTimeoutEnabled = "settings.previewTimeoutEnabled"
    static let previewEnabled = "settings.previewEnabled"
    static let previewReplacementBehavior = "settings.previewReplacementBehavior"
    static let saveLocationOption = "settings.saveLocationOption"
    static let customSavePath = "settings.customSavePath"
    static let filenamePrefix = "settings.filenamePrefix"
    static let hotkeySelectionKeyCode = "settings.hotkeySelection.keyCode"
    static let hotkeySelectionModifiers = "settings.hotkeySelection.modifiers"
    static let hotkeyFullScreenKeyCode = "settings.hotkeyFullScreen.keyCode"
    static let hotkeyFullScreenModifiers = "settings.hotkeyFullScreen.modifiers"
    static let hotkeyWindowKeyCode = "settings.hotkeyWindow.keyCode"
    static let hotkeyWindowModifiers = "settings.hotkeyWindow.modifiers"
}

private enum LegacyKeys {
    static let previewTimeoutSeconds = "settings.previewTimeoutSeconds"
    static let hotkeySelection = "settings.hotkeySelection"
    static let hotkeyFullScreen = "settings.hotkeyFullScreen"
    static let hotkeyWindow = "settings.hotkeyWindow"
}
