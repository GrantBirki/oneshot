import AppKit
import Combine
import Foundation

private typealias Keys = SettingsStoreKeys
private typealias LegacyKeys = SettingsStoreLegacyKeys

final class SettingsStore: ObservableObject {
    static let defaultSaveDelaySeconds: Double = 7
    static let maximumSaveDelaySeconds: Double = 3600

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
        didSet { persistSaveDelaySeconds() }
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

    @Published var shutterSoundEnabled: Bool {
        didSet { defaults.set(shutterSoundEnabled, forKey: Keys.shutterSoundEnabled) }
    }

    @Published var shutterSound: ShutterSoundOption {
        didSet { defaults.set(shutterSound.rawValue, forKey: Keys.shutterSound) }
    }

    @Published var shutterSoundVolume: Double {
        didSet { persistShutterSoundVolume() }
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

    @Published var hotkeyScrolling: Hotkey? {
        didSet {
            persistHotkey(
                hotkeyScrolling,
                keyCodeKey: Keys.hotkeyScrollingKeyCode,
                modifiersKey: Keys.hotkeyScrollingModifiers,
            )
        }
    }

    @Published private(set) var hotkeyRegistrationStatuses: [HotkeyAction: HotkeyRegistrationStatus] = [:]
    @Published private(set) var hotkeyAssignmentErrors: [HotkeyAction: HotkeyAssignmentResult] = [:]
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .unknown
    @Published private(set) var launchAtLoginMessage: String?

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

    var hotkeyConfiguration: HotkeyConfiguration {
        HotkeyConfiguration(
            selection: hotkeySelection,
            scrolling: hotkeyScrolling,
            window: hotkeyWindow,
            fullScreen: hotkeyFullScreen,
        )
    }

    var hotkeyConfigurationPublisher: AnyPublisher<HotkeyConfiguration, Never> {
        Publishers.CombineLatest4(
            $hotkeySelection,
            $hotkeyScrolling,
            $hotkeyWindow,
            $hotkeyFullScreen,
        )
        .map { selection, scrolling, window, fullScreen in
            HotkeyConfiguration(
                selection: selection,
                scrolling: scrolling,
                window: window,
                fullScreen: fullScreen,
            )
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var usesClipboardOnlyOutput: Bool {
        !previewEnabled && previewDisabledOutputBehavior == .clipboardOnly
    }

    var usesDiskOutput: Bool {
        !usesClipboardOnlyOutput
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
        shutterSoundEnabled = defaults.object(forKey: Keys.shutterSoundEnabled) as? Bool ?? true
        shutterSound = Self.loadShutterSoundOption(from: defaults)
        shutterSoundVolume = Self.loadShutterSoundVolume(from: defaults)

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
        hotkeyScrolling = loadHotkey(
            keyCodeKey: Keys.hotkeyScrollingKeyCode,
            modifiersKey: Keys.hotkeyScrollingModifiers,
            legacyKey: nil,
            defaultValue: nil,
        )
    }

    @discardableResult
    func setHotkey(_ hotkey: Hotkey?, for action: HotkeyAction) -> HotkeyAssignmentResult {
        if let hotkey,
           let duplicate = hotkeyConfiguration.duplicateAction(for: hotkey, excluding: action)
        {
            let result = HotkeyAssignmentResult.duplicate(duplicate)
            hotkeyAssignmentErrors[action] = result
            return result
        }

        hotkeyAssignmentErrors.removeAll()
        switch action {
        case .selection:
            hotkeySelection = hotkey
        case .scrolling:
            hotkeyScrolling = hotkey
        case .window:
            hotkeyWindow = hotkey
        case .fullScreen:
            hotkeyFullScreen = hotkey
        }
        return .accepted
    }

    func updateHotkeyRegistrationStatuses(_ statuses: [HotkeyAction: HotkeyRegistrationStatus]) {
        hotkeyRegistrationStatuses = statuses
    }

    func hotkeyMessage(for action: HotkeyAction) -> String? {
        if case let .duplicate(duplicate)? = hotkeyAssignmentErrors[action] {
            return "This shortcut is already used for \(duplicate.title.lowercased())."
        }
        return hotkeyRegistrationStatuses[action]?.message
    }

    func applyLaunchAtLoginResult(_ result: LaunchAtLoginUpdateResult) {
        launchAtLoginStatus = result.status

        switch result {
        case let .enabled(changed):
            if changed {
                launchAtLoginMessage = nil
            }
            if !autoLaunchEnabled {
                autoLaunchEnabled = true
            }
        case let .disabled(changed):
            if changed {
                launchAtLoginMessage = nil
            }
            if autoLaunchEnabled {
                autoLaunchEnabled = false
            }
        case .requiresApproval:
            launchAtLoginMessage = result.message
            if !autoLaunchEnabled {
                autoLaunchEnabled = true
            }
        case let .failed(actualStatus):
            launchAtLoginMessage = result.message
            let actualValue = actualStatus.isRequestedEnabled
            if autoLaunchEnabled != actualValue {
                autoLaunchEnabled = actualValue
            }
        }
    }

    func updateLaunchAtLoginStatus(_ status: LaunchAtLoginStatus) {
        launchAtLoginStatus = status
        launchAtLoginMessage = status == .requiresApproval
            ? "Approval is required in System Settings."
            : nil
        switch status {
        case .enabled, .requiresApproval:
            if !autoLaunchEnabled {
                autoLaunchEnabled = true
            }
        case .disabled:
            if autoLaunchEnabled {
                autoLaunchEnabled = false
            }
        case .unknown, .unavailable:
            break
        }
    }
}

private extension SettingsStore {
    typealias PreviewDisabledBehavior = PreviewDisabledOutputBehavior

    static func loadSaveDelaySeconds(from defaults: UserDefaults) -> Double {
        if let saveDelay = defaults.object(forKey: Keys.saveDelaySeconds) as? Double {
            let normalized = clampSaveDelaySeconds(saveDelay)
            if normalized != saveDelay || !saveDelay.isFinite {
                defaults.set(normalized, forKey: Keys.saveDelaySeconds)
            }
            return normalized
        }
        if let legacyDelay = defaults.object(forKey: LegacyKeys.previewTimeoutSeconds) as? Double {
            defaults.removeObject(forKey: LegacyKeys.previewTimeoutSeconds)
            let normalized = clampSaveDelaySeconds(legacyDelay)
            defaults.set(normalized, forKey: Keys.saveDelaySeconds)
            return normalized
        }
        return defaultSaveDelaySeconds
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

    static func loadShutterSoundOption(from defaults: UserDefaults) -> ShutterSoundOption {
        loadEnum(
            ShutterSoundOption.self,
            from: defaults,
            key: Keys.shutterSound,
            defaultValue: .shutter,
        )
    }

    static func loadShutterSoundVolume(from defaults: UserDefaults) -> Double {
        let value = defaults.object(forKey: Keys.shutterSoundVolume) as? Double ?? 1.0
        return clampVolume(value)
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

        let keyCodeInt: Int
        if let intValue = keyCodeValue as? Int {
            keyCodeInt = intValue
        } else if let uintValue = keyCodeValue as? UInt {
            guard let exactValue = Int(exactly: uintValue) else {
                persistHotkey(nil, keyCodeKey: keyCodeKey, modifiersKey: modifiersKey)
                return nil
            }
            keyCodeInt = exactValue
        } else {
            keyCodeInt = defaults.integer(forKey: keyCodeKey)
        }

        if keyCodeInt < 0 || keyCodeInt > Int(UInt16.max) {
            return nil
        }

        let keyCode = UInt16(keyCodeInt)
        guard let rawValue = modifierRawValue(forKey: modifiersKey) else {
            persistHotkey(nil, keyCodeKey: keyCodeKey, modifiersKey: modifiersKey)
            return nil
        }
        let hotkey = Hotkey(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: rawValue))
        guard hotkey.isValid else {
            persistHotkey(nil, keyCodeKey: keyCodeKey, modifiersKey: modifiersKey)
            return nil
        }
        return hotkey
    }

    func modifierRawValue(forKey key: String) -> UInt? {
        if let value = defaults.object(forKey: key) as? UInt {
            return value
        }
        if let value = defaults.object(forKey: key) as? Int {
            return value >= 0 ? UInt(value) : nil
        }
        let value = defaults.integer(forKey: key)
        return value >= 0 ? UInt(value) : nil
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

    func persistShutterSoundVolume() {
        let clamped = Self.clampVolume(shutterSoundVolume)
        if clamped != shutterSoundVolume {
            shutterSoundVolume = clamped
        }
        defaults.set(clamped, forKey: Keys.shutterSoundVolume)
    }

    func persistSaveDelaySeconds() {
        let clamped = Self.clampSaveDelaySeconds(saveDelaySeconds)
        if clamped != saveDelaySeconds {
            saveDelaySeconds = clamped
        }
        defaults.set(clamped, forKey: Keys.saveDelaySeconds)
    }

    static func clampVolume(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    static func clampSaveDelaySeconds(_ value: Double) -> Double {
        guard value.isFinite else {
            return defaultSaveDelaySeconds
        }
        return min(max(value, 0), maximumSaveDelaySeconds)
    }

    static let unsetKeyCodeSentinel = -1
}
