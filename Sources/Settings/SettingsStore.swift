import AppKit
import Foundation

final class SettingsStore: ObservableObject {
    @Published var autoLaunchEnabled: Bool {
        didSet { defaults.set(autoLaunchEnabled, forKey: Keys.autoLaunchEnabled) }
    }

    @Published var menuBarIconHidden: Bool {
        didSet { defaults.set(menuBarIconHidden, forKey: Keys.menuBarIconHidden) }
    }

    @Published var showSelectionCoordinates: Bool {
        didSet { defaults.set(showSelectionCoordinates, forKey: Keys.showSelectionCoordinates) }
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

    @Published var previewAutoDismissBehavior: PreviewAutoDismissBehavior {
        didSet { defaults.set(previewAutoDismissBehavior.rawValue, forKey: Keys.previewAutoDismissBehavior) }
    }

    @Published var previewReplacementBehavior: PreviewReplacementBehavior {
        didSet { defaults.set(previewReplacementBehavior.rawValue, forKey: Keys.previewReplacementBehavior) }
    }

    @Published var previewDisabledOutputBehavior: PreviewDisabledOutputBehavior {
        didSet { defaults.set(previewDisabledOutputBehavior.rawValue, forKey: Keys.previewDisabledOutputBehavior) }
    }

    @Published var selectionDimmingMode: SelectionDimmingMode {
        didSet { defaults.set(selectionDimmingMode.rawValue, forKey: Keys.selectionDimmingMode) }
    }

    @Published var selectionDimmingColorHex: String {
        didSet { defaults.set(selectionDimmingColorHex, forKey: Keys.selectionDimmingColorHex) }
    }

    @Published var selectionVisualCue: SelectionVisualCue {
        didSet { defaults.set(selectionVisualCue.rawValue, forKey: Keys.selectionVisualCue) }
    }

    @Published var autoCopyToClipboard: Bool {
        didSet { defaults.set(autoCopyToClipboard, forKey: Keys.autoCopyToClipboard) }
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

    var selectionDimmingColor: NSColor {
        get {
            ColorHexCodec.nsColor(from: selectionDimmingColorHex) ?? ColorHexCodec.defaultSelectionDimmingColor
        }
        set {
            selectionDimmingColorHex = ColorHexCodec.hex(from: newValue)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        autoLaunchEnabled = defaults.object(forKey: Keys.autoLaunchEnabled) as? Bool ?? false
        menuBarIconHidden = defaults.object(forKey: Keys.menuBarIconHidden) as? Bool ?? false
        showSelectionCoordinates = defaults.object(forKey: Keys.showSelectionCoordinates) as? Bool ?? true
        saveDelaySeconds = Self.loadSaveDelaySeconds(from: defaults)
        previewTimeoutEnabled = defaults.object(forKey: Keys.previewTimeoutEnabled) as? Bool ?? true
        previewEnabled = defaults.object(forKey: Keys.previewEnabled) as? Bool ?? true
        previewAutoDismissBehavior = Self.loadPreviewAutoDismissBehavior(from: defaults)
        previewReplacementBehavior = Self.loadPreviewReplacementBehavior(from: defaults)
        previewDisabledOutputBehavior = Self.loadPreviewDisabledOutputBehavior(from: defaults)
        selectionDimmingMode = Self.loadSelectionDimmingMode(from: defaults)
        selectionDimmingColorHex = Self.loadSelectionDimmingColorHex(from: defaults)
        selectionVisualCue = Self.loadSelectionVisualCue(from: defaults)
        autoCopyToClipboard = defaults.object(forKey: Keys.autoCopyToClipboard) as? Bool ?? true
        saveLocationOption = Self.loadSaveLocationOption(from: defaults)
        customSavePath = defaults.string(forKey: Keys.customSavePath) ?? ""
        filenamePrefix = defaults.string(forKey: Keys.filenamePrefix) ?? "screenshot"

        hotkeySelection = loadHotkey(
            keyCodeKey: Keys.hotkeySelectionKeyCode,
            modifiersKey: Keys.hotkeySelectionModifiers,
            legacyKey: LegacyKeys.hotkeySelection,
            defaultValue: nil,
        )
        hotkeyFullScreen = loadHotkey(
            keyCodeKey: Keys.hotkeyFullScreenKeyCode,
            modifiersKey: Keys.hotkeyFullScreenModifiers,
            legacyKey: LegacyKeys.hotkeyFullScreen,
            defaultValue: nil,
        )
        hotkeyWindow = loadHotkey(
            keyCodeKey: Keys.hotkeyWindowKeyCode,
            modifiersKey: Keys.hotkeyWindowModifiers,
            legacyKey: LegacyKeys.hotkeyWindow,
            defaultValue: nil,
        )
    }
}

private extension SettingsStore {
    typealias PreviewDisabledBehavior = PreviewDisabledOutputBehavior

    static func loadSaveDelaySeconds(from defaults: UserDefaults) -> Double {
        if let saveDelay = defaults.object(forKey: Keys.saveDelaySeconds) as? Double {
            return saveDelay
        }
        if let legacyDelay = defaults.object(forKey: LegacyKeys.previewTimeoutSeconds) as? Double {
            defaults.removeObject(forKey: LegacyKeys.previewTimeoutSeconds)
            return legacyDelay
        }
        return 7
    }

    static func loadSelectionDimmingColorHex(from defaults: UserDefaults) -> String {
        let dimmingColorRaw = defaults.string(forKey: Keys.selectionDimmingColorHex) ?? ""
        return ColorHexCodec.normalized(dimmingColorRaw) ?? ColorHexCodec.defaultSelectionDimmingColorHex
    }

    static func loadPreviewAutoDismissBehavior(from defaults: UserDefaults) -> PreviewAutoDismissBehavior {
        loadEnum(
            PreviewAutoDismissBehavior.self,
            from: defaults,
            key: Keys.previewAutoDismissBehavior,
            defaultValue: .saveToDisk,
        )
    }

    static func loadPreviewReplacementBehavior(from defaults: UserDefaults) -> PreviewReplacementBehavior {
        loadEnum(
            PreviewReplacementBehavior.self,
            from: defaults,
            key: Keys.previewReplacementBehavior,
            defaultValue: .saveImmediately,
        )
    }

    static func loadPreviewDisabledOutputBehavior(from defaults: UserDefaults) -> PreviewDisabledBehavior {
        loadEnum(
            PreviewDisabledOutputBehavior.self,
            from: defaults,
            key: Keys.previewDisabledOutputBehavior,
            defaultValue: .saveToDisk,
        )
    }

    static func loadSelectionDimmingMode(from defaults: UserDefaults) -> SelectionDimmingMode {
        loadEnum(
            SelectionDimmingMode.self,
            from: defaults,
            key: Keys.selectionDimmingMode,
            defaultValue: .fullScreen,
        )
    }

    static func loadSelectionVisualCue(from defaults: UserDefaults) -> SelectionVisualCue {
        loadEnum(
            SelectionVisualCue.self,
            from: defaults,
            key: Keys.selectionVisualCue,
            defaultValue: .none,
        )
    }

    static func loadSaveLocationOption(from defaults: UserDefaults) -> SaveLocationOption {
        loadEnum(
            SaveLocationOption.self,
            from: defaults,
            key: Keys.saveLocationOption,
            defaultValue: .downloads,
        )
    }

    static func loadEnum<T: RawRepresentable>(
        _: T.Type,
        from defaults: UserDefaults,
        key: String,
        defaultValue: T,
    ) -> T where T.RawValue == String {
        let rawValue = defaults.string(forKey: key) ?? defaultValue.rawValue
        return T(rawValue: rawValue) ?? defaultValue
    }

    func loadHotkey(
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

    func storedHotkey(keyCodeKey: String, modifiersKey: String) -> Hotkey? {
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

    func modifierRawValue(forKey key: String) -> UInt {
        if let value = defaults.object(forKey: key) as? UInt {
            return value
        }
        if let value = defaults.object(forKey: key) as? Int {
            return UInt(value)
        }
        return UInt(defaults.integer(forKey: key))
    }

    func persistHotkey(_ hotkey: Hotkey?, keyCodeKey: String, modifiersKey: String) {
        if let hotkey {
            defaults.set(Int(hotkey.keyCode), forKey: keyCodeKey)
            defaults.set(Int(hotkey.modifiers.rawValue), forKey: modifiersKey)
        } else {
            defaults.set(SettingsStore.unsetKeyCodeSentinel, forKey: keyCodeKey)
            defaults.set(0, forKey: modifiersKey)
        }
    }

    static let unsetKeyCodeSentinel = -1
}

private enum Keys {
    static let autoLaunchEnabled = "settings.autoLaunchEnabled"
    static let menuBarIconHidden = "settings.menuBarIconHidden"
    static let showSelectionCoordinates = "settings.showSelectionCoordinates"
    static let saveDelaySeconds = "settings.saveDelaySeconds"
    static let previewTimeoutEnabled = "settings.previewTimeoutEnabled"
    static let previewEnabled = "settings.previewEnabled"
    static let previewAutoDismissBehavior = "settings.previewAutoDismissBehavior"
    static let previewReplacementBehavior = "settings.previewReplacementBehavior"
    static let previewDisabledOutputBehavior = "settings.previewDisabledOutputBehavior"
    static let selectionDimmingMode = "settings.selectionDimmingMode"
    static let selectionDimmingColorHex = "settings.selectionDimmingColorHex"
    static let selectionVisualCue = "settings.selectionVisualCue"
    static let autoCopyToClipboard = "settings.autoCopyToClipboard"
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
