import Cocoa
import Combine

final class AppController {
    private let settings: SettingsStore
    private let hotkeyManager: HotkeyManager
    private let captureManager: CaptureManager
    private let menuBarController: MenuBarController
    private let preferencesWindowController: PreferencesWindowController
    private let launchAtLoginManager: LaunchAtLoginManager
    private var cancellables = Set<AnyCancellable>()

    init() {
        settings = SettingsStore()
        hotkeyManager = HotkeyManager()
        captureManager = CaptureManager(settings: settings)
        preferencesWindowController = PreferencesWindowController(settings: settings)
        launchAtLoginManager = LaunchAtLoginManager()

        menuBarController = MenuBarController(
            onCaptureSelection: { [weak captureManager] in captureManager?.captureSelection() },
            onCaptureFullScreen: { [weak captureManager] in captureManager?.captureFullScreen() },
            onCaptureWindow: { [weak captureManager] in captureManager?.captureWindow() },
            onPreferences: { [weak preferencesWindowController] in preferencesWindowController?.show() },
            onQuit: { NSApp.terminate(nil) },
            hotkeyProvider: { [weak settings] in
                (
                    selection: settings?.hotkeySelection ?? "",
                    fullScreen: settings?.hotkeyFullScreen ?? "",
                    window: settings?.hotkeyWindow ?? ""
                )
            }
        )
    }

    func start() {
        NSLog("OpenShot AppController start")
        menuBarController.start()
        registerHotkeys()
        observeSettings()
        launchAtLoginManager.setEnabled(settings.autoLaunchEnabled)
    }

    private func observeSettings() {
        settings.$autoLaunchEnabled
            .sink { [weak self] enabled in
                self?.launchAtLoginManager.setEnabled(enabled)
            }
            .store(in: &cancellables)

        settings.$hotkeySelection
            .sink { [weak self] _ in self?.registerHotkeys() }
            .store(in: &cancellables)
        settings.$hotkeyFullScreen
            .sink { [weak self] _ in self?.registerHotkeys() }
            .store(in: &cancellables)
        settings.$hotkeyWindow
            .sink { [weak self] _ in self?.registerHotkeys() }
            .store(in: &cancellables)
    }

    private func registerHotkeys() {
        hotkeyManager.unregisterAll()

        if let selectionHotkey = HotkeyParser.parse(settings.hotkeySelection) {
            NSLog("Registering selection hotkey: \(selectionHotkey.display)")
            hotkeyManager.register(hotkey: selectionHotkey) { [weak self] in
                self?.captureManager.captureSelection()
            }
        } else {
            NSLog("Selection hotkey not set or invalid")
        }

        if let fullScreenHotkey = HotkeyParser.parse(settings.hotkeyFullScreen) {
            NSLog("Registering full screen hotkey: \(fullScreenHotkey.display)")
            hotkeyManager.register(hotkey: fullScreenHotkey) { [weak self] in
                self?.captureManager.captureFullScreen()
            }
        } else {
            NSLog("Full screen hotkey not set or invalid")
        }

        if let windowHotkey = HotkeyParser.parse(settings.hotkeyWindow) {
            NSLog("Registering window hotkey: \(windowHotkey.display)")
            hotkeyManager.register(hotkey: windowHotkey) { [weak self] in
                self?.captureManager.captureWindow()
            }
        } else {
            NSLog("Window hotkey not set or invalid")
        }

        menuBarController.refreshHotkeys()
    }
}
