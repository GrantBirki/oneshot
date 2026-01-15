import Cocoa
import Combine

final class AppController {
    private let settings: SettingsStore
    private let hotkeyManager: HotkeyManager
    private let captureManager: CaptureManager
    private let menuBarController: MenuBarController
    private let settingsWindowController: SettingsWindowController
    private let launchAtLoginManager: LaunchAtLoginManager
    private var cancellables = Set<AnyCancellable>()

    init() {
        settings = SettingsStore()
        hotkeyManager = HotkeyManager()
        captureManager = CaptureManager(settings: settings)
        settingsWindowController = SettingsWindowController(settings: settings)
        launchAtLoginManager = LaunchAtLoginManager()

        menuBarController = MenuBarController(
            onCaptureSelection: { [weak captureManager] in captureManager?.captureSelection() },
            onCaptureFullScreen: { [weak captureManager] in captureManager?.captureFullScreen() },
            onCaptureWindow: { [weak captureManager] in captureManager?.captureWindow() },
            onSettings: { [weak settingsWindowController] in settingsWindowController?.show() },
            onQuit: { NSApp.terminate(nil) },
            hotkeyProvider: { [weak settings] in
                MenuBarController.HotkeyBindings(
                    selection: settings?.hotkeySelection,
                    fullScreen: settings?.hotkeyFullScreen,
                    window: settings?.hotkeyWindow,
                )
            },
        )
    }

    func start() {
        NSLog("OneShot AppController start")
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

        if let selectionHotkey = settings.hotkeySelection, selectionHotkey.isValid {
            NSLog("Registering selection hotkey: \(selectionHotkey.displayString)")
            hotkeyManager.register(hotkey: selectionHotkey) { [weak self] in
                self?.captureManager.captureSelection()
            }
        } else {
            NSLog("Selection hotkey not set or invalid")
        }

        if let fullScreenHotkey = settings.hotkeyFullScreen, fullScreenHotkey.isValid {
            NSLog("Registering full screen hotkey: \(fullScreenHotkey.displayString)")
            hotkeyManager.register(hotkey: fullScreenHotkey) { [weak self] in
                self?.captureManager.captureFullScreen()
            }
        } else {
            NSLog("Full screen hotkey not set or invalid")
        }

        if let windowHotkey = settings.hotkeyWindow, windowHotkey.isValid {
            NSLog("Registering window hotkey: \(windowHotkey.displayString)")
            hotkeyManager.register(hotkey: windowHotkey) { [weak self] in
                self?.captureManager.captureWindow()
            }
        } else {
            NSLog("Window hotkey not set or invalid")
        }

        menuBarController.refreshHotkeys()
    }
}
